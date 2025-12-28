class ListSong {
  final int? id;
  final int listId;
  final int songId;
  final int order;

  ListSong({
    this.id,
    required this.listId,
    required this.songId,
    this.order = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'listId': listId,
      'songId': songId,
      'order': order,
    };
  }

  factory ListSong.fromMap(Map<String, dynamic> map) {
    return ListSong(
      id: map['id'] as int?,
      listId: map['listId'] as int,
      songId: map['songId'] as int,
      order: map['order'] as int,
    );
  }
}
