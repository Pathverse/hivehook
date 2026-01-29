import 'package:hihook/src/engine/engine.dart';
import 'package:hihook/src/core/payload.dart';
import 'package:hihook/src/core/result.dart';

import 'core/hive_config.dart';
import 'core/hive_core.dart';
import 'store/hbox_store.dart';

/// User-facing facade for Hive storage with hihook integration.
///
/// HHive handles:
/// - Resolving the correct store via [HHiveCore]
/// - Emitting events to [HiEngine] for hook execution
/// - Providing convenience methods that bundle value + metadata
///
/// Usage:
/// ```dart
/// // Setup
/// HHiveCore.register(HiveConfig(env: 'users', withMeta: true));
/// await HHiveCore.initialize();
///
/// // Create instance
/// final hive = await HHive.create('users');
///
/// // CRUD operations
/// await hive.put('user:1', {'name': 'Alice'});
/// final user = await hive.get<Map>('user:1');
/// await hive.delete('user:1');
/// ```
class HHive {
  /// Cached instances per environment.
  static final Map<String, HHive> _instances = {};

  /// The configuration for this environment.
  final HiveConfig config;

  /// The hihook engine for this environment.
  final HiEngine engine;

  /// The underlying store.
  final HBoxStore _store;

  HHive._({
    required this.config,
    required this.engine,
    required HBoxStore store,
  }) : _store = store;

  /// Creates or returns the cached HHive instance for the given environment.
  ///
  /// The environment must be registered and initialized via [HHiveCore].
  /// Subsequent calls with the same env return the cached instance.
  static Future<HHive> create(String env) async {
    // Return cached instance
    if (_instances.containsKey(env)) {
      return _instances[env]!;
    }

    final config = HHiveCore.configs[env];
    if (config == null) {
      throw StateError(
        'No config registered for env "$env". '
        'Call HHiveCore.register() first.',
      );
    }

    final store = await HHiveCore.getStore(env);
    // Merge global hooks + config hooks
    final hooks = HHiveCore.getHooksFor(env);
    final engine = HiEngine(hooks: hooks);

    final instance = HHive._(
      config: config,
      engine: engine,
      store: store,
    );

    _instances[env] = instance;
    return instance;
  }

  /// Creates an HHive instance from a config without global registration.
  ///
  /// This is useful for one-off scenarios or testing where you don't want
  /// to pollute the global registry. Each call creates a new instance.
  ///
  /// ```dart
  /// final hive = await HHive.createFromConfig(HiveConfig(
  ///   env: 'temp',
  ///   hooks: [myValidationHook],
  /// ));
  /// ```
  static Future<HHive> createFromConfig(HiveConfig config) async {
    // Register temporarily if not registered
    final wasRegistered = HHiveCore.configs.containsKey(config.env);
    if (!wasRegistered) {
      HHiveCore.register(config);
      // Ensure initialized
      if (!HHiveCore.isInitialized) {
        await HHiveCore.initialize();
      }
    }

    // Clear any cached instance to get fresh hooks
    _instances.remove(config.env);

    // Create with the provided config's hooks
    final store = await HHiveCore.getStore(config.env);
    final hooks = [...HHiveCore.globalHooks, ...config.hooks];
    final engine = HiEngine(hooks: hooks);

    final instance = HHive._(
      config: config,
      engine: engine,
      store: store,
    );

    _instances[config.env] = instance;
    return instance;
  }

  /// Clears the cached instance for an environment.
  ///
  /// Next call to [create] will create a fresh instance.
  static void dispose(String env) {
    _instances.remove(env);
  }

  /// Clears all cached instances (for testing).
  static void disposeAll() {
    _instances.clear();
  }

  /// The environment name.
  String get env => config.env;

  /// Whether metadata is enabled.
  bool get hasMeta => config.withMeta;

  // --- Read Operations ---

  /// Gets a value by key.
  ///
  /// Emits 'read' event through hook pipeline.
  /// Returns `null` if key doesn't exist or hooks return [HiDelete].
  Future<T?> get<T>(String key) async {
    final payload = HiPayload<T?>(key: key, value: null, env: env);

    final result = await engine.emit<dynamic, dynamic>('read', payload);

    // Check for HiDelete or HiBreak
    if (result is HiDelete) {
      await _store.delete(key);
      await _store.deleteMeta(key);
      return null;
    }

    if (result is HiBreak) {
      return result.returnValue as T?;
    }

    // Perform actual read
    final value = await _store.get(key);
    return value as T?;
  }

  /// Gets a value with its metadata.
  ///
  /// Convenience method that bundles value + meta.
  Future<({T? value, Map<String, dynamic>? meta})> getWithMeta<T>(
    String key,
  ) async {
    final value = await get<T>(key);
    final meta = await _store.getMeta(key);
    return (value: value, meta: meta);
  }

  // --- Write Operations ---

  /// Stores a value by key.
  ///
  /// Emits 'write' event through hook pipeline.
  /// Optionally stores metadata alongside the value.
  Future<void> put<T>(
    String key,
    T value, {
    Map<String, dynamic>? meta,
  }) async {
    // Load existing meta if we need to merge
    Map<String, dynamic>? existingMeta;
    if (config.withMeta) {
      existingMeta = await _store.getMeta(key);
    }

    final payload = HiPayload<T>(
      key: key,
      value: value,
      env: env,
      metadata: {
        'meta': meta ?? existingMeta,
        'store': _store,
      },
    );

    final result = await engine.emit<dynamic, dynamic>('write', payload);

    // Check for HiDelete
    if (result is HiDelete) {
      await _store.delete(key);
      await _store.deleteMeta(key);
      return;
    }

    if (result is HiBreak) {
      return; // Hook handled it
    }

    // Get potentially modified value from result
    final finalValue = result is HiContinue && result.payload != null
        ? result.payload!.value
        : value;

    // Perform actual write
    await _store.put(key, finalValue);

    // Handle metadata
    if (config.withMeta) {
      // Check if meta was modified in context
      final resultMeta = result is HiContinue && result.payload?.metadata != null
          ? result.payload!.metadata!['meta'] as Map<String, dynamic>?
          : meta;

      if (resultMeta != null) {
        await _store.putMeta(key, resultMeta);
      }
    }
  }

  // --- Delete Operations ---

  /// Deletes a value by key.
  ///
  /// Emits 'delete' event through hook pipeline.
  Future<void> delete(String key) async {
    final payload = HiPayload<void>(key: key, value: null, env: env);

    final result = await engine.emit<dynamic, dynamic>('delete', payload);

    if (result is HiBreak) {
      return; // Hook handled it
    }

    await _store.delete(key);
    if (config.withMeta) {
      await _store.deleteMeta(key);
    }
  }

  /// Clears all values.
  ///
  /// Emits 'clear' event through hook pipeline.
  Future<void> clear() async {
    final payload = HiPayload<void>(key: null, value: null, env: env);

    final result = await engine.emit<dynamic, dynamic>('clear', payload);

    if (result is HiBreak) {
      return; // Hook handled it
    }

    await _store.clear();
    if (config.withMeta) {
      await _store.clearMeta();
    }
  }

  // --- Cache Utilities ---

  /// Gets cached value or computes and caches it if not found.
  ///
  /// This is a convenience method for the common cache-aside pattern:
  /// 1. Try to get existing value
  /// 2. If found, return it
  /// 3. If not found, compute new value via [computeValue]
  /// 4. Store the computed value (unless null and [cacheOnNullValues] is false)
  /// 5. Return the value
  ///
  /// ```dart
  /// final user = await hive.ifNotCached<Map>(
  ///   'user:123',
  ///   () async => await fetchUserFromApi(123),
  ///   meta: {'ttl': 3600},
  /// );
  /// ```
  ///
  /// Set [cacheOnNullValues] to `true` if you want to cache null results
  /// (useful to avoid repeated lookups for known-missing keys).
  Future<T?> ifNotCached<T>(
    String key,
    Future<T?> Function() computeValue, {
    Map<String, dynamic>? meta,
    bool cacheOnNullValues = false,
  }) async {
    // Try to get existing value
    final existing = await get<T>(key);
    if (existing != null) {
      return existing;
    }

    // Compute new value
    final newValue = await computeValue();

    // Don't cache null unless explicitly requested
    if (newValue == null && !cacheOnNullValues) {
      return null;
    }

    // Store and return
    await put<T?>(key, newValue, meta: meta);
    return newValue;
  }

  // --- Iteration ---

  /// Returns a stream of all keys.
  Stream<String> keys() => _store.keys();

  /// Returns a stream of all values.
  Stream<dynamic> values() => _store.values();

  /// Returns a stream of all entries.
  Stream<MapEntry<String, dynamic>> entries() => _store.entries();

  // --- Direct Access (bypasses hooks) ---

  /// Direct access to the underlying store.
  ///
  /// Use with caution - bypasses all hooks.
  HBoxStore get store => _store;
}
