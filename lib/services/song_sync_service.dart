import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../db/models/sync_song_detail.dart';
import '../db/models/sync_song_index.dart';

/// Handles all network operations required for syncing Tamil Christian songs
/// from the CDN at https://samsolomonprabu.github.io/cdn/cs/v3.
///
/// Data format (from CDN):
///   - Master index response body: gzip-compressed JSON encoded as base64.
///     Decoded shape: `{ "songs": [ {"a": "id", "b": "title"}, ... ] }`
///   - Bucket URL: /caches/{sha256(bucketNumber)}.cs.song
///     Decoded shape: `List` where `arr[offset] = {"c": "lyrics"}`
///     bucketNumber = floor(songId / 50), offset = songId % 50
class SongSyncService {
  static const String _language = 'tamil';
  static const String _baseCdn =
      'https://samsolomonprabu.github.io/cdn/cs/v3';

  final http.Client _client;

  SongSyncService({http.Client? client})
      : _client = client ?? http.Client();

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Returns the SHA-256 hex digest of [input].
  String _sha256Hex(String input) {
    final bytes = utf8.encode(input);
    return sha256.convert(bytes).toString();
  }

  /// Returns the bucket number that contains the song with [songId].
  int _bucketForId(String songId) => (int.parse(songId) / 50).floor();

  /// Decodes a gzip+base64 payload returned by the CDN into a Dart object.
  ///
  /// The CDN sends the response body as a plain base64 string whose decoded
  /// bytes are gzip-compressed JSON.
  dynamic _decodeCompressedPayload(String base64Text) {
    final gzBytes = base64Decode(base64Text.trim());
    // GZipCodec is in dart:io (available on Android / iOS / desktop).
    final jsonBytes = GZipCodec().decode(gzBytes);
    final jsonStr = utf8.decode(jsonBytes);
    return jsonDecode(jsonStr);
  }

  /// Fetches [url] and decodes its compressed JSON body.
  Future<dynamic> _fetchCompressedJson(String url) async {
    debugPrint('[SongSyncService] GET $url');
    final response = await _client
        .get(
          Uri.parse(url),
          headers: {
            'User-Agent': 'Mozilla/5.0',
            'Accept': '*/*',
          },
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception(
        'HTTP ${response.statusCode} for $url',
      );
    }

    return _decodeCompressedPayload(response.body);
  }

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Fetches the remote master song index.
  ///
  /// Tries the primary URL first; falls back to the minified variant.
  /// Returns the raw decoded JSON map.
  Future<Map<String, dynamic>> fetchMasterIndex() async {
    final urls = [
      '$_baseCdn/data/$_language.compressed',
      '$_baseCdn/data/$_language.min.compressed',
    ];

    Exception? lastError;
    for (final url in urls) {
      try {
        final data = await _fetchCompressedJson(url);
        if (data is Map<String, dynamic>) return data;
        throw Exception('Unexpected master index shape for $url');
      } on Exception catch (e) {
        lastError = e;
        debugPrint('[SongSyncService] Failed URL: $url — $e');
      }
    }
    throw lastError ?? Exception('Could not fetch master index');
  }

  /// Fetches the song-detail bucket for [bucketNumber].
  ///
  /// The CDN stores each bucket as a gzip+base64 JSON **object** whose keys
  /// are the per-bucket offsets as strings ("0"–"49") and whose values are
  /// `{"c": "<lyrics>"}` maps. Example shape:
  /// `{"0": {"c": "lyrics..."}, "1": {"c": "lyrics..."}, ...}`
  ///
  /// The bucket URL is derived by SHA-256 hashing the bucket number string.
  Future<Map<String, dynamic>> fetchBucket(int bucketNumber) async {
    final hash = _sha256Hex(bucketNumber.toString());
    final url = '$_baseCdn/caches/$hash.cs.song';
    final data = await _fetchCompressedJson(url);
    if (data is Map<String, dynamic>) return data;
    // Older-format fallback: plain JSON array → convert to string-keyed map.
    if (data is List) {
      return {
        for (int i = 0; i < data.length; i++) i.toString(): data[i],
      };
    }
    throw Exception(
      'Bucket $bucketNumber returned unexpected format '
      '(${data.runtimeType})',
    );
  }

  /// Parses the raw master-index map into a typed list of [SyncSongIndex].
  List<SyncSongIndex> parseMasterIndex(Map<String, dynamic> raw) {
    final songs = raw['songs'];
    if (songs == null || songs is! List) {
      throw Exception('"songs" array not found in master index response');
    }
    return songs.map<SyncSongIndex>((s) {
      final id = (s['a'] ?? '').toString();
      final title = (s['b'] as String? ?? '').trim();
      return SyncSongIndex(
        remoteId: id,
        title: title,
        bucket: _bucketForId(id),
      );
    }).toList();
  }

  /// Computes the sorted list of unique bucket numbers needed for [songIds].
  List<int> computeBucketsFromSongIds(List<String> songIds) {
    return songIds.map(_bucketForId).toSet().toList()..sort();
  }

  /// Extracts [SyncSongDetail] records from a decoded bucket map.
  ///
  /// [bucketMap]    — the `Map<String, dynamic>` returned by [fetchBucket].
  /// [indexRecords] — the [SyncSongIndex] entries that belong to this bucket.
  List<SyncSongDetail> extractDetailsFromBucket(
    Map<String, dynamic> bucketMap,
    List<SyncSongIndex> indexRecords,
  ) {
    final now = DateTime.now();
    final details = <SyncSongDetail>[];

    for (final record in indexRecords) {
      // The bucket map key is the per-bucket offset (songId % 50) as a string.
      final offsetKey = (int.parse(record.remoteId) % 50).toString();
      final raw = bucketMap[offsetKey];
      if (raw == null) {
        debugPrint(
          '[SongSyncService] Key "$offsetKey" not found in bucket '
          '${record.bucket} — skipping song ${record.remoteId}',
        );
        continue;
      }

      final lyrics =
          (raw is Map ? (raw['c'] as String? ?? '') : '').trim();

      details.add(SyncSongDetail(
        remoteId: record.remoteId,
        title: record.title,
        lyrics: lyrics,
        syncedAt: now,
      ));
    }

    return details;
  }

  /// Disposes the underlying HTTP client.
  void dispose() => _client.close();
}
