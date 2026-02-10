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
    _database = await _initDB('vocabulary_v4.db'); // Incremented version
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getApplicationDocumentsDirectory();
    final path = join(dbPath.path, filePath);

    // Copy from assets if not exists
    if (FileSystemEntity.typeSync(path) == FileSystemEntityType.notFound) {
      ByteData data = await rootBundle.load('assets/vocabulary.db');
      List<int> bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      await File(path).writeAsBytes(bytes);
    }

    final db = await openDatabase(path, version: 1);
    
    // Create user_stats table with 'current_grade' and 'current_step'
    await db.execute('''
      CREATE TABLE IF NOT EXISTS user_stats (
        id INTEGER PRIMARY KEY,
        current_grade INTEGER DEFAULT 1,
        current_step INTEGER DEFAULT 1,
        tokens INTEGER DEFAULT 0
      )
    ''');
    
    // Initialize stats if empty
    final count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM user_stats'));
    if (count == 0) {
      await db.insert('user_stats', {'id': 1, 'current_grade': 1, 'current_step': 1, 'tokens': 0});
    }

    return db;
  }

  Future<Map<String, dynamic>> getUserStats() async {
    final db = await instance.database;
    final result = await db.query('user_stats', where: 'id = ?', whereArgs: [1]);
    if (result.isNotEmpty) {
      return result.first;
    }
    return {'current_grade': 1, 'current_step': 1, 'tokens': 0};
  }

  Future<void> updateTokens(int additionalTokens) async {
    final db = await instance.database;
    await db.rawUpdate('UPDATE user_stats SET tokens = tokens + ? WHERE id = 1', [additionalTokens]);
  }

  Future<void> advanceStep(int grade, int stepCompleted) async {
    final db = await instance.database;
    
    // Check if there are more words in this grade
    int nextStep = stepCompleted + 1;
    int offset = (nextStep - 1) * 10;
    
    final nextWords = await db.rawQuery(
      'SELECT id FROM vocabulary WHERE grade = ? LIMIT 1 OFFSET ?', 
      [grade, offset]
    );

    if (nextWords.isNotEmpty) {
      // Advance step within the same grade
      await db.rawUpdate(
        'UPDATE user_stats SET current_step = ? WHERE id = 1 AND current_grade = ? AND current_step = ?', 
        [nextStep, grade, stepCompleted]
      );
    } else {
      // Move to next grade, reset step to 1
      await db.rawUpdate(
        'UPDATE user_stats SET current_grade = current_grade + 1, current_step = 1 WHERE id = 1 AND current_grade = ? AND current_step = ?', 
        [grade, stepCompleted]
      );
    }
  }

  Future<List<Word>> getWordsForStep(int grade, int step) async {
    final db = await instance.database;
    int limit = 10;
    int offset = (step - 1) * 10;
    final result = await db.rawQuery(
      'SELECT * FROM vocabulary WHERE grade = ? LIMIT ? OFFSET ?', 
      [grade, limit, offset]
    );
    return result.map((json) => Word.fromMap(json)).toList();
  }

  Future<int> getTotalStepsForGrade(int grade) async {
    final db = await instance.database;
    final result = await db.rawQuery('SELECT COUNT(*) FROM vocabulary WHERE grade = ?', [grade]);
    int count = Sqflite.firstIntValue(result) ?? 0;
    return (count / 10).ceil();
  }
}