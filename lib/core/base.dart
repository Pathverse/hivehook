import 'package:hive_ce/hive.dart';
import 'package:hivehook/core/config.dart';
import 'package:hivehook/core/web_debug.dart' as web_debug;
import 'package:hivehook/core/web_debug.dart' as web_debug;

/// Low-level Hive wrapper for managing box collections.
/// Handles initialization and box lifecycle management.
class HHiveCore {
  /// Detect debug mode using assertions (only run in debug mode).
  /// This mirrors Flutter's kDebugMode but works in pure Dart.
  static final bool kDebugMode = () {
    bool isDebug = false;
    assert(() {
      isDebug = true;
      return true;
    }());
    return isDebug;
  }();

  /// Whether debug object storage is available.
  /// Only works on web platform where objects are stored in `window.hiveDebug`.
  static bool get isDebugAvailable => web_debug.isWebDebugAvailable;

  /// Override for debug object storage. When null, uses [kDebugMode] && [isDebugAvailable].
  /// Set to `false` to disable debug storage.
  /// Set to `true` to force debug storage (only works on web).
  static bool? _debugObjOverride;
  static bool get DEBUG_OBJ =>
      (_debugObjOverride ?? kDebugMode) && isDebugAvailable;
  static set DEBUG_OBJ(bool? value) => _debugObjOverride = value;

  static String? HIVE_INIT_PATH = null;
  static HiveStorageBackendPreference HIVE_STORAGE_BACKEND_PREFERENCE =
      HiveStorageBackendPreference.native;

  static HiveCipher? HIVE_CIPHER = null;

  static String _hiveBoxCollectionName = 'hivehooks';
  static String get HIVE_BOX_COLLECTION_NAME => _hiveBoxCollectionName;
  static set HIVE_BOX_COLLECTION_NAME(String value) {
    if (_hiveBoxCollectionName != value) {
      _hiveBoxCollectionName = value;
      // Reset hive state when collection name changes
      _openedBoxes.clear();
      _hiveBoxCollection = null;
      _alreadyInitialized = false;
      // Note: We do NOT clear configs - they are still valid,
      // just need to be re-registered with new collection
    }
  }

  static BoxCollection? _hiveBoxCollection;

  static bool _alreadyInitialized = false;

  static final Map<String, CollectionBox<String>> _openedBoxes = {};

  /// Retrieves or opens a box for the given environment.
  static Future<CollectionBox<String>> getBox(String env) async {
    if (_hiveBoxCollection == null) {
      throw StateError(
        'HHiveCore is not initialized. Please call HHiveCore.initialize() first.',
      );
    }
    if (_openedBoxes.containsKey(env)) {
      return _openedBoxes[env]!;
    }
    final box = await _hiveBoxCollection!.openBox<String>(env);
    _openedBoxes[env] = box;
    return box;
  }

  /// Retrieves the shared metadata box if metadata is enabled for the environment.
  /// All environments share a single `_meta` box with namespaced keys `{env}::{key}`.
  static Future<CollectionBox<String>?> getMetaBox(String env) async {
    final config = HHImmutableConfig.instances[env];
    if (config == null || !config.usesMeta) {
      return null;
    }
    return getBox('_meta');
  }

  /// Initializes Hive and opens all registered box collections.
  /// Must be called before using any HHive instances.
  static Future<void> initialize() async {
    if (_alreadyInitialized) {
      return;
    }
    _alreadyInitialized = true;

    Hive.init(
      HIVE_INIT_PATH,
      backendPreference: HIVE_STORAGE_BACKEND_PREFERENCE,
    );

    // open box collections
    final List<String> boxes = [];
    bool anyUsesMeta = false;
    for (final config in HHImmutableConfig.instances.values) {
      boxes.add(config.env);
      if (config.usesMeta) {
        anyUsesMeta = true;
      }
    }
    // Single shared meta box for all environments
    if (anyUsesMeta) {
      boxes.add('_meta');
    }

    _hiveBoxCollection = await BoxCollection.open(
      _hiveBoxCollectionName,
      boxes.toSet(),
      path: HIVE_INIT_PATH,
      key: HIVE_CIPHER,
    );

    // Initialize web debug storage if available and enabled
    if (DEBUG_OBJ) {
      web_debug.initWebDebug();
    }
  }

  /// Flushes and closes boxes for the given environment.
  static Future<void> dispose(String env) async {
    if (_hiveBoxCollection == null) {
      return;
    }
    final store = await getBox(env);
    await store.flush();
    if (_openedBoxes.containsKey(env)) {
      _openedBoxes.remove(env);
    }

    // Note: The shared _meta box is not disposed per-environment.
    // It will be closed when all environments are disposed or the collection closes.
  }
}
