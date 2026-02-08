import 'package:hive_ce/hive.dart';
import 'package:hihook/src/hook/hook.dart';

import 'box_collection_config.dart';
import 'hive_config.dart';
import '../store/hbox_store.dart';
import '../store/hive_box_adapter.dart';

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

  /// Hive initialization path.
  static String? storagePath;

  /// Hive storage backend preference.
  static HiveStorageBackendPreference HIVE_STORAGE_BACKEND_PREFERENCE =
      HiveStorageBackendPreference.native;

  /// Hive cipher for encryption.
  static HiveCipher? encryptionCipher;

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
  static HiveJsonEncoder? globalJsonEncoder;

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
  static HiveJsonDecoder? globalJsonDecoder;

  /// Global hooks applied to all environments for value operations.
  ///
  /// These are prepended to per-config hooks (global runs first).
  /// Handles events: 'read', 'write', 'delete', 'clear'.
  /// ```dart
  /// HHiveCore.globalHooks.addAll([loggingHook, metricsHook]);
  /// ```
  static final List<HiHook> globalHooks = [];

  /// Global hooks applied to all environments for metadata operations.
  ///
  /// These are prepended to per-config metaHooks (global runs first).
  /// Handles events: 'readMeta', 'writeMeta', 'deleteMeta', 'clearMeta'.
  /// ```dart
  /// HHiveCore.globalMetaHooks.addAll([encryptionHook]);
  /// ```
  static final List<HiHook> globalMetaHooks = [];

  // --- State ---

  static final Map<String, HiveConfig> _configs = {};
  static final Map<String, BoxCollectionConfig> _collectionConfigs = {};
  static final Map<String, HBoxStore> _stores = {};
  static final Map<String, BoxCollection> _collections = {};
  static final Map<String, CollectionBox<dynamic>> _openedBoxes = {};
  static final Set<int> _registeredAdapterTypeIds = {};
  static final Set<String> _openedCollectionNames = {};
  static final Map<String, bool> _collectionMetaRequired = {};
  static bool _initialized = false;
  static String? _effectiveInitPath;

  /// Registered configurations.
  static Map<String, HiveConfig> get configs => Map.unmodifiable(_configs);

  /// Whether [initialize] has been called.
  static bool get isInitialized => _initialized;

  /// Whether a specific BoxCollection has been opened.
  static bool isCollectionOpened(String collectionName) =>
      _openedCollectionNames.contains(collectionName);

  /// Registered collection configurations.
  static Map<String, BoxCollectionConfig> get collectionConfigs =>
      Map.unmodifiable(_collectionConfigs);

  /// Register a BoxCollection configuration.
  ///
  /// Pre-configures path, cipher, and box names for a collection.
  /// If not called, collections auto-create with defaults when referenced.
  ///
  /// Must be called before [initialize] or before any [register] that
  /// references this collection.
  ///
  /// ```dart
  /// HHiveCore.registerCollection(BoxCollectionConfig(
  ///   name: 'myapp',
  ///   path: '/custom/path',
  ///   cipher: myCipher,
  ///   includeMeta: true,
  /// ));
  /// ```
  static void registerCollection(BoxCollectionConfig config) {
    config.validate();

    if (_openedCollectionNames.contains(config.name)) {
      throw StateError(
        'BoxCollection "${config.name}" is already opened. '
        'Cannot register collection config after opening.',
      );
    }

    if (_collectionConfigs.containsKey(config.name)) {
      throw StateError(
        'Collection "${config.name}" is already registered. '
        'Each collection can only be registered once.',
      );
    }

    _collectionConfigs[config.name] = config;
  }

  /// Register a configuration.
  ///
  /// Rules:
  /// - Each env can only be registered once
  /// - BoxCollection: cannot add to already-opened collection
  /// - Box: can register anytime (lazy opening)
  static void register(HiveConfig config) {
    config.validate();

    // Enforce unique env
    if (_configs.containsKey(config.env)) {
      throw StateError(
        'Env "${config.env}" is already registered. '
        'Each env can only be registered once.',
      );
    }

    // For BoxCollection: update collection config
    if (config.type == HiveBoxType.boxCollection) {
      final collectionName = config.boxCollectionName;
      
      // Only block if collection is opened AND this is a NEW box name
      if (_openedCollectionNames.contains(collectionName)) {
        final existingConfig = _collectionConfigs[collectionName];
        final isExistingBox = existingConfig?.boxNames.contains(config.boxName) ?? false;
        if (!isExistingBox) {
          throw StateError(
            'BoxCollection "$collectionName" is already opened. '
            'Cannot add new box "${config.boxName}" to an opened collection.',
          );
        }
        // Box already exists - allow this env to reuse it
        _configs[config.env] = config;
        return;
      }

      // Get or create BoxCollectionConfig
      var collectionConfig = _collectionConfigs[collectionName];
      if (collectionConfig == null) {
        // Auto-create with defaults
        collectionConfig = BoxCollectionConfig.defaults(collectionName);
        _collectionConfigs[collectionName] = collectionConfig;
      }

      // Update box names
      final updatedBoxNames = {...collectionConfig.boxNames, config.boxName};
      _collectionConfigs[collectionName] = collectionConfig.copyWith(
        boxNames: updatedBoxNames,
      );

      // Track meta requirement
      if (config.withMeta) {
        _collectionMetaRequired[collectionName] = true;
        // Validate meta requirement against collection config
        collectionConfig.validateMetaRequirement(true);
      }
    }

    _configs[config.env] = config;
  }

  /// Initialize Hive and open all registered BoxCollections.
  ///
  /// [path] - Optional path for Hive storage (non-web platforms).
  ///          If not provided, uses [storagePath] static field.
  ///
  /// For [HiveBoxType.boxCollection], all boxes are opened at once.
  /// For [HiveBoxType.box], boxes are opened lazily on first access.
  static Future<void> initialize({String? path}) async {
    if (_initialized) return;
    _initialized = true;

    // Use provided path or fall back to static field
    final initPath = path ?? storagePath;
    _effectiveInitPath = initPath;

    // Initialize Hive
    Hive.init(
      initPath,
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

      await _openBoxCollection(collectionName, configs);
    }
  }

  /// Opens a BoxCollection and creates stores for all its configs.
  ///
  /// This is called during [initialize] for pre-registered collections,
  /// or lazily when first accessing a store from an unopened collection.
  static Future<void> _openBoxCollection(
    String collectionName,
    List<HiveConfig> configs,
  ) async {
    // Already opened?
    if (_openedCollectionNames.contains(collectionName)) return;

    // Get collection config (should exist from register() calls)
    final collectionConfig = _collectionConfigs[collectionName] ??
        BoxCollectionConfig.defaults(collectionName);

    // Determine whether meta is needed
    final metaRequired = _collectionMetaRequired[collectionName] ?? false;
    final includeMeta = collectionConfig.shouldIncludeMeta(metaRequired);

    // Collect box names from collection config + any from HiveConfigs
    final boxNames = <String>{...collectionConfig.boxNames};
    for (final config in configs) {
      boxNames.add(config.boxName);
    }
    if (includeMeta) boxNames.add('_meta');

    // Resolve path and cipher (collection config > global defaults)
    final effectivePath = collectionConfig.storagePath ?? _effectiveInitPath;
    final effectiveCipher = collectionConfig.encryptionCipher ?? encryptionCipher;

    // Open collection
    final collection = await BoxCollection.open(
      collectionName,
      boxNames,
      path: effectivePath,
      key: effectiveCipher,
    );
    _collections[collectionName] = collection;

    // Mark as opened (locks further registration)
    _openedCollectionNames.add(collectionName);

    // Create HBoxStore for each config
    // Track opened boxes by boxName to share between envs
    final openedDataBoxes = <String, CollectionBox<dynamic>>{};
    CollectionBox<String>? metaBox;
    HiveBoxAdapter<String>? metaBoxAdapter;
    if (includeMeta) {
      metaBox = await collection.openBox<String>('_meta');
      metaBoxAdapter = CollectionBoxAdapter<String>(metaBox);
      _openedBoxes['$collectionName::_meta'] = metaBox;
    }

    for (final config in configs) {
      // Open or reuse box by boxName
      CollectionBox<dynamic> box;
      final boxKey = '$collectionName::${config.boxName}';

      if (openedDataBoxes.containsKey(config.boxName)) {
        box = openedDataBoxes[config.boxName]!;
      } else {
        // Use dynamic for native mode, String for json mode
        if (config.storageMode == HiveStorageMode.native) {
          box = await collection.openBox<dynamic>(config.boxName);
        } else {
          box = await collection.openBox<String>(config.boxName);
        }
        openedDataBoxes[config.boxName] = box;
        _openedBoxes[boxKey] = box;
      }

      _stores[config.env] = HBoxStore(
        box: CollectionBoxAdapter<dynamic>(box),
        metaBox: config.withMeta ? metaBoxAdapter : null,
        env: config.env,
        storageMode: config.storageMode,
        jsonEncoder: config.jsonEncoder ?? globalJsonEncoder,
        jsonDecoder: config.jsonDecoder ?? globalJsonDecoder,
      );
    }
  }

  /// Get the store for an environment.
  ///
  /// For [HiveBoxType.boxCollection]:
  /// - If collection is opened, returns the store
  /// - If collection is not opened, opens it first (locks further registration)
  ///
  /// For [HiveBoxType.box], creates the store lazily.
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

    // For boxCollection type, check if collection needs to be opened
    final collectionName = config.boxCollectionName;
    if (!_openedCollectionNames.contains(collectionName)) {
      // Collect all configs for this collection
      final collectionConfigs = _configs.values
          .where((c) =>
              c.type == HiveBoxType.boxCollection &&
              c.boxCollectionName == collectionName)
          .toList();

      // Open the collection (this locks further registration)
      await _openBoxCollection(collectionName, collectionConfigs);
    }

    // Now the store should exist
    if (_stores.containsKey(env)) {
      return _stores[env]!;
    }

    // Handle late-registered env that reuses an existing box in opened collection
    if (_openedCollectionNames.contains(collectionName)) {
      final boxKey = '$collectionName::${config.boxName}';
      final openedBox = _openedBoxes[boxKey];
      if (openedBox != null) {
        // Get meta box if needed
        HiveBoxAdapter<String>? metaBoxAdapter;
        if (config.withMeta) {
          final metaBox = _openedBoxes['$collectionName::_meta'];
          if (metaBox != null) {
            metaBoxAdapter = CollectionBoxAdapter<String>(metaBox as CollectionBox<String>);
          }
        }

        final store = HBoxStore(
          box: CollectionBoxAdapter<dynamic>(openedBox as CollectionBox<dynamic>),
          metaBox: metaBoxAdapter,
          env: config.env,
          storageMode: config.storageMode,
          jsonEncoder: config.jsonEncoder ?? globalJsonEncoder,
          jsonDecoder: config.jsonDecoder ?? globalJsonDecoder,
        );
        _stores[env] = store;
        return store;
      }
    }

    // Should not happen, but defensive
    throw StateError(
      'Store for env "$env" not found after opening collection.',
    );
  }

  /// Creates an HBoxStore for a Box type config (lazy initialization).
  ///
  /// Opens individual boxes using Hive.openBox() instead of BoxCollection.
  /// - Regular Box creates files: {path}/{boxName}.hive
  /// - Meta box (if enabled): {path}/{boxName}_meta.hive
  static Future<HBoxStore> _createBoxStore(HiveConfig config) async {
    // Open the data box
    Box<dynamic> dataBox;
    if (config.storageMode == HiveStorageMode.native) {
      dataBox = await Hive.openBox<dynamic>(
        config.boxName,
        encryptionCipher: encryptionCipher,
      );
    } else {
      dataBox = await Hive.openBox<String>(
        config.boxName,
        encryptionCipher: encryptionCipher,
      );
    }

    // Open meta box if needed
    HiveBoxAdapter<String>? metaBoxAdapter;
    if (config.withMeta) {
      final metaBoxName = '${config.boxName}_meta';
      final metaBox = await Hive.openBox<String>(
        metaBoxName,
        encryptionCipher: encryptionCipher,
      );
      metaBoxAdapter = RegularBoxAdapter<String>(metaBox);
    }

    final store = HBoxStore(
      box: RegularBoxAdapter<dynamic>(dataBox),
      metaBox: metaBoxAdapter,
      env: config.env,
      storageMode: config.storageMode,
      jsonEncoder: config.jsonEncoder ?? globalJsonEncoder,
      jsonDecoder: config.jsonDecoder ?? globalJsonDecoder,
    );

    _stores[config.env] = store;
    return store;
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
    _collectionConfigs.clear();
    _collectionMetaRequired.clear();
    _stores.clear();
    _collections.clear();
    _openedBoxes.clear();
    _openedCollectionNames.clear();
    _registeredAdapterTypeIds.clear();
    _initialized = false;
    _effectiveInitPath = null;
    // Note: Does not clear global defaults (globalTypeAdapters, globalHooks, etc.)
  }

  /// Resets all state including global defaults (for testing).
  static Future<void> resetAll() async {
    await reset();
    globalTypeAdapters.clear();
    globalHooks.clear();
    globalMetaHooks.clear();
    globalJsonEncoder = null;
    globalJsonDecoder = null;
  }

  /// Gets merged hooks for an environment (global + config).
  ///
  /// Global hooks run first, then per-config hooks.
  /// These handle value events: 'read', 'write', 'delete', 'clear'.
  static List<HiHook> getHooksFor(String env) {
    final config = _configs[env];
    if (config == null) return List.unmodifiable(globalHooks);
    return [...globalHooks, ...config.hooks];
  }

  /// Gets merged meta hooks for an environment (global + config).
  ///
  /// Global meta hooks run first, then per-config meta hooks.
  /// These handle meta events: 'readMeta', 'writeMeta', 'deleteMeta', 'clearMeta'.
  static List<HiHook> getMetaHooksFor(String env) {
    final config = _configs[env];
    if (config == null) return List.unmodifiable(globalMetaHooks);
    return [...globalMetaHooks, ...config.metaHooks];
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
