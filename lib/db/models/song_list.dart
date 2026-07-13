class SongList {
  /// Name of the list seeded by [DatabaseHelper] on first launch; protected
  /// from rename/delete in the UI.
  static const String defaultListName = 'Favorite Songs';

  final int? id;
  final String name;
  final DateTime createdAt;

  bool get isDefault => name == defaultListName;

  SongList({
    this.id,
    required this.name,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory SongList.fromMap(Map<String, dynamic> map) {
    return SongList(
      id: map['id'] as int?,
      name: map['name'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }
}
