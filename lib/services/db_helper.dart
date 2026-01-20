import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../models/word.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('vocabulary_v3.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getApplicationDocumentsDirectory();
    final path = join(dbPath.path, filePath);

    // Always copy from assets if it's a new version/file to ensure hints are there
    if (FileSystemEntity.typeSync(path) == FileSystemEntityType.notFound) {
      ByteData data = await rootBundle.load('assets/vocabulary.db');
      List<int> bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      await File(path).writeAsBytes(bytes);
    }

    final db = await openDatabase(path, version: 1);
    
    // Create user_stats table with 'current_stage'
    await db.execute('''
      CREATE TABLE IF NOT EXISTS user_stats (
        id INTEGER PRIMARY KEY,
        current_stage INTEGER DEFAULT 1,
        tokens INTEGER DEFAULT 0
      )
    ''');
    
    // Initialize stats if empty
    final count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM user_stats'));
    if (count == 0) {
      await db.insert('user_stats', {'id': 1, 'current_stage': 1, 'tokens': 0});
    }

    // Check for hint column and add if missing (redundant if we copied fresh asset, but safe)
    try {
      await db.rawQuery('SELECT hint FROM vocabulary LIMIT 1');
    } catch (e) {
      // Add hint column if it doesn't exist (legacy support)
      await db.execute('ALTER TABLE vocabulary ADD COLUMN hint TEXT');
    }

    return db;
  }

  Future<Map<String, dynamic>> getUserStats() async {
    final db = await instance.database;
    final result = await db.query('user_stats', where: 'id = ?', whereArgs: [1]);
    if (result.isNotEmpty) {
      return result.first;
    }
    return {'current_stage': 1, 'tokens': 0};
  }

  Future<void> updateTokens(int additionalTokens) async {
    final db = await instance.database;
    await db.rawUpdate('UPDATE user_stats SET tokens = tokens + ? WHERE id = 1', [additionalTokens]);
  }

  Future<void> advanceStage(int stageCompleted) async {
    final db = await instance.database;
    // Only advance if the user just completed their current highest stage
    await db.rawUpdate(
      'UPDATE user_stats SET current_stage = current_stage + 1 WHERE id = 1 AND current_stage = ?', 
      [stageCompleted]
    );
  }

  Future<void> resetDatabase() async {
    final dbPath = await getApplicationDocumentsDirectory();
    final path = join(dbPath.path, 'vocabulary_v3.db');
    
    // Close existing connection
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
    
    // Delete the file
    if (await File(path).exists()) {
      await File(path).delete();
    }
  }

  Future<List<Word>> getAllWords() async {
    final db = await instance.database;
    final result = await db.query('vocabulary');
    return result.map((json) => Word.fromMap(json)).toList();
  }

  Future<List<Word>> getWordsForStage(int stage) async {
    final db = await instance.database;
    int limit = 10;
    int offset = (stage - 1) * 10;
    final result = await db.rawQuery('SELECT * FROM vocabulary LIMIT ? OFFSET ?', [limit, offset]);
    return result.map((json) => Word.fromMap(json)).toList();
  }

  Future<List<Word>> getWordsUpToStage(int stage, int count) async {
    final db = await instance.database;
    int maxIndex = stage * 10;
    final result = await db.rawQuery(
      'SELECT * FROM vocabulary WHERE id <= ? ORDER BY RANDOM() LIMIT ?', 
      [maxIndex, count]
    );
    return result.map((json) => Word.fromMap(json)).toList();
  }

  Future<List<Word>> getAllUnlockedWords(int stage) async {
    final db = await instance.database;
    int maxIndex = stage * 10;
    // Fetch all words up to the current stage limit
    final result = await db.rawQuery('SELECT * FROM vocabulary WHERE id <= ? ORDER BY id ASC', [maxIndex]);
    return result.map((json) => Word.fromMap(json)).toList();
  }

  Future<List<Word>> getRandomWords(int count) async {
    final db = await instance.database;
    final result = await db.rawQuery('SELECT * FROM vocabulary ORDER BY RANDOM() LIMIT ?', [count]);
    return result.map((json) => Word.fromMap(json)).toList();
  }
}