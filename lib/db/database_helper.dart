import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'models/song.dart';
import 'models/song_list.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('church_presenter.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const integerType = 'INTEGER NOT NULL';

    // Songs table
    await db.execute('''
      CREATE TABLE songs (
        id $idType,
        title $textType,
        content $textType,
        createdAt $textType,
        updatedAt $textType
      )
    ''');

    // Song lists table
    await db.execute('''
      CREATE TABLE song_lists (
        id $idType,
        name $textType,
        createdAt $textType
      )
    ''');

    // Junction table for many-to-many relationship
    await db.execute('''
      CREATE TABLE list_songs (
        id $idType,
        listId $integerType,
        songId $integerType,
        \`order\` INTEGER DEFAULT 0,
        FOREIGN KEY (listId) REFERENCES song_lists (id) ON DELETE CASCADE,
        FOREIGN KEY (songId) REFERENCES songs (id) ON DELETE CASCADE
      )
    ''');

    // Create default list
    await db.insert('song_lists', {
      'name': 'Favorite Songs',
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  // ==================== SONG OPERATIONS ====================

  Future<Song> createSong(Song song) async {
    final db = await database;
    final id = await db.insert('songs', song.toMap());
    return song.copyWith(id: id);
  }

  Future<Song?> readSong(int id) async {
    final db = await database;
    final maps = await db.query('songs', where: 'id = ?', whereArgs: [id]);

    if (maps.isNotEmpty) {
      return Song.fromMap(maps.first);
    }
    return null;
  }

  Future<List<Song>> readAllSongs() async {
    final db = await database;
    const orderBy = 'createdAt DESC';
    final result = await db.query('songs', orderBy: orderBy);
    return result.map((json) => Song.fromMap(json)).toList();
  }

  Future<int> updateSong(Song song) async {
    final db = await database;
    return db.update(
      'songs',
      song.copyWith(updatedAt: DateTime.now()).toMap(),
      where: 'id = ?',
      whereArgs: [song.id],
    );
  }

  Future<int> deleteSong(int id) async {
    final db = await database;
    return await db.delete('songs', where: 'id = ?', whereArgs: [id]);
  }

  // ==================== SONG LIST OPERATIONS ====================

  Future<SongList> createSongList(SongList songList) async {
    final db = await database;
    final id = await db.insert('song_lists', songList.toMap());
    return SongList(id: id, name: songList.name, createdAt: songList.createdAt);
  }

  Future<List<SongList>> readAllSongLists() async {
    final db = await database;
    const orderBy = 'createdAt ASC';
    final result = await db.query('song_lists', orderBy: orderBy);
    return result.map((json) => SongList.fromMap(json)).toList();
  }

  Future<int> updateSongList(SongList songList) async {
    final db = await database;
    return db.update(
      'song_lists',
      songList.toMap(),
      where: 'id = ?',
      whereArgs: [songList.id],
    );
  }

  Future<int> deleteSongList(int id) async {
    final db = await database;
    return await db.delete('song_lists', where: 'id = ?', whereArgs: [id]);
  }

  // ==================== LIST-SONG OPERATIONS ====================

  Future<void> addSongToList(int listId, int songId) async {
    final db = await database;

    // Get the max order for this list
    final result = await db.rawQuery(
      'SELECT MAX(\`order\`) as maxOrder FROM list_songs WHERE listId = ?',
      [listId],
    );

    final maxOrder = result.first['maxOrder'] as int? ?? -1;

    await db.insert('list_songs', {
      'listId': listId,
      'songId': songId,
      'order': maxOrder + 1,
    });
  }

  Future<void> removeSongFromList(int listId, int songId) async {
    final db = await database;
    await db.delete(
      'list_songs',
      where: 'listId = ? AND songId = ?',
      whereArgs: [listId, songId],
    );
  }

  Future<List<Song>> getSongsInList(int listId) async {
    final db = await database;
    final result = await db.rawQuery(
      '''
      SELECT songs.* FROM songs
      INNER JOIN list_songs ON songs.id = list_songs.songId
      WHERE list_songs.listId = ?
      ORDER BY list_songs.\`order\` ASC
    ''',
      [listId],
    );

    return result.map((json) => Song.fromMap(json)).toList();
  }

  Future<bool> isSongInList(int listId, int songId) async {
    final db = await database;
    final result = await db.query(
      'list_songs',
      where: 'listId = ? AND songId = ?',
      whereArgs: [listId, songId],
    );
    return result.isNotEmpty;
  }

  Future<void> close() async {
    final db = await database;
    db.close();
  }
}
