import 'package:church_presenter/db/database_helper.dart';
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
  }) =>
      SyncStats(
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

/// ChangeNotifier that drives the Sync Songs UI.
///
/// Inject via [ChangeNotifierProvider] when pushing [SyncSongsPage].
class SongSyncController extends ChangeNotifier {
  SongSyncController({
    SongSyncService? service,
    DatabaseHelper? db,
  })  : _service = service ?? SongSyncService(),
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

  // ---------------------------------------------------------------------------
  // Initialisation
  // ---------------------------------------------------------------------------

  /// Loads the persisted last-synced timestamp and current local song count.
  /// Call this once from [initState].
  Future<void> init() async {
    _lastSyncedAt = await _db.getLastSyncedAt();
    final localCount = await _db.getSyncedSongCount();
    _stats = _stats.copyWith(localCount: localCount);
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
    // Preserve localCount so the UI keeps showing the previous value.
    _stats = SyncStats(localCount: _stats.localCount);
    notifyListeners();

    try {
      // ------------------------------------------------------------------
      // Step 1: Fetch remote master index
      // ------------------------------------------------------------------
      _update(SyncStatus.fetchingIndex, 'Fetching master index…');
      final rawIndex = await _service.fetchMasterIndex();
      final indexRecords = _service.parseMasterIndex(rawIndex);

      debugPrint('[SongSync] Remote master index: ${indexRecords.length} songs');
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
        int inserted = 0;
        for (int i = 0; i < buckets.length; i++) {
          if (_cancelRequested) {
            throw _SyncCancelledException();
          }
          final bucket = buckets[i];
          _update(
            SyncStatus.fetchingBucket,
            'Fetching bucket ${i + 1} of ${buckets.length}…',
          );

          final bucketMap = await _service.fetchBucket(bucket);
          if (_cancelRequested) throw _SyncCancelledException();
          final details = _service.extractDetailsFromBucket(
            bucketMap,
            bucketToRecords[bucket] ?? [],
          );

          _update(SyncStatus.writingToDb, 'Writing songs to database…');
          await _db.upsertSongDetailBatch(details);

          inserted += details.length;
          _stats = _stats.copyWith(
            fetchedBuckets: i + 1,
            insertedSongs: inserted,
          );
          notifyListeners();

          debugPrint(
            '[SongSync] Bucket $bucket done — saved ${details.length} songs '
            '(total inserted: $inserted)',
          );
        }
      }

      // ------------------------------------------------------------------
      // Step 7: Finalise — only update timestamp on full success
      // ------------------------------------------------------------------
      final now = DateTime.now();
      await _db.saveLastSyncedAt(now);
      _lastSyncedAt = now;

      final finalCount = await _db.getSyncedSongCount();
      _stats = _stats.copyWith(localCount: finalCount);

      _update(SyncStatus.completed, 'Sync completed successfully!');
      debugPrint('[SongSync] ✓ Sync finished. Total local songs: $finalCount');
    } on _SyncCancelledException {
      _update(SyncStatus.idle, 'Sync cancelled.');
      debugPrint('[SongSync] Sync was cancelled by user.');
    } catch (e, st) {
      _errorMessage = e.toString();
      _update(SyncStatus.failed, 'Sync failed.');
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

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }
}

// Private sentinel thrown to exit the sync loop on cancellation.
class _SyncCancelledException implements Exception {}
