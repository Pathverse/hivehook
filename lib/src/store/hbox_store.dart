import 'dart:convert';

import 'package:hive_ce/hive.dart';
import 'package:hihook/interfaces/hi_store.dart';

import '../core/hive_config.dart';

/// Pure Hive storage implementation of [HiStore].
///
/// This class handles only storage operations - no event emission.
/// Event emission is handled by [HHive] facade.
///
/// Storage modes:
/// - [HiveStorageMode.json]: Values are JSON encoded/decoded (default)
/// - [HiveStorageMode.native]: Values stored directly using Hive type adapters
///
/// Metadata (if enabled) is stored in a separate box with namespaced keys.
class HBoxStore implements HiStore<String, dynamic> {
  /// The main data box.
  final CollectionBox<dynamic> box;

  /// The metadata box (null if metadata not enabled).
  final CollectionBox<String>? metaBox;

  /// Environment name (used for metadata key namespacing).
  final String env;

  /// Storage mode (json or native).
  final HiveStorageMode storageMode;

  /// Custom JSON encoder for non-JSON-serializable types.
  final HiveJsonEncoder? jsonEncoder;

  /// Custom JSON decoder/reviver for non-JSON-serializable types.
  final HiveJsonDecoder? jsonDecoder;

  /// Creates an HBoxStore with the given Hive boxes.
  HBoxStore({
    required this.box,
    required this.metaBox,
    required this.env,
    this.storageMode = HiveStorageMode.json,
    this.jsonEncoder,
    this.jsonDecoder,
  });

  @override
  bool get supportsMeta => metaBox != null;

  /// Whether using JSON storage mode.
  bool get isJsonMode => storageMode == HiveStorageMode.json;

  /// Encodes a value to JSON string.
  String _encode(dynamic value) => jsonEncode(value, toEncodable: jsonEncoder);

  /// Decodes a JSON string to value.
  dynamic _decode(String raw) => jsonDecode(raw, reviver: jsonDecoder);

  /// Namespaced data key: {env}::{key}
  /// This prevents cross-contamination between envs sharing the same box.
  String _dataKey(String key) => '$env::$key';

  /// Strips the env prefix from a stored key.
  /// Returns null if the key doesn't belong to this env.
  String? _stripPrefix(String storedKey) {
    final prefix = '$env::';
    if (storedKey.startsWith(prefix)) {
      return storedKey.substring(prefix.length);
    }
    return null;
  }

  @override
  Future<dynamic> get(String key) async {
    final raw = await box.get(_dataKey(key));
    if (raw == null) return null;
    return isJsonMode ? _decode(raw as String) : raw;
  }

  @override
  Future<void> put(String key, dynamic value) async {
    final storedValue = isJsonMode ? _encode(value) : value;
    await box.put(_dataKey(key), storedValue);
  }

  @override
  Future<void> delete(String key) async {
    await box.delete(_dataKey(key));
  }

  @override
  Future<void> clear() async {
    // Only clear keys for this env (not the entire box)
    final prefix = '$env::';
    final allKeys = await box.getAllKeys();
    for (final key in allKeys) {
      if (key.startsWith(prefix)) {
        await box.delete(key);
      }
    }
  }

  @override
  Stream<String> keys() async* {
    final allKeys = await box.getAllKeys();
    for (final storedKey in allKeys) {
      final key = _stripPrefix(storedKey);
      if (key != null) {
        yield key;
      }
    }
  }

  @override
  Stream<dynamic> values() async* {
    final allValues = await box.getAllValues();
    for (final entry in allValues.entries) {
      // Only yield values for this env
      if (_stripPrefix(entry.key) != null) {
        yield isJsonMode ? _decode(entry.value as String) : entry.value;
      }
    }
  }

  @override
  Stream<MapEntry<String, dynamic>> entries() async* {
    final allValues = await box.getAllValues();
    for (final entry in allValues.entries) {
      final key = _stripPrefix(entry.key);
      if (key != null) {
        final value = isJsonMode ? _decode(entry.value as String) : entry.value;
        yield MapEntry(key, value);
      }
    }
  }

  // --- Metadata Methods ---

  /// Namespaced metadata key: {env}::{key}
  String _metaKey(String key) => '$env::$key';

  @override
  Future<Map<String, dynamic>?> getMeta(String key) async {
    if (metaBox == null) return null;
    final raw = await metaBox!.get(_metaKey(key));
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  @override
  Future<void> putMeta(String key, Map<String, dynamic> meta) async {
    if (metaBox == null) return;
    await metaBox!.put(_metaKey(key), jsonEncode(meta));
  }

  @override
  Future<void> deleteMeta(String key) async {
    if (metaBox == null) return;
    await metaBox!.delete(_metaKey(key));
  }

  @override
  Future<void> clearMeta() async {
    if (metaBox == null) return;
    // Only clear keys for this env
    final prefix = '$env::';
    final allKeys = await metaBox!.getAllKeys();
    final keysToDelete = allKeys.where((k) => k.startsWith(prefix));
    for (final key in keysToDelete) {
      await metaBox!.delete(key);
    }
  }
}
