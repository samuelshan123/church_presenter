import 'package:church_presenter/db/database_helper.dart';
import 'package:church_presenter/db/models/sync_song_detail.dart';
import 'package:church_presenter/db/models/sync_song_index.dart';
import 'package:church_presenter/services/song_sync_service.dart';
import 'package:flutter/foundation.dart';

// ---------------------------------------------------------------------------
// Sync status enum
// ---------------------------------------------------------------------------

enum SyncStatus {
  idle,
  fetchingIndex,
  comparingLocal,
  findingMissing,
  fetchingBucket,
  writingToDb,
  completed,
  failed,
}

// ---------------------------------------------------------------------------
// Immutable stats snapshot
// ---------------------------------------------------------------------------

class SyncStats {
  final int totalRemote;
  final int localCount;
  final int missingCount;
  final int totalBuckets;
  final int fetchedBuckets;
  final int insertedSongs;

  const SyncStats({
    this.totalRemote = 0,
    this.localCount = 0,
    this.missingCount = 0,
    this.totalBuckets = 0,
    this.fetchedBuckets = 0,
    this.insertedSongs = 0,
  });

  SyncStats copyWith({
    int? totalRemote,
    int? localCount,
    int? missingCount,
    int? totalBuckets,
    int? fetchedBuckets,
    int? insertedSongs,
  }) => SyncStats(
    totalRemote: totalRemote ?? this.totalRemote,
    localCount: localCount ?? this.localCount,
    missingCount: missingCount ?? this.missingCount,
    totalBuckets: totalBuckets ?? this.totalBuckets,
    fetchedBuckets: fetchedBuckets ?? this.fetchedBuckets,
    insertedSongs: insertedSongs ?? this.insertedSongs,
  );
}

// ---------------------------------------------------------------------------
// Controller
// ---------------------------------------------------------------------------

// sync_meta keys describing the last completed run. Live counts are always
// derived from the song tables, so only run-scoped figures are stored here.
const String _kLastTotalBuckets = 'last_total_buckets';
const String _kLastInsertedSongs = 'last_inserted_songs';

/// ChangeNotifier that drives the Sync Songs UI.
///
/// Inject via [ChangeNotifierProvider] when pushing [SyncSongsPage].
class SongSyncController extends ChangeNotifier {
  SongSyncController({SongSyncService? service, DatabaseHelper? db})
    : _service = service ?? SongSyncService(),
      _db = db ?? DatabaseHelper.instance;

  final SongSyncService _service;
  final DatabaseHelper _db;

  // ---------------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------------

  SyncStatus _status = SyncStatus.idle;
  SyncStatus get status => _status;

  String _statusMessage = 'Idle — tap "Sync Songs" to begin.';
  String get statusMessage => _statusMessage;

  SyncStats _stats = const SyncStats();
  SyncStats get stats => _stats;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  DateTime? _lastSyncedAt;
  DateTime? get lastSyncedAt => _lastSyncedAt;

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  bool _cancelRequested = false;
  bool get cancelRequested => _cancelRequested;

  /// Buckets skipped due to fetch/parse errors in the last run. Non-zero means
  /// the sync finished but some songs are still missing — retry to pick them up.
  int _skippedBuckets = 0;
  int get skippedBuckets => _skippedBuckets;

  // ---------------------------------------------------------------------------
  // Initialisation
  // ---------------------------------------------------------------------------

  /// Restores the last-known sync picture so returning to the page immediately
  /// shows what is stored and what is still missing.
  ///
  /// Live counts (local / missing / remote total) are computed from the local
  /// DB rather than read back from saved values, so they can never drift out
  /// of step with what is actually stored. Only the figures that describe the
  /// *previous run* ([SyncStats.totalBuckets], [SyncStats.insertedSongs]) come
  /// from [sync_meta].
  ///
  /// Call this once from [initState].
  Future<void> init() async {
    // Never clobber a sync that is already running.
    if (_isSyncing) return;

    _lastSyncedAt = await _db.getLastSyncedAt();

    final localCount = await _db.getSyncedSongCount();
    final indexCount = await _db.getSongIndexCount();
    final missingCount = await _db.getMissingSongCount();
    final lastBuckets = await _db.getSyncMetaInt(_kLastTotalBuckets) ?? 0;
    final lastInserted = await _db.getSyncMetaInt(_kLastInsertedSongs) ?? 0;

    _stats = SyncStats(
      totalRemote: indexCount,
      localCount: localCount,
      missingCount: missingCount,
      totalBuckets: lastBuckets,
      fetchedBuckets: lastBuckets,
      insertedSongs: lastInserted,
    );

    // Give the idle card something useful to say instead of a generic prompt.
    if (_status == SyncStatus.idle) {
      if (indexCount == 0) {
        _statusMessage = 'No songs synced yet — tap "Sync Songs" to begin.';
      } else if (missingCount > 0) {
        _statusMessage =
            '$missingCount of $indexCount songs not downloaded yet.';
      } else {
        _statusMessage = 'All $localCount songs are up to date.';
      }
    }

    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Sync orchestration
  // ---------------------------------------------------------------------------

  /// Runs the full sync pipeline on a background isolate-friendly async chain.
  ///
  /// All heavy DB work is performed inside sqflite's own thread pool;
  /// HTTP calls are async and non-blocking — the UI stays responsive.
  /// Requests cancellation of an in-progress sync.
  void cancelSync() {
    if (_isSyncing) {
      _cancelRequested = true;
      notifyListeners();
    }
  }

  Future<void> syncSongs() async {
    if (_isSyncing) return;

    _isSyncing = true;
    _cancelRequested = false;
    _errorMessage = null;
    _skippedBuckets = 0;
    // Preserve the restored counts so the tiles keep showing the last-known
    // picture instead of blanking to zero until step 3 lands.
    _stats = SyncStats(
      localCount: _stats.localCount,
      totalRemote: _stats.totalRemote,
      missingCount: _stats.missingCount,
    );
    notifyListeners();

    try {
      // ------------------------------------------------------------------
      // Step 1: Fetch remote master index
      // ------------------------------------------------------------------
      _update(SyncStatus.fetchingIndex, 'Fetching master index…');
      final rawIndex = await _service.fetchMasterIndex();
      final indexRecords = _service.parseMasterIndex(rawIndex);

      debugPrint(
        '[SongSync] Remote master index: ${indexRecords.length} songs',
      );
      _stats = _stats.copyWith(totalRemote: indexRecords.length);
      notifyListeners();

      // ------------------------------------------------------------------
      // Step 2: Compare with local detail table
      // ------------------------------------------------------------------
      _update(SyncStatus.comparingLocal, 'Comparing with local database…');
      final localCount = await _db.getSyncedSongCount();
      _stats = _stats.copyWith(localCount: localCount);
      notifyListeners();

      // ------------------------------------------------------------------
      // Step 3: Detect missing songs
      // ------------------------------------------------------------------
      _update(SyncStatus.findingMissing, 'Finding missing songs…');
      final allRemoteIds = indexRecords.map((r) => r.remoteId).toList();
      final missingIds = await _db.getMissingSongIds(allRemoteIds);

      debugPrint('[SongSync] Missing songs: ${missingIds.length}');
      _stats = _stats.copyWith(missingCount: missingIds.length);
      notifyListeners();

      // ------------------------------------------------------------------
      // Step 4: Upsert full index (always keep index up to date)
      // ------------------------------------------------------------------
      _update(SyncStatus.writingToDb, 'Saving index to database…');
      await _db.upsertSongIndexBatch(indexRecords);
      debugPrint('[SongSync] Index upserted.');

      if (missingIds.isEmpty) {
        debugPrint('[SongSync] No missing songs — sync complete.');
      } else {
        // ----------------------------------------------------------------
        // Step 5: Compute required buckets
        // ----------------------------------------------------------------
        final buckets = _service.computeBucketsFromSongIds(missingIds);
        debugPrint('[SongSync] Buckets to fetch: ${buckets.length}');
        _stats = _stats.copyWith(
          totalBuckets: buckets.length,
          fetchedBuckets: 0,
        );
        notifyListeners();

        // Build bucket → index-records lookup for O(1) access
        final missingIdSet = missingIds.toSet();
        final missingRecords = indexRecords
            .where((r) => missingIdSet.contains(r.remoteId))
            .toList();
        final bucketToRecords = <int, List<SyncSongIndex>>{};
        for (final r in missingRecords) {
          bucketToRecords.putIfAbsent(r.bucket, () => []).add(r);
        }

        // ----------------------------------------------------------------
        // Step 6: Fetch each bucket and persist
        // ----------------------------------------------------------------
        final baseLocalCount = _stats.localCount;
        final totalMissing = missingIds.length;
        int inserted = 0;
        int failedBuckets = 0;
        for (int i = 0; i < buckets.length; i++) {
          if (_cancelRequested) {
            throw _SyncCancelledException();
          }
          final bucket = buckets[i];
          _update(
            SyncStatus.fetchingBucket,
            'Downloading bucket ${i + 1} of ${buckets.length}…',
          );

          // A single unreachable/corrupt bucket must not abort the whole run —
          // the remaining buckets are still worth fetching, and the sync is
          // resumable so the failed one is retried next time.
          List<SyncSongDetail> details;
          try {
            final bucketMap = await _service.fetchBucket(bucket);
            details = _service.extractDetailsFromBucket(
              bucketMap,
              bucketToRecords[bucket] ?? [],
            );
          } on _SyncCancelledException {
            rethrow;
          } catch (e) {
            failedBuckets++;
            debugPrint('[SongSync] ⚠ Bucket $bucket failed — skipping: $e');
            _stats = _stats.copyWith(fetchedBuckets: i + 1);
            notifyListeners();
            continue;
          }
          if (_cancelRequested) throw _SyncCancelledException();

          // Only claim "writing" for the window we're actually writing in —
          // otherwise the card sits on this message during the next fetch.
          _update(
            SyncStatus.writingToDb,
            'Saving ${details.length} songs (bucket ${i + 1} of ${buckets.length})…',
          );
          await _db.upsertSongDetailBatch(details);

          inserted += details.length;
          // Advance localCount/missingCount live so the tiles track the DB
          // instead of freezing on their step-2/step-3 snapshot.
          _stats = _stats.copyWith(
            fetchedBuckets: i + 1,
            insertedSongs: inserted,
            localCount: baseLocalCount + inserted,
            missingCount: totalMissing - inserted < 0
                ? 0
                : totalMissing - inserted,
          );
          notifyListeners();

          debugPrint(
            '[SongSync] Bucket $bucket done — saved ${details.length} songs '
            '(total inserted: $inserted)',
          );
        }

        _skippedBuckets = failedBuckets;
      }

      // ------------------------------------------------------------------
      // Step 7: Finalise — the run reached the end without aborting.
      // Individual buckets may have been skipped (see [_skippedBuckets]);
      // the timestamp still records that a sync ran to completion, and the
      // missing count below reflects whatever those skips left behind.
      // ------------------------------------------------------------------
      final now = DateTime.now();
      await _db.saveLastSyncedAt(now);
      _lastSyncedAt = now;

      final finalCount = await _db.getSyncedSongCount();
      final finalMissing = await _db.getMissingSongCount();
      _stats = _stats.copyWith(
        localCount: finalCount,
        missingCount: finalMissing,
      );

      // Persist the run-scoped figures so returning to the page can show them.
      await _db.saveSyncMetaInt(_kLastTotalBuckets, _stats.totalBuckets);
      await _db.saveSyncMetaInt(_kLastInsertedSongs, _stats.insertedSongs);

      _update(
        SyncStatus.completed,
        _skippedBuckets > 0
            ? 'Sync finished — $_skippedBuckets batch'
                  '${_skippedBuckets == 1 ? '' : 'es'} could not be downloaded. '
                  'Sync again to retry.'
            : 'Sync completed successfully!',
      );
      debugPrint(
        '[SongSync] ✓ Sync finished. Total local songs: $finalCount '
        '(skipped buckets: $_skippedBuckets)',
      );
    } on _SyncCancelledException {
      // Buckets already written are kept (sync is resumable) — reconcile the
      // tiles with what actually landed rather than leaving mid-flight values.
      await _reconcileLocalCount();
      final saved = _stats.insertedSongs;
      _update(
        SyncStatus.idle,
        saved > 0
            ? 'Sync cancelled — $saved songs saved. '
                  '${_stats.missingCount} still missing.'
            : 'Sync cancelled.',
      );
      debugPrint('[SongSync] Sync was cancelled by user (saved: $saved).');
    } catch (e, st) {
      await _reconcileLocalCount();
      _errorMessage = e.toString();
      final saved = _stats.insertedSongs;
      _update(
        SyncStatus.failed,
        saved > 0
            ? 'Sync failed after saving $saved songs. Sync again to continue.'
            : 'Sync failed.',
      );
      debugPrint('[SongSync] ✗ Error: $e\n$st');
    } finally {
      _isSyncing = false;
      _cancelRequested = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  void _update(SyncStatus status, String message) {
    _status = status;
    _statusMessage = message;
    notifyListeners();
  }

  /// Re-reads the true local and missing counts from the DB, replacing any
  /// stale in-flight estimates, and records the sync timestamp when the run
  /// actually persisted something.
  ///
  /// Used when a sync ends early (cancel/failure). A partial run still pulled
  /// real songs down, so it counts as a sync for "last synced" purposes — but
  /// a run that died before saving anything does not.
  Future<void> _reconcileLocalCount() async {
    try {
      final count = await _db.getSyncedSongCount();
      final missing = await _db.getMissingSongCount();
      _stats = _stats.copyWith(localCount: count, missingCount: missing);

      if (_stats.insertedSongs > 0) {
        final now = DateTime.now();
        await _db.saveLastSyncedAt(now);
        _lastSyncedAt = now;
        await _db.saveSyncMetaInt(_kLastTotalBuckets, _stats.totalBuckets);
        await _db.saveSyncMetaInt(_kLastInsertedSongs, _stats.insertedSongs);
      }
    } catch (e) {
      debugPrint('[SongSync] Could not reconcile counts: $e');
    }
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }
}

// Private sentinel thrown to exit the sync loop on cancellation.
class _SyncCancelledException implements Exception {}
