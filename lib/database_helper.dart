import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('save_app.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 4,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        url TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        caption TEXT,
        creator TEXT,
        thumbnail TEXT,
        tags TEXT,
        collection TEXT
      )
    ''');
    await _createFtsTable(db);
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) await _createFtsTable(db);
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE items ADD COLUMN caption TEXT');
      await db.execute('ALTER TABLE items ADD COLUMN creator TEXT');
      await db.execute('ALTER TABLE items ADD COLUMN thumbnail TEXT');
    }
    if (oldVersion < 4) {
      await db.execute('ALTER TABLE items ADD COLUMN tags TEXT');
      await db.execute('ALTER TABLE items ADD COLUMN collection TEXT');
      
      // Recreate FTS table to include tags
      await db.execute('DROP TABLE IF EXISTS items_fts');
      await _createFtsTable(db);
      
      // Populate FTS table with existing data
      await db.execute('''
        INSERT INTO items_fts(rowid, url, caption, tags)
        SELECT id, url, caption, tags FROM items
      ''');
    }
  }

  Future _createFtsTable(Database db) async {
    await db.execute('CREATE VIRTUAL TABLE items_fts USING fts5(url, caption, tags, content="items", content_rowid="id")');

    await db.execute('DROP TRIGGER IF EXISTS items_ai');
    await db.execute('DROP TRIGGER IF EXISTS items_ad');
    await db.execute('DROP TRIGGER IF EXISTS items_au');

    await db.execute('''
      CREATE TRIGGER items_ai AFTER INSERT ON items BEGIN
        INSERT INTO items_fts(rowid, url, caption, tags) VALUES (new.id, new.url, new.caption, new.tags);
      END;
    ''');
    await db.execute('''
      CREATE TRIGGER items_ad AFTER DELETE ON items BEGIN
        INSERT INTO items_fts(items_fts, rowid, url, caption, tags) VALUES('delete', old.id, old.url, old.caption, old.tags);
      END;
    ''');
    await db.execute('''
      CREATE TRIGGER items_au AFTER UPDATE ON items BEGIN
        INSERT INTO items_fts(items_fts, rowid, url, caption, tags) VALUES('delete', old.id, old.url, old.caption, old.tags);
        INSERT INTO items_fts(rowid, url, caption, tags) VALUES (new.id, new.url, new.caption, new.tags);
      END;
    ''');
  }

  Future<int> insertItem(String url, {String? caption, String? creator, String? thumbnail, String? tags, String? collection}) async {
    final db = await instance.database;
    final row = {
      'url': url,
      'timestamp': DateTime.now().toIso8601String(),
      'caption': caption,
      'creator': creator,
      'thumbnail': thumbnail,
      'tags': tags,
      'collection': collection,
    };
    return await db.insert('items', row);
  }

  Future<List<Map<String, dynamic>>> fetchItems() async {
    final db = await instance.database;
    return await db.query('items', orderBy: 'id DESC');
  }

  Future<List<Map<String, dynamic>>> searchItems(String query) async {
    final db = await instance.database;
    // Using FTS MATCH operator for efficient searching
    return await db.rawQuery('''
      SELECT items.* FROM items
      JOIN items_fts ON items.id = items_fts.rowid
      WHERE items_fts MATCH ?
      ORDER BY rank
    ''', [query]);
  }

  Future close() async {
    final db = await _database;
    if (db != null) {
      await db.close();
    }
  }
}
