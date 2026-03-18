import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/event_config.dart';
import '../models/photo.dart';
import '../models/send_queue_item.dart';

class DatabaseService {
  static Database? _database;

  Future<Database> get database async {
    _database ??= await _initDb();
    return _database!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'tronche.db');
    return openDatabase(path, version: 1, onCreate: _createTables);
  }

  Future<void> _createTables(Database db, int version) async {
    await db.execute('''
      CREATE TABLE event_config (
        id INTEGER PRIMARY KEY,
        server_event_id TEXT,
        user_email TEXT NOT NULL,
        jwt_token TEXT NOT NULL,
        refresh_token TEXT NOT NULL,
        name1 TEXT NOT NULL,
        name2 TEXT NOT NULL,
        event_date TEXT NOT NULL,
        overlay_template TEXT DEFAULT 'elegant',
        overlay_config TEXT DEFAULT '{}',
        timer_duration INTEGER DEFAULT 3,
        admin_password_hash TEXT NOT NULL,
        share_code TEXT NOT NULL,
        plan TEXT DEFAULT 'free'
      )
    ''');
    await db.execute('''
      CREATE TABLE photos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        local_path TEXT NOT NULL,
        thumbnail_path TEXT,
        photo_code TEXT UNIQUE NOT NULL,
        taken_at TEXT NOT NULL,
        is_synced INTEGER DEFAULT 0,
        server_photo_id TEXT,
        synced_at TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE send_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        photo_id INTEGER REFERENCES photos(id),
        type TEXT NOT NULL,
        recipient TEXT,
        status TEXT DEFAULT 'pending',
        attempts INTEGER DEFAULT 0,
        last_error TEXT,
        created_at TEXT NOT NULL,
        sent_at TEXT
      )
    ''');
  }

  // Event Config

  Future<EventConfig?> getEventConfig() async {
    final db = await database;
    final maps = await db.query('event_config', limit: 1);
    if (maps.isEmpty) return null;
    return EventConfig.fromMap(maps.first);
  }

  Future<void> saveEventConfig(EventConfig config) async {
    final db = await database;
    await db.delete('event_config');
    await db.insert('event_config', config.toMap());
  }

  Future<void> updateEventConfig(Map<String, dynamic> updates) async {
    final db = await database;
    await db.update('event_config', updates);
  }

  Future<void> clearEventConfig() async {
    final db = await database;
    await db.delete('event_config');
  }

  // Photos

  Future<int> insertPhoto(Photo photo) async {
    final db = await database;
    return db.insert('photos', photo.toMap());
  }

  Future<List<Photo>> getAllPhotos() async {
    final db = await database;
    final maps = await db.query('photos', orderBy: 'taken_at DESC');
    return maps.map(Photo.fromMap).toList();
  }

  Future<List<Photo>> getUnsyncedPhotos() async {
    final db = await database;
    final maps = await db.query(
      'photos',
      where: 'is_synced = 0',
      orderBy: 'taken_at ASC',
    );
    return maps.map(Photo.fromMap).toList();
  }

  Future<void> markPhotoSynced(int id, String serverPhotoId) async {
    final db = await database;
    await db.update(
      'photos',
      {
        'is_synced': 1,
        'server_photo_id': serverPhotoId,
        'synced_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deletePhoto(int id) async {
    final db = await database;
    // Also delete orphaned send_queue items for this photo
    await db.delete('send_queue', where: 'photo_id = ?', whereArgs: [id]);
    await db.delete('photos', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> getPhotoCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM photos');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> getSyncedPhotoCount() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM photos WHERE is_synced = 1',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // Send Queue

  Future<int> insertSendQueueItem(SendQueueItem item) async {
    final db = await database;
    return db.insert('send_queue', item.toMap());
  }

  Future<List<SendQueueItem>> getPendingQueueItems() async {
    final db = await database;
    final maps = await db.query(
      'send_queue',
      where: "status IN ('pending', 'failed')",
      orderBy: 'created_at ASC',
    );
    return maps.map(SendQueueItem.fromMap).toList();
  }

  Future<List<SendQueueItem>> getAllQueueItems() async {
    final db = await database;
    final maps = await db.query('send_queue', orderBy: 'created_at DESC');
    return maps.map(SendQueueItem.fromMap).toList();
  }

  Future<void> updateQueueItemStatus(
    int id,
    String status, {
    String? error,
    DateTime? sentAt,
  }) async {
    final db = await database;
    final rows = await db.query(
      'send_queue',
      where: 'id = ?',
      whereArgs: [id],
    );
    final currentAttempts = rows.isNotEmpty ? (rows.first['attempts'] as int) : 0;
    final updates = <String, dynamic>{
      'status': status,
      'attempts': currentAttempts + 1,
    };
    if (error != null) updates['last_error'] = error;
    if (sentAt != null) updates['sent_at'] = sentAt.toIso8601String();
    await db.update('send_queue', updates, where: 'id = ?', whereArgs: [id]);
  }

  /// Removes send_queue items that reference deleted photos.
  Future<void> cleanOrphanedQueueItems() async {
    final db = await database;
    await db.rawDelete(
      'DELETE FROM send_queue WHERE photo_id NOT IN (SELECT id FROM photos)',
    );
  }

  Future<int> getPendingQueueCount() async {
    final db = await database;
    final result = await db.rawQuery(
      "SELECT COUNT(*) as count FROM send_queue WHERE status IN ('pending', 'failed')",
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }
}
