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

  static Future<void> staticClear(HHPayload payload) async {
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

  static Future<void> staticDelete(HHPayload payload) async {
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

  static Future<dynamic> staticPop(HHPayload payload) async {
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

  static Future<dynamic> staticGet(HHPayload payload) async {
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

  static Future<void> staticPut(HHPayload payload) async {
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

  static Future<Map<String, dynamic>?> staticGetMeta(HHPayload payload) async {
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

  static Future<void> staticPutMeta(HHPayload payload) async {
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

  static Future<void> dispose(HHPayload payload, {bool clear = true}) async {
    if (clear) {
      // Clear data directly without triggering hooks during disposal
      final ctx = HHCtx(payload);
      await ctx.access.storeClear();
      if (ctx.config.usesMeta) {
        await ctx.access.metaClear();
      }
    }
    await HHiveCore.dispose(payload.env!);
    final config = HHImmutableConfig.getInstance(payload.env!);
    if (config != null) {
      dangerousRemoveConfig(config);
    }
  }
}
