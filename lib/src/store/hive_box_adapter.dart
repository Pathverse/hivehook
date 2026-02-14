import 'package:hive_ce/hive.dart';

/// Abstract adapter for Hive box operations.
///
/// Provides a unified interface for both [CollectionBox] and [Box],
/// allowing [HBoxStore] to work with either storage type.
abstract class HiveBoxAdapter<E> {
  /// Gets a value by key.
  Future<E?> get(String key);

  /// Puts a value at key.
  Future<void> put(String key, E value);

  /// Deletes a value by key.
  Future<void> delete(String key);

  /// Gets all keys in the box.
  Future<List<String>> getAllKeys();

  /// Gets all key-value pairs in the box.
  Future<Map<String, E>> getAllValues();

  /// Clears all entries in the box (ignores env scoping).
  Future<void> clearAll();
}

/// Adapter for [CollectionBox] (used with BoxCollection).
class CollectionBoxAdapter<E> implements HiveBoxAdapter<E> {
  final CollectionBox<E> _box;

  CollectionBoxAdapter(this._box);

  @override
  Future<E?> get(String key) => _box.get(key);

  @override
  Future<void> put(String key, E value) => _box.put(key, value);

  @override
  Future<void> delete(String key) => _box.delete(key);

  @override
  Future<List<String>> getAllKeys() => _box.getAllKeys();

  @override
  Future<Map<String, E>> getAllValues() => _box.getAllValues();

  @override
  Future<void> clearAll() => _box.clear();
}

/// Adapter for regular [Box] (used with Hive.openBox).
class RegularBoxAdapter<E> implements HiveBoxAdapter<E> {
  final Box<E> _box;

  RegularBoxAdapter(this._box);

  @override
  Future<E?> get(String key) async => _box.get(key);

  @override
  Future<void> put(String key, E value) => _box.put(key, value);

  @override
  Future<void> delete(String key) => _box.delete(key);

  @override
  Future<List<String>> getAllKeys() async =>
      _box.keys.map((k) => k.toString()).toList();

  @override
  Future<Map<String, E>> getAllValues() async {
    final result = <String, E>{};
    for (final key in _box.keys) {
      final value = _box.get(key);
      if (value != null) {
        result[key.toString()] = value;
      }
    }
    return result;
  }

  @override
  Future<void> clearAll() => _box.clear();
}
