import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists the whole app state as one JSON document.
abstract interface class SafetyStorage {
  Future<Map<String, dynamic>?> read();
  Future<void> write(Map<String, dynamic> data);
  Future<void> delete();
}

/// Encrypted on-device storage (Android Keystore / iOS Keychain).
class SecureSafetyStorage implements SafetyStorage {
  SecureSafetyStorage();

  static const _key = 'guardian.state.v3';
  final _storage = const FlutterSecureStorage();

  @override
  Future<Map<String, dynamic>?> read() async {
    final raw = await _storage.read(key: _key);
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } on FormatException {
      return null; // Corrupt data: start fresh rather than crash on launch.
    }
  }

  @override
  Future<void> write(Map<String, dynamic> data) =>
      _storage.write(key: _key, value: jsonEncode(data));

  @override
  Future<void> delete() => _storage.delete(key: _key);
}

/// In-memory storage for tests.
class MemorySafetyStorage implements SafetyStorage {
  MemorySafetyStorage([this.data]);

  Map<String, dynamic>? data;

  @override
  Future<Map<String, dynamic>?> read() async => data == null
      ? null
      : jsonDecode(jsonEncode(data)) as Map<String, dynamic>;

  @override
  Future<void> write(Map<String, dynamic> value) async =>
      data = jsonDecode(jsonEncode(value)) as Map<String, dynamic>;

  @override
  Future<void> delete() async => data = null;
}
