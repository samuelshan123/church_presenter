import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'models/song.dart';
import 'models/song_list.dart';
import 'models/sync_song_detail.dart';
import 'models/sync_song_index.dart';

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

    return await openDatabase(
      path,
      version: 4,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
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
        `order` INTEGER DEFAULT 0,
        FOREIGN KEY (listId) REFERENCES song_lists (id) ON DELETE CASCADE,
        FOREIGN KEY (songId) REFERENCES songs (id) ON DELETE CASCADE
      )
    ''');

    // Create default list
    await db.insert('song_lists', {
      'name': 'Favorite Songs',
      'createdAt': DateTime.now().toIso8601String(),
    });

    // Sync tables (version 2)
    await _createSyncTables(db);

    // Bible verse history (version 3)
    await _createBibleHistoryTable(db);
  }

  /// Called when an existing database is opened with a higher version number.
  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createSyncTables(db);
    }
    if (oldVersion < 3) {
      await _createBibleHistoryTable(db);
    }
    if (oldVersion < 4) {
      await db.execute(
        'ALTER TABLE bible_verse_history ADD COLUMN verseText TEXT',
      );
    }
  }

  /// Creates the three sync-related tables.
  Future<void> _createSyncTables(Database db) async {
    // Master index of remote songs (id + title + bucket number)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_song_index (
        remote_id TEXT PRIMARY KEY,
        title     TEXT NOT NULL,
        bucket    INTEGER NOT NULL
      )
    ''');

    // Full song detail records fetched from CDN buckets
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_song_detail (
        remote_id TEXT PRIMARY KEY,
        title     TEXT NOT NULL,
        lyrics    TEXT NOT NULL,
        synced_at TEXT NOT NULL
      )
    ''');

    // Key/value store for sync metadata (e.g. last_synced_at)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_meta (
        key   TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
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

  Future<List<Song>> searchSongsByTitle(String title) async {
    final db = await database;
    final result = await db.query(
      'songs',
      where: 'LOWER(title) LIKE ?',
      whereArgs: ['%${title.toLowerCase()}%'],
    );
    return result.map((json) => Song.fromMap(json)).toList();
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

  Future<bool> addSongToList(int listId, int songId) async {
    final db = await database;

    // Prevent duplicate song in the same list
    final existing = await db.query(
      'list_songs',
      where: 'listId = ? AND songId = ?',
      whereArgs: [listId, songId],
    );
    if (existing.isNotEmpty) return false;

    // Get the max order for this list
    final result = await db.rawQuery(
      'SELECT MAX(`order`) as maxOrder FROM list_songs WHERE listId = ?',
      [listId],
    );

    final maxOrder = result.first['maxOrder'] as int? ?? -1;

    await db.insert('list_songs', {
      'listId': listId,
      'songId': songId,
      'order': maxOrder + 1,
    });
    return true;
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
      ORDER BY list_songs.`order` ASC
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

  Future<void> _createBibleHistoryTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS bible_verse_history (
        id        INTEGER PRIMARY KEY AUTOINCREMENT,
        bookEnglish TEXT NOT NULL,
        bookTamil   TEXT NOT NULL,
        chapter     INTEGER NOT NULL,
        verseNumber INTEGER NOT NULL,
        verseText   TEXT,
        timestamp   TEXT NOT NULL
      )
    ''');
  }

  // ==================== BIBLE HISTORY ====================

  Future<void> insertBibleHistory({
    required String bookEnglish,
    required String bookTamil,
    required int chapter,
    required int verseNumber,
    required String verseText,
  }) async {
    final db = await database;
    // Avoid consecutive duplicate
    final last = await db.query(
      'bible_verse_history',
      orderBy: 'id DESC',
      limit: 1,
    );
    if (last.isNotEmpty &&
        last.first['bookEnglish'] == bookEnglish &&
        last.first['chapter'] == chapter &&
        last.first['verseNumber'] == verseNumber) {
      return;
    }
    await db.insert('bible_verse_history', {
      'bookEnglish': bookEnglish,
      'bookTamil': bookTamil,
      'chapter': chapter,
      'verseNumber': verseNumber,
      'verseText': verseText,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Returns all history rows ordered most-recent first.
  Future<List<Map<String, dynamic>>> getBibleHistory() async {
    final db = await database;
    return db.query('bible_verse_history', orderBy: 'id DESC');
  }

  Future<void> clearBibleHistory() async {
    final db = await database;
    await db.delete('bible_verse_history');
  }

  Future<void> close() async {
    final db = await database;
    db.close();
  }

  // ==================== SYNC META ====================

  /// Returns the timestamp of the last successful sync, or null if never synced.
  Future<DateTime?> getLastSyncedAt() async {
    final db = await database;
    final result = await db.query(
      'sync_meta',
      where: 'key = ?',
      whereArgs: ['last_synced_at'],
    );
    if (result.isEmpty) return null;
    return DateTime.tryParse(result.first['value'] as String);
  }

  /// Persists the last-synced timestamp.
  Future<void> saveLastSyncedAt(DateTime dt) async {
    final db = await database;
    await db.insert('sync_meta', {
      'key': 'last_synced_at',
      'value': dt.toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // ==================== SYNC SONG INDEX ====================

  /// Returns the set of remote IDs stored in the local song index table.
  Future<Set<String>> getAllLocalSongIndexIds() async {
    final db = await database;
    final result = await db.query('sync_song_index', columns: ['remote_id']);
    return result.map((r) => r['remote_id'] as String).toSet();
  }

  /// Upserts a batch of song index records (insert or replace).
  Future<void> upsertSongIndexBatch(List<SyncSongIndex> records) async {
    final db = await database;
    final batch = db.batch();
    for (final r in records) {
      batch.insert(
        'sync_song_index',
        r.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  // ==================== SYNC SONG DETAIL ====================

  /// Returns the set of remote IDs that already have full detail stored locally.
  Future<Set<String>> getLocalSongDetailIds() async {
    final db = await database;
    final result = await db.query('sync_song_detail', columns: ['remote_id']);
    return result.map((r) => r['remote_id'] as String).toSet();
  }

  /// Returns the count of fully-synced song detail records.
  Future<int> getSyncedSongCount() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS cnt FROM sync_song_detail',
    );
    return (result.first['cnt'] as int?) ?? 0;
  }

  /// Returns the subset of [remoteIds] that are NOT yet in the local detail table.
  Future<List<String>> getMissingSongIds(List<String> remoteIds) async {
    final localIds = await getLocalSongDetailIds();
    return remoteIds.where((id) => !localIds.contains(id)).toList();
  }

  /// Upserts a batch of song detail records (insert or replace).
  Future<void> upsertSongDetailBatch(List<SyncSongDetail> records) async {
    final db = await database;
    final batch = db.batch();
    for (final r in records) {
      batch.insert(
        'sync_song_detail',
        r.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  /// Returns only remote_id + title for songs starting with [letter].
  /// Much lighter than loading full lyrics — use this for list views.
  /// Optionally pass [search] to do a SQL-level title filter.
  Future<List<({String remoteId, String title})>>
  getSyncedSongTitlesByFirstLetter(String letter, {String? search}) async {
    final db = await database;
    late final List<Map<String, dynamic>> rows;
    if (search != null && search.isNotEmpty) {
      rows = await db.query(
        'sync_song_detail',
        columns: ['remote_id', 'title'],
        where: 'title LIKE ? AND LOWER(title) LIKE ?',
        whereArgs: ['$letter%', '%${search.toLowerCase()}%'],
        orderBy: 'title ASC',
      );
    } else {
      rows = await db.query(
        'sync_song_detail',
        columns: ['remote_id', 'title'],
        where: 'title LIKE ?',
        whereArgs: ['$letter%'],
        orderBy: 'title ASC',
      );
    }
    return rows
        .map(
          (r) =>
              (remoteId: r['remote_id'] as String, title: r['title'] as String),
        )
        .toList();
  }

  /// Fetches a single full song detail record by its remote ID.
  /// Returns null if the song is not yet synced.
  Future<SyncSongDetail?> getSyncedSongDetailById(String remoteId) async {
    final db = await database;
    final rows = await db.query(
      'sync_song_detail',
      where: 'remote_id = ?',
      whereArgs: [remoteId],
    );
    if (rows.isEmpty) return null;
    return SyncSongDetail.fromMap(rows.first);
  }

  /// Returns detail records whose title starts with [letter].
  Future<List<SyncSongDetail>> getSyncedSongsByFirstLetter(
    String letter,
  ) async {
    final db = await database;
    // Use glob-style pattern; works for Unicode in SQLite.
    final result = await db.query(
      'sync_song_detail',
      where: 'title LIKE ?',
      whereArgs: ['$letter%'],
      orderBy: 'title ASC',
    );
    return result.map(SyncSongDetail.fromMap).toList();
  }

  /// Full-text search across title and lyrics in synced songs.
  Future<List<SyncSongDetail>> searchSyncedSongs(String query) async {
    final db = await database;
    final lower = query.toLowerCase();
    final result = await db.query(
      'sync_song_detail',
      where: 'LOWER(title) LIKE ? OR LOWER(lyrics) LIKE ?',
      whereArgs: ['%$lower%', '%$lower%'],
      orderBy: 'title ASC',
    );
    return result.map(SyncSongDetail.fromMap).toList();
  }
}
