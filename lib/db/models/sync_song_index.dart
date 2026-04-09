/// Represents one entry from the remote master song index.
/// The remote CDN compresses a list of objects like {"a": "id", "b": "title"}.
class SyncSongIndex {
  final String remoteId; // 'a' field from CDN
  final String title; // 'b' field from CDN
  final int bucket; // pre-computed: floor(int.parse(remoteId) / 50)

  const SyncSongIndex({
    required this.remoteId,
    required this.title,
    required this.bucket,
  });

  Map<String, dynamic> toMap() => {
        'remote_id': remoteId,
        'title': title,
        'bucket': bucket,
      };

  factory SyncSongIndex.fromMap(Map<String, dynamic> map) => SyncSongIndex(
        remoteId: map['remote_id'] as String,
        title: map['title'] as String,
        bucket: map['bucket'] as int,
      );
}
