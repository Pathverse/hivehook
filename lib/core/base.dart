import 'package:hive_ce/hive.dart';
import 'package:hivehook/core/config.dart';

class HiveBase {
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

  static Future<CollectionBox<String>> getBox(String env) async {
    if (_hiveBoxCollection == null) {
      throw StateError(
        'HiveBase is not initialized. Please call HiveBase.initialize() first.',
      );
    }
    if (_openedBoxes.containsKey(env)) {
      return _openedBoxes[env]!;
    }
    final box = await _hiveBoxCollection!.openBox<String>(env);
    _openedBoxes[env] = box;
    return box;
  }

  static Future<CollectionBox<String>?> getMetaBox(String env) async {
    final config = HHImmutableConfig.instances[env];
    if (config == null || !config.usesMeta) {
      return null;
    }
    final boxName = '_meta_$env';
    return getBox(boxName);
  }

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
    for (final config in HHImmutableConfig.instances.values) {
      boxes.add(config.env);
      if (config.usesMeta) {
        boxes.add('_meta_${config.env}');
      }
    }

    _hiveBoxCollection = await BoxCollection.open(
      _hiveBoxCollectionName,
      boxes.toSet(),
      path: HIVE_INIT_PATH,
      key: HIVE_CIPHER,
    );
  }

  static Future<void> dispose(String env) async {
    if (_hiveBoxCollection == null) {
      return;
    }
    final store = await getBox(env);
    await store.flush();
    if (_openedBoxes.containsKey(env)) {
      _openedBoxes.remove(env);
    }

    final metaStore = await getMetaBox(env);
    if (metaStore != null) {
      await metaStore.flush();
      final metaBoxName = '_meta_$env';
      if (_openedBoxes.containsKey(metaBoxName)) {
        _openedBoxes.remove(metaBoxName);
      }
    }
  }
}
