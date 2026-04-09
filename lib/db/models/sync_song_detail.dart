/// Represents a fully-fetched song detail record stored locally.
/// Lyrics are extracted from the bucket cache array (field 'c').
class SyncSongDetail {
  final String remoteId;
  final String title;
  final String lyrics;
  final DateTime syncedAt;

  const SyncSongDetail({
    required this.remoteId,
    required this.title,
    required this.lyrics,
    required this.syncedAt,
  });

  Map<String, dynamic> toMap() => {
        'remote_id': remoteId,
        'title': title,
        'lyrics': lyrics,
        'synced_at': syncedAt.toIso8601String(),
      };

  factory SyncSongDetail.fromMap(Map<String, dynamic> map) => SyncSongDetail(
        remoteId: map['remote_id'] as String,
        title: map['title'] as String,
        lyrics: map['lyrics'] as String,
        syncedAt: DateTime.parse(map['synced_at'] as String),
      );

  SyncSongDetail copyWith({
    String? remoteId,
    String? title,
    String? lyrics,
    DateTime? syncedAt,
  }) =>
      SyncSongDetail(
        remoteId: remoteId ?? this.remoteId,
        title: title ?? this.title,
        lyrics: lyrics ?? this.lyrics,
        syncedAt: syncedAt ?? this.syncedAt,
      );
}
