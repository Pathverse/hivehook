import 'package:hive_ce/hive.dart';
import 'package:hihook/src/hook/hook.dart';

/// Custom JSON encoder function.
/// Called for objects that are not directly JSON-encodable.
typedef HiveJsonEncoder = Object? Function(dynamic object);

/// Custom JSON decoder/reviver function.
/// Called for each key-value pair during decoding.
typedef HiveJsonDecoder = Object? Function(Object? key, Object? value);

/// Storage mode for values.
enum HiveStorageMode {
  /// JSON encode/decode all values.
  /// Works with any JSON-serializable data (Map, List, String, num, bool, null).
  /// Default and recommended for most use cases.
  json,

  /// Native Hive storage using type adapters.
  /// Requires registering TypeAdapters for non-primitive types.
  /// Use when you need DateTime, custom classes, etc.
  native,
}

/// Hive box type for storage configuration.
enum HiveBoxType {
  /// Use BoxCollection (all boxes opened at once).
  /// Recommended for multiple environments.
  boxCollection,

  /// Use individual Box (lazy opening).
  /// Recommended for single environment or dynamic box creation.
  box,
}

/// Configuration for a Hive-backed storage environment.
///
/// Example:
/// ```dart
/// final config = HiveConfig(
///   env: 'users',
///   hooks: [ttlPlugin.hooks, lruPlugin.hooks].expand((h) => h).toList(),
///   metaHooks: [encryptionPlugin.metaHooks].expand((h) => h).toList(),
///   withMeta: true,
/// );
/// ```
class HiveConfig {
  /// Environment name (unique identifier for this config).
  /// 
  /// Each env can only be registered once. Keys are prefixed with
  /// `{env}::` to prevent cross-contamination between environments.
  final String env;

  /// Box name for storage (defaults to [env]).
  /// 
  /// Multiple envs can share the same boxName (keys are prefixed
  /// with `{env}::` for isolation). Use this to group related
  /// environments into a single physical box.
  final String boxName;

  /// Hooks to apply to value operations in this environment.
  /// 
  /// These hooks handle events: 'read', 'write', 'delete', 'clear'.
  /// For metadata operations, use [metaHooks] instead.
  final List<HiHook> hooks;

  /// Hooks to apply to metadata operations in this environment.
  /// 
  /// These hooks handle events: 'readMeta', 'writeMeta', 'deleteMeta', 'clearMeta'.
  /// Metadata hooks run on a separate engine from value hooks.
  /// 
  /// This separation allows plugins to:
  /// - Encrypt values and metadata independently
  /// - Check TTL/invalidation before reading values (meta-first pattern)
  /// - Transform metadata without affecting value processing
  final List<HiHook> metaHooks;

  /// Box type: boxCollection (batch open) or box (individual open).
  final HiveBoxType type;

  /// Whether to enable metadata storage.
  final bool withMeta;

  /// BoxCollection name (only for [HiveBoxType.boxCollection]).
  /// Default: 'hivehooks'
  final String boxCollectionName;

  /// Metadata box name (only for [HiveBoxType.box]).
  /// Default: '_{env}Meta'
  final String? boxMetaName;

  /// Whether to open boxes lazily.
  final bool lazy;

  /// Storage mode: json (default) or native (uses type adapters).
  final HiveStorageMode storageMode;

  /// Type adapters to register for this environment.
  ///
  /// These are registered during [HHiveCore.initialize()].
  /// Example:
  /// ```dart
  /// HiveConfig(
  ///   env: 'users',
  ///   storageMode: HiveStorageMode.native,
  ///   typeAdapters: [UserAdapter(), DateTimeAdapter()],
  /// )
  /// ```
  final List<TypeAdapter<dynamic>> typeAdapters;

  /// Custom JSON encoder for non-JSON-serializable types.
  ///
  /// Only used when [storageMode] is [HiveStorageMode.json].
  /// Example:
  /// ```dart
  /// HiveConfig(
  ///   env: 'users',
  ///   jsonEncoder: (obj) {
  ///     if (obj is DateTime) return {'__type': 'DateTime', 'value': obj.toIso8601String()};
  ///     if (obj is User) return {'__type': 'User', ...obj.toJson()};
  ///     return obj;
  ///   },
  /// )
  /// ```
  final HiveJsonEncoder? jsonEncoder;

  /// Custom JSON decoder/reviver for non-JSON-serializable types.
  ///
  /// Only used when [storageMode] is [HiveStorageMode.json].
  /// Example:
  /// ```dart
  /// HiveConfig(
  ///   env: 'users',
  ///   jsonDecoder: (key, value) {
  ///     if (value is Map && value['__type'] == 'DateTime') {
  ///       return DateTime.parse(value['value']);
  ///     }
  ///     if (value is Map && value['__type'] == 'User') {
  ///       return User.fromJson(value);
  ///     }
  ///     return value;
  ///   },
  /// )
  /// ```
  final HiveJsonDecoder? jsonDecoder;

  const HiveConfig({
    required this.env,
    String? boxName,
    this.hooks = const [],
    this.metaHooks = const [],
    this.type = HiveBoxType.boxCollection,
    this.withMeta = true,
    this.boxCollectionName = 'hivehooks',
    this.boxMetaName,
    this.lazy = false,
    this.storageMode = HiveStorageMode.json,
    this.typeAdapters = const [],
    this.jsonEncoder,
    this.jsonDecoder,
  }) : boxName = boxName ?? env;

  /// Computed meta box name for box type.
  String get resolvedMetaBoxName => boxMetaName ?? '_${env}Meta';

  /// Validates the configuration.
  void validate() {
    if (env.isEmpty) {
      throw ArgumentError('env cannot be empty');
    }
    if (env.startsWith('_')) {
      throw ArgumentError('env cannot start with underscore (reserved)');
    }
  }

  @override
  String toString() => 'HiveConfig(env: $env, type: $type, withMeta: $withMeta)';
}
