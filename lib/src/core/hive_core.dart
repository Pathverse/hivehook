import 'package:hive_ce/hive.dart';
import 'package:hihook/src/hook/hook.dart';

import 'hive_config.dart';
import '../store/hbox_store.dart';

/// Centralized initialization and lifecycle management for Hive storage.
///
/// Handles:
/// - BoxCollection initialization (all boxes registered before open)
/// - Individual Box initialization (lazy per-box)
/// - Store instance management
/// - Web debug initialization
///
/// Usage:
/// ```dart
/// // 1. Register configs before initialization
/// HHiveCore.register(HiveConfig(env: 'users', withMeta: true));
/// HHiveCore.register(HiveConfig(env: 'settings', withMeta: false));
///
/// // 2. Initialize (opens all BoxCollections)
/// await HHiveCore.initialize();
///
/// // 3. Get store instances
/// final store = await HHiveCore.getStore('users');
/// ```
class HHiveCore {
  // --- Static Configuration ---

  /// Detect debug mode using assertions (only run in debug mode).
  static final bool kDebugMode = () {
    bool isDebug = false;
    assert(() {
      isDebug = true;
      return true;
    }());
    return isDebug;
  }();

  /// Whether debug object storage is available (web only).
  /// TODO: Add web_debug implementation for browser dev tools integration
  static bool get isDebugAvailable => false;

  /// Override for debug object storage.
  static bool? _debugObjOverride;
  static bool get DEBUG_OBJ =>
      (_debugObjOverride ?? kDebugMode) && isDebugAvailable;
  static set DEBUG_OBJ(bool? value) => _debugObjOverride = value;

  /// Hive initialization path.
  static String? HIVE_INIT_PATH;

  /// Hive storage backend preference.
  static HiveStorageBackendPreference HIVE_STORAGE_BACKEND_PREFERENCE =
      HiveStorageBackendPreference.native;

  /// Hive cipher for encryption.
  static HiveCipher? HIVE_CIPHER;

  // --- Global Defaults ---

  /// Global type adapters registered for all environments.
  ///
  /// These are merged with per-config adapters during initialization.
  /// ```dart
  /// HHiveCore.globalTypeAdapters.addAll([DateTimeAdapter(), UriAdapter()]);
  /// ```
  static final List<TypeAdapter<dynamic>> globalTypeAdapters = [];

  /// Global JSON encoder for all environments using JSON storage mode.
  ///
  /// Per-config encoder takes precedence if set.
  /// ```dart
  /// HHiveCore.globalJsonEncoder = (obj) {
  ///   if (obj is DateTime) return {'__t': 'DateTime', 'v': obj.toIso8601String()};
  ///   throw JsonUnsupportedObjectError(obj);
  /// };
  /// ```
  static JsonEncoder? globalJsonEncoder;

  /// Global JSON decoder for all environments using JSON storage mode.
  ///
  /// Per-config decoder takes precedence if set.
  /// ```dart
  /// HHiveCore.globalJsonDecoder = (key, value) {
  ///   if (value is Map && value['__t'] == 'DateTime') {
  ///     return DateTime.parse(value['v']);
  ///   }
  ///   return value;
  /// };
  /// ```
  static JsonDecoder? globalJsonDecoder;

  /// Global hooks applied to all environments.
  ///
  /// These are prepended to per-config hooks (global runs first).
  /// ```dart
  /// HHiveCore.globalHooks.addAll([loggingHook, metricsHook]);
  /// ```
  static final List<HiHook> globalHooks = [];

  // --- State ---

  static final Map<String, HiveConfig> _configs = {};
  static final Map<String, HBoxStore> _stores = {};
  static final Map<String, BoxCollection> _collections = {};
  static final Map<String, CollectionBox<dynamic>> _openedBoxes = {};
  static final Set<int> _registeredAdapterTypeIds = {};
  static bool _initialized = false;

  /// Registered configurations.
  static Map<String, HiveConfig> get configs => Map.unmodifiable(_configs);

  /// Whether [initialize] has been called.
  static bool get isInitialized => _initialized;

  /// Register a configuration.
  ///
  /// Must be called before [initialize] for BoxCollection types.
  static void register(HiveConfig config) {
    config.validate();
    if (_initialized && config.type == HiveBoxType.boxCollection) {
      throw StateError(
        'Cannot register BoxCollection config after initialization. '
        'Register all BoxCollection configs before calling initialize().',
      );
    }
    _configs[config.env] = config;
  }

  /// Initialize Hive and open all registered BoxCollections.
  ///
  /// For [HiveBoxType.boxCollection], all boxes are opened at once.
  /// For [HiveBoxType.box], boxes are opened lazily on first access.
  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    // Initialize Hive
    Hive.init(
      HIVE_INIT_PATH,
      backendPreference: HIVE_STORAGE_BACKEND_PREFERENCE,
    );

    // Register all type adapters (global + per-config)
    for (final adapter in globalTypeAdapters) {
      if (!_registeredAdapterTypeIds.contains(adapter.typeId)) {
        Hive.registerAdapter(adapter);
        _registeredAdapterTypeIds.add(adapter.typeId);
      }
    }
    for (final config in _configs.values) {
      for (final adapter in config.typeAdapters) {
        if (!_registeredAdapterTypeIds.contains(adapter.typeId)) {
          Hive.registerAdapter(adapter);
          _registeredAdapterTypeIds.add(adapter.typeId);
        }
      }
    }

    // Group BoxCollection configs by collection name
    final byCollection = <String, List<HiveConfig>>{};
    for (final config in _configs.values) {
      if (config.type == HiveBoxType.boxCollection) {
        byCollection
            .putIfAbsent(config.boxCollectionName, () => [])
            .add(config);
      }
    }

    // Open each BoxCollection with all its boxes
    for (final entry in byCollection.entries) {
      final collectionName = entry.key;
      final configs = entry.value;

      // Collect box names
      final boxNames = <String>{};
      bool anyMeta = false;
      for (final config in configs) {
        boxNames.add(config.env);
        if (config.withMeta) anyMeta = true;
      }
      if (anyMeta) boxNames.add('_meta');

      // Open collection
      final collection = await BoxCollection.open(
        collectionName,
        boxNames,
        path: HIVE_INIT_PATH,
        key: HIVE_CIPHER,
      );
      _collections[collectionName] = collection;

      // Create HBoxStore for each config
      CollectionBox<String>? metaBox;
      if (anyMeta) {
        metaBox = await collection.openBox<String>('_meta');
        _openedBoxes['$collectionName::_meta'] = metaBox;
      }

      for (final config in configs) {
        // Use dynamic for native mode, String for json mode
        final CollectionBox<dynamic> box;
        if (config.storageMode == HiveStorageMode.native) {
          box = await collection.openBox<dynamic>(config.env);
        } else {
          box = await collection.openBox<String>(config.env);
        }
        _openedBoxes['$collectionName::${config.env}'] = box;
        _stores[config.env] = HBoxStore(
          box: box,
          metaBox: config.withMeta ? metaBox : null,
          env: config.env,
          storageMode: config.storageMode,
          jsonEncoder: config.jsonEncoder ?? globalJsonEncoder,
          jsonDecoder: config.jsonDecoder ?? globalJsonDecoder,
        );
      }
    }

    // Initialize web debug if enabled
    if (DEBUG_OBJ) {
      // TODO: Add web_debug.initWebDebug() when web debug support is added
    }
  }

  /// Get the store for an environment.
  ///
  /// For [HiveBoxType.boxCollection], returns the pre-created store.
  /// For [HiveBoxType.box], creates the store lazily if not exists.
  static Future<HBoxStore> getStore(String env) async {
    // Return existing store
    if (_stores.containsKey(env)) {
      return _stores[env]!;
    }

    // Check if config exists
    final config = _configs[env];
    if (config == null) {
      throw StateError(
        'No config registered for env "$env". '
        'Call HHiveCore.register() first.',
      );
    }

    // For box type, create lazily
    if (config.type == HiveBoxType.box) {
      return _createBoxStore(config);
    }

    // For boxCollection type, should have been created during initialize
    throw StateError(
      'Store for env "$env" not found. '
      'Ensure HHiveCore.initialize() was called after registering the config.',
    );
  }

  /// Creates an HBoxStore for a Box type config (lazy initialization).
  static Future<HBoxStore> _createBoxStore(HiveConfig config) async {
    // For individual Box type, we need to use regular Hive boxes
    // wrapped in a CollectionBox-compatible interface
    // TODO: Implement Box type support
    throw UnimplementedError(
      'Individual Box support not yet implemented. '
      'Use HiveBoxType.boxCollection for now.',
    );
  }

  /// Disposes resources for an environment.
  static Future<void> dispose(String env) async {
    if (_stores.containsKey(env)) {
      _stores.remove(env);
    }
    // Note: Actual box disposal is handled by BoxCollection
  }

  /// Resets all state (for testing).
  static Future<void> reset() async {
    _configs.clear();
    _stores.clear();
    _collections.clear();
    _openedBoxes.clear();
    _registeredAdapterTypeIds.clear();
    _initialized = false;
    // Note: Does not clear global defaults (globalTypeAdapters, globalHooks, etc.)
  }

  /// Resets all state including global defaults (for testing).
  static Future<void> resetAll() async {
    await reset();
    globalTypeAdapters.clear();
    globalHooks.clear();
    globalJsonEncoder = null;
    globalJsonDecoder = null;
  }

  /// Gets merged hooks for an environment (global + config).
  ///
  /// Global hooks run first, then per-config hooks.
  static List<HiHook> getHooksFor(String env) {
    final config = _configs[env];
    if (config == null) return List.unmodifiable(globalHooks);
    return [...globalHooks, ...config.hooks];
  }

  /// Manually register a type adapter.
  ///
  /// Use this for adapters that aren't tied to a specific environment.
  /// Must be called before [initialize].
  static void registerAdapter<T>(TypeAdapter<T> adapter) {
    if (_initialized) {
      throw StateError(
        'Cannot register adapters after initialization. '
        'Call registerAdapter() before initialize().',
      );
    }
    if (!_registeredAdapterTypeIds.contains(adapter.typeId)) {
      Hive.registerAdapter(adapter);
      _registeredAdapterTypeIds.add(adapter.typeId);
    }
  }
}
