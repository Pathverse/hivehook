import 'package:hivehook/core/base.dart';
import 'package:hivehook/core/config.dart';
import 'package:hivehook/core/ctx.dart';
import 'package:hivehook/core/enums.dart';
import 'package:hivehook/core/payload.dart';

/// Main HiveHook API for interacting with the database.
/// Provides CRUD operations with hook support and metadata management.
class HHive {
  static final Map<String, HHive> _instances = {};

  // instance
  final HHImmutableConfig config;

  HHive._internal(this.config);

  /// Creates or retrieves an HHive instance for the given environment.
  /// Either [config] or [env] must be provided.
  factory HHive({HHImmutableConfig? config, String? env}) {
    if (config == null && env == null) {
      throw ArgumentError(
        'Either config or env must be provided to create HHive instance.',
      );
    }

    if (config != null && env != null) {
      if (config.env != env) {
        throw ArgumentError(
          'Provided config env (${config.env}) does not match provided env ($env).',
        );
      }
    }

    final targetEnv = config?.env ?? env!;

    // Check if HHive instance already exists for this env
    if (_instances.containsKey(targetEnv)) {
      return _instances[targetEnv]!;
    }

    // If only env is provided, get or create config
    final finalConfig = config ?? HHImmutableConfig.instances[targetEnv];

    if (finalConfig == null) {
      throw ArgumentError(
        'No config found for env "$targetEnv". Please create one first by providing a config.',
      );
    }

    // Create new HHive instance
    final instance = HHive._internal(finalConfig);
    _instances[targetEnv] = instance;
    return instance;
  }

  /// Clears all data and metadata for the given environment.
  /// Triggers onClear hooks.
  static Future<void> staticClear(HHPayloadI payload) async {
    final ctx = HHCtx(payload);
    await ctx.control.emit(
      TriggerType.onClear.name,
      action: (ctx) async {
        await ctx.access.storeClear();
        await ctx.access.metaClear();
      },
      handleCtrlException: true,
    );
  }

  /// Clears all data and metadata for this environment.
  Future<void> clear({Map<String, dynamic>? meta}) async {
    await HHive.staticClear(HHPayload(env: config.env, metadata: meta));
  }

  /// Deletes a value and its metadata by key.
  /// Triggers onDelete hooks.
  static Future<void> staticDelete(HHPayloadI payload) async {
    final ctx = HHCtx(payload);
    await ctx.control.emit(
      TriggerType.onDelete.name,
      action: (ctx) async {
        await ctx.access.storeDelete(ctx.payload.key!);
        if ((ctx as HHCtx).config.usesMeta) {
          await ctx.access.metaDelete(ctx.payload.key!);
        }
      },
      handleCtrlException: true,
    );
  }

  /// Deletes a value and its metadata by key.
  Future<void> delete(String key, {Map<String, dynamic>? meta}) async {
    await HHive.staticDelete(
      HHPayload(env: config.env, key: key, metadata: meta),
    );
  }

  /// Gets and deletes a value in one operation.
  /// Returns the value before deletion.
  static Future<dynamic> staticPop(HHPayloadI payload) async {
    final ctx = HHCtx(payload);
    return await ctx.control.emit(
      TriggerType.onDelete.name,
      action: (ctx) async {
        final value = await ctx.access.storePop(ctx.payload.key!);
        if ((ctx as HHCtx).config.usesMeta) {
          await ctx.access.metaPop(ctx.payload.key!);
        }
        return value;
      },
      handleCtrlException: true,
    );
  }

  /// Gets and deletes a value in one operation.
  Future<dynamic> pop(String key, {Map<String, dynamic>? meta}) async {
    return await HHive.staticPop(
      HHPayload(env: config.env, key: key, metadata: meta),
    );
  }

  /// Retrieves a value by key.
  /// Triggers valueRead hooks.
  static Future<dynamic> staticGet(HHPayloadI payload) async {
    final ctx = HHCtx(payload);
    return await ctx.control.emit(
      TriggerType.valueRead.name,
      action: (ctx) async {
        return await ctx.access.storeGet(ctx.payload.key!);
      },
      handleCtrlException: true,
    );
  }

  /// Retrieves a value by key.
  Future<dynamic> get(String key, {Map<String, dynamic>? meta}) async {
    return await HHive.staticGet(
      HHPayload(env: config.env, key: key, metadata: meta),
    );
  }

  /// Stores a value with optional metadata.
  /// Triggers valueWrite hooks.
  static Future<void> staticPut(HHPayloadI payload) async {
    final ctx = HHCtx(payload);
    await ctx.control.emit(
      TriggerType.valueWrite.name,
      action: (ctx) async {
        await ctx.access.storePut(ctx.payload.key!, ctx.payload.value);
        if ((ctx as HHCtx).config.usesMeta && ctx.payload.metadata != null) {
          await ctx.access.metaPut(ctx.payload.key!, ctx.payload.metadata!);
        }
      },
      handleCtrlException: true,
    );
  }

  /// Stores a value with optional metadata.
  Future<void> put(
    String key,
    dynamic value, {
    Map<String, dynamic>? meta,
  }) async {
    await HHive.staticPut(
      HHPayload(env: config.env, key: key, value: value, metadata: meta),
    );
  }

  /// Gets cached value or computes and caches it if not found.
  /// Set [cacheOnNullValues] to control whether null results are cached.
  static Future<dynamic> ifNotCachedStatic(
    HHPayloadI payload,
    Future<dynamic> Function() computeValue, {
    bool cacheOnNullValues = false,
  }) async {
    final ctx = HHCtx(payload);

    // Try to get existing value
    final existing = await ctx.control.emit(
      TriggerType.valueRead.name,
      action: (ctx) async {
        return await ctx.access.storeGet(ctx.payload.key!);
      },
      handleCtrlException: true,
    );

    if (existing != null) {
      return existing;
    }

    // Compute new value
    final newValue = await computeValue();
    if (newValue == null && !cacheOnNullValues) {
      return null;
    }
    // Store it
    await ctx.control.emit(
      TriggerType.valueWrite.name,
      action: (ctx) async {
        await ctx.access.storePut(ctx.payload.key!, newValue);
        if ((ctx as HHCtx).config.usesMeta && ctx.payload.metadata != null) {
          await ctx.access.metaPut(ctx.payload.key!, ctx.payload.metadata!);
        }
      },
      handleCtrlException: true,
    );

    return newValue;
  }

  /// Gets cached value or computes and caches it if not found.
  Future<dynamic> ifNotCached(
    String key,
    Future<dynamic> Function() computeValue, {
    Map<String, dynamic>? meta,
    bool cacheOnNullValues = false,
  }) async {
    return await HHive.ifNotCachedStatic(
      HHPayload(env: config.env, key: key, metadata: meta),
      computeValue,
      cacheOnNullValues: cacheOnNullValues,
    );
  }

  /// Retrieves metadata for a key.
  /// Triggers metadataRead hooks.
  static Future<Map<String, dynamic>?> staticGetMeta(HHPayloadI payload) async {
    final ctx = HHCtx(payload);
    return await ctx.control.emit(
      TriggerType.metadataRead.name,
      action: (ctx) async {
        return await ctx.access.metaGet(ctx.payload.key!);
      },
      handleCtrlException: true,
    );
  }

  /// Retrieves metadata for a key.
  Future<Map<String, dynamic>?> getMeta(
    String key, {
    Map<String, dynamic>? meta,
  }) async {
    return await HHive.staticGetMeta(
      HHPayload(env: config.env, key: key, metadata: meta),
    );
  }

  /// Stores metadata for a key.
  /// Triggers metadataWrite hooks.
  static Future<void> staticPutMeta(HHPayloadI payload) async {
    final ctx = HHCtx(payload);
    await ctx.control.emit(
      TriggerType.metadataWrite.name,
      action: (ctx) async {
        await ctx.access.metaPut(ctx.payload.key!, ctx.payload.metadata!);
      },
      handleCtrlException: true,
    );
  }

  /// Stores metadata for a key.
  Future<void> putMeta(
    String key,
    Map<String, dynamic> metadata, {
    Map<String, dynamic>? meta,
  }) async {
    await HHive.staticPutMeta(
      HHPayload(env: config.env, key: key, metadata: metadata),
    );
  }

  /// Disposes an environment and optionally clears its data.
  /// Set [clear] to false to keep data after disposal.
  static Future<void> dispose(HHPayloadI payload, {bool clear = true}) async {
    final immutablePayload = payload.asImmutable();
    if (clear) {
      // Clear data directly without triggering hooks during disposal
      final ctx = HHCtx(payload);
      await ctx.access.storeClear();
      if (ctx.config.usesMeta) {
        await ctx.access.metaClear();
      }
    }
    await HHiveCore.dispose(immutablePayload.env!);
    final config = HHImmutableConfig.getInstance(immutablePayload.env!);
    if (config != null) {
      dangerousRemoveConfig(config);
    }
  }

  /// Returns a stream of all keys. Bypasses hooks for performance.
  Stream<String> keys() async* {
    final ctx = HHCtx(HHPayload(env: config.env));
    await for (final key in ctx.access.storeKeys()) {
      yield key;
    }
  }

  /// Returns a stream of all keys. Bypasses hooks for performance.
  static Stream<String> staticKeys(HHPayloadI payload) async* {
    final ctx = HHCtx(payload);
    await for (final key in ctx.access.storeKeys()) {
      yield key;
    }
  }

  /// Returns a stream of all values. Bypasses hooks for performance.
  Stream<dynamic> values() async* {
    final ctx = HHCtx(HHPayload(env: config.env));
    await for (final value in ctx.access.storeValues()) {
      yield value;
    }
  }

  /// Returns a stream of all values. Bypasses hooks for performance.
  static Stream<dynamic> staticValues(HHPayloadI payload) async* {
    final ctx = HHCtx(payload);
    await for (final value in ctx.access.storeValues()) {
      yield value;
    }
  }

  /// Returns a stream of all key-value entries. Bypasses hooks for performance.
  Stream<MapEntry<String, dynamic>> entries() async* {
    final ctx = HHCtx(HHPayload(env: config.env));
    await for (final entry in ctx.access.storeEntries()) {
      yield entry;
    }
  }

  /// Returns a stream of all key-value entries. Bypasses hooks for performance.
  static Stream<MapEntry<String, dynamic>> staticEntries(
    HHPayloadI payload,
  ) async* {
    final ctx = HHCtx(payload);
    await for (final entry in ctx.access.storeEntries()) {
      yield entry;
    }
  }

  /// Clears all data across all environments.
  /// Use [exemptList] to specify regex patterns for environments to skip.
  static Future<void> staticClearAll({
    List<String> exemptList = const [],
  }) async {
    final envs = HHImmutableConfig.instances.keys;
    for (final env in envs) {
      // if regex match
      if (exemptList.any((pattern) => RegExp(pattern).hasMatch(env))) {
        continue;
      }
      final ctx = HHCtx(HHPayload(env: env));
      await ctx.access.storeClear();
      if (ctx.config.usesMeta) {
        await ctx.access.metaClear();
      }
    }
  }
}
