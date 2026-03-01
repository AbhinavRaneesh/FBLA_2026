import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:mongo_dart/mongo_dart.dart';

class MongoDbService {
  static Db? _db;
  static String? _connectedUri;
  static String? _configuredUri;
  static bool _indexesEnsured = false;
  static String? _lastInitError;

  static bool get isConnected => _db?.isConnected ?? false;
  static String? get connectedUri => _connectedUri;
  static String? get lastInitError => _lastInitError;

  static void configureUri(String uri) {
    final value = uri.trim();
    if (value.isNotEmpty) {
      _configuredUri = value;
    }
  }

  static String _redactUri(String uri) {
    final atIndex = uri.indexOf('@');
    final schemeIndex = uri.indexOf('://');
    final colonAfterScheme =
        schemeIndex >= 0 ? uri.indexOf(':', schemeIndex + 3) : -1;
    if (atIndex > 0 && colonAfterScheme > 0 && colonAfterScheme < atIndex) {
      return '${uri.substring(0, colonAfterScheme + 1)}***${uri.substring(atIndex)}';
    }
    return uri;
  }

  static Future<bool> initialize({String? connectionString}) async {
    final provided = connectionString?.trim() ?? '';
    if (provided.isNotEmpty) {
      _configuredUri = provided;
    }

    if (kIsWeb) {
      _lastInitError = 'MongoDB is not supported on Flutter web via mongo_dart.';
      debugPrint(_lastInitError);
      return false;
    }

    if (isConnected) {
      _lastInitError = null;
      return true;
    }

    final uri = (_configuredUri ??
        connectionString ??
        const String.fromEnvironment('MONGODB_URI'))
      .trim();
    if (uri.isEmpty) {
      _lastInitError = 'MongoDB init skipped: MONGODB_URI not provided.';
      debugPrint(_lastInitError);
      return false;
    }

    try {
      debugPrint('MongoDB attempting connection: ${_redactUri(uri)}');
      final db = await Db.create(uri);
      await db.open();

      _db = db;
      _connectedUri = uri;
      _lastInitError = null;
      await _ensureIndexes();
      debugPrint('MongoDB Atlas connected successfully.');
      return true;
    } catch (e) {
      _lastInitError = e.toString();
      debugPrint('MongoDB connection failed: $_lastInitError');
      return false;
    }
  }

  static Future<void> _ensureConnectedOrThrow() async {
    if (isConnected) return;

    final ok = await initialize(connectionString: _configuredUri);
    if (ok) return;

    final reason = _lastInitError ?? 'unknown reason';
    throw Exception('MongoDB is not connected. Details: $reason');
  }

  static DbCollection collection(String name) {
    final db = _db;
    if (db == null || !db.isConnected) {
      throw StateError('MongoDB is not connected. Call MongoDbService.initialize() first.');
    }
    return db.collection(name);
  }

  static Future<void> _ensureIndexes() async {
    if (_indexesEnsured || !isConnected) return;
    final users = collection('users');
    await users.createIndex(keys: {'email': 1}, unique: true, name: 'email_unique');
    _indexesEnsured = true;
  }

  static String _hashPassword(String password) {
    return sha256.convert(utf8.encode(password)).toString();
  }

  static String _normalizeEmail(String email) {
    return email.trim().toLowerCase();
  }

  static Future<Map<String, dynamic>> createUser({
    required String email,
    required String password,
    required String name,
    required String role,
    required String gradeLevel,
  }) async {
    await _ensureConnectedOrThrow();

    final normalizedEmail = _normalizeEmail(email);
    final users = collection('users');
    final existing = await users.findOne(where.eq('email', normalizedEmail));
    if (existing != null) {
      throw Exception('An account with this email already exists.');
    }

    final nowIso = DateTime.now().toUtc().toIso8601String();
    final Map<String, dynamic> userDoc = {
      'email': normalizedEmail,
      'name': name.trim(),
      'role': role.trim(),
      'gradeLevel': gradeLevel.trim(),
      'passwordHash': _hashPassword(password),
      'createdAt': nowIso,
      'updatedAt': nowIso,
    };

    await users.insertOne(userDoc);

    return {
      'email': normalizedEmail,
      'name': name.trim(),
      'role': role.trim(),
      'gradeLevel': gradeLevel.trim(),
    };
  }

  static Future<Map<String, dynamic>> loginUser({
    required String email,
    required String password,
  }) async {
    await _ensureConnectedOrThrow();

    final normalizedEmail = _normalizeEmail(email);
    final users = collection('users');
    final userDoc = await users.findOne(where.eq('email', normalizedEmail));
    if (userDoc == null) {
      throw Exception('No account found for this email.');
    }

    final storedHash = (userDoc['passwordHash'] ?? '').toString();
    final incomingHash = _hashPassword(password);
    if (storedHash != incomingHash) {
      throw Exception('Incorrect password.');
    }

    return {
      'email': normalizedEmail,
      'name': (userDoc['name'] ?? '').toString(),
      'role': (userDoc['role'] ?? '').toString(),
      'gradeLevel': (userDoc['gradeLevel'] ?? '').toString(),
    };
  }

  static Future<void> close() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
      _connectedUri = null;
      _indexesEnsured = false;
    }
  }
}
