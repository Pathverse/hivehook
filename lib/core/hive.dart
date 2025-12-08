import 'package:hivehook/core/base.dart';
import 'package:hivehook/core/config.dart';
import 'package:hivehook/core/ctx.dart';
import 'package:hivehook/core/enums.dart';
import 'package:hivehook/core/payload.dart';

class HHive {
  static final Map<String, HHive> _instances = {};

  // instance
  final HHImmutableConfig config;

  HHive._internal(this.config);

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

  Future<void> clear({Map<String, dynamic>? meta}) async {
    await HHive.staticClear(HHPayload(env: config.env, metadata: meta));
  }

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

  Future<void> delete(String key, {Map<String, dynamic>? meta}) async {
    await HHive.staticDelete(
      HHPayload(env: config.env, key: key, metadata: meta),
    );
  }

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

  Future<dynamic> pop(String key, {Map<String, dynamic>? meta}) async {
    return await HHive.staticPop(
      HHPayload(env: config.env, key: key, metadata: meta),
    );
  }

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

  Future<dynamic> get(String key, {Map<String, dynamic>? meta}) async {
    return await HHive.staticGet(
      HHPayload(env: config.env, key: key, metadata: meta),
    );
  }

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

  Future<void> put(
    String key,
    dynamic value, {
    Map<String, dynamic>? meta,
  }) async {
    await HHive.staticPut(
      HHPayload(env: config.env, key: key, value: value, metadata: meta),
    );
  }

  static Future<dynamic> ifNotCachedStatic(
    HHPayloadI payload,
    Future<dynamic> Function() computeValue,
  ) async {
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

  Future<dynamic> ifNotCached(
    String key,
    Future<dynamic> Function() computeValue, {
    Map<String, dynamic>? meta,
  }) async {
    return await HHive.ifNotCachedStatic(
      HHPayload(env: config.env, key: key, metadata: meta),
      computeValue,
    );
  }

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

  Future<Map<String, dynamic>?> getMeta(
    String key, {
    Map<String, dynamic>? meta,
  }) async {
    return await HHive.staticGetMeta(
      HHPayload(env: config.env, key: key, metadata: meta),
    );
  }

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

  Future<void> putMeta(
    String key,
    Map<String, dynamic> metadata, {
    Map<String, dynamic>? meta,
  }) async {
    await HHive.staticPutMeta(
      HHPayload(env: config.env, key: key, metadata: metadata),
    );
  }

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

  Stream<String> keys() async* {
    /// get keys stream, note this will bypass hooks
    final ctx = HHCtx(HHPayload(env: config.env));
    await for (final key in ctx.access.storeKeys()) {
      yield key;
    }
  }

  static Stream<String> staticKeys(HHPayloadI payload) async* {
    /// get keys stream, note this will bypass hooks
    final ctx = HHCtx(payload);
    await for (final key in ctx.access.storeKeys()) {
      yield key;
    }
  }

  Stream<dynamic> values() async* {
    /// get values stream, note this will bypass hooks
    final ctx = HHCtx(HHPayload(env: config.env));
    await for (final value in ctx.access.storeValues()) {
      yield value;
    }
  }

  static Stream<dynamic> staticValues(HHPayloadI payload) async* {
    /// get values stream, note this will bypass hooks
    final ctx = HHCtx(payload);
    await for (final value in ctx.access.storeValues()) {
      yield value;
    }
  }

  Stream<MapEntry<String, dynamic>> entries() async* {
    /// get entries stream, note this will bypass hooks
    final ctx = HHCtx(HHPayload(env: config.env));
    await for (final entry in ctx.access.storeEntries()) {
      yield entry;
    }
  }

  static Stream<MapEntry<String, dynamic>> staticEntries(
    HHPayloadI payload,
  ) async* {
    /// get entries stream, note this will bypass hooks
    final ctx = HHCtx(payload);
    await for (final entry in ctx.access.storeEntries()) {
      yield entry;
    }
  }

  static Future<void> staticClearAll({List<String> exemptList = const []}) async {
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
