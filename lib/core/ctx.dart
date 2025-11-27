import 'dart:convert';
import 'package:hive_ce/hive.dart';
import 'package:hivehook/core/base.dart';
import 'package:hivehook/core/config.dart';
import 'package:hivehook/core/enums.dart';
import 'package:hivehook/core/i_ctx.dart';
import 'package:hivehook/core/payload.dart';

class HHCtxControl extends HHCtxControlI {
  @override
  HHCtx get ctx => super.ctx as HHCtx;

  HHCtxControl(super.ctx);

  Future<dynamic> invoke(
    Future<dynamic> Function(HHCtxI ctx) hookAction,
    bool handleCtrlException,
  ) async {
    try {
      return await hookAction(ctx);
    } on HHCtrlException catch (e) {
      if (!handleCtrlException) {
        rethrow;
      }

      // Handle control flow exception
      switch (e.nextPhase) {
        case NextPhase.f_continue:
          // Continue to next hook
          return null;

        case NextPhase.f_skip:
          // Skip applies to hook batches - rethrow to outer rim
          rethrow;

        case NextPhase.f_break:
          // Break should throw - rethrow to outer handler
          rethrow;

        case NextPhase.f_delete:
          // Delete key and rethrow
          if (ctx.payload.key != null) {
            // Key deletion will be handled at outer level
          }
          rethrow;

        case NextPhase.f_pop:
          // Pop key and rethrow
          if (ctx.payload.key != null) {
            // Key pop will be handled at outer level
          }
          rethrow;

        case NextPhase.f_panic:
          // Throw runtime exception instead
          throw HHRuntimeException('Panic in hook execution: ${e.runtimeMeta}');
      }
    }
  }

  void breakEarly(dynamic returnValue, [Map<String, dynamic>? meta]) {
    throw HHCtrlException(
      nextPhase: NextPhase.f_break,
      returnValue: returnValue,
      runtimeMeta: meta ?? {},
    );
  }

  @override
  Future<dynamic> emit(
    String eventName, {
    Future Function(HHCtxI ctx)? action,
    bool handleCtrlException = false,
  }) async {
    dynamic result;
    bool skipNextBatch = false;

    try {
      // Execute pre-action hooks
      if (!skipNextBatch) {
        final preHooks = ctx.config.preActionHooks[eventName] ?? [];
        // print(
        //   'DEBUG: Executing $eventName - preHooks count: ${preHooks.length}',
        // );
        for (var hook in preHooks) {
          try {
            await invoke(hook.action, handleCtrlException);
          } on HHCtrlException catch (e) {
            if (e.nextPhase == NextPhase.f_skip) {
              // Skip the next batch (main action)
              skipNextBatch = true;
              break;
            }
            rethrow;
          }
        }
      }

      // Execute the main action if provided
      if (action != null && !skipNextBatch) {
        try {
          result = await invoke(action, handleCtrlException);
        } on HHCtrlException catch (e) {
          if (e.nextPhase == NextPhase.f_skip) {
            // Skip the next batch (post hooks)
            skipNextBatch = true;
          } else {
            rethrow;
          }
        }
      }

      // Execute post-action hooks
      if (!skipNextBatch) {
        final postHooks = ctx.config.postActionHooks[eventName] ?? [];
        for (var hook in postHooks) {
          try {
            await invoke(hook.action, handleCtrlException);
          } on HHCtrlException catch (e) {
            if (e.nextPhase == NextPhase.f_skip) {
              // No more batches after post hooks
              break;
            }
            rethrow;
          }
        }
      }
    } on HHCtrlException catch (e) {
      // Handle phase control that affects the entire emit
      switch (e.nextPhase) {
        case NextPhase.f_break:
          // Break out of hook execution - return value
          return e.returnValue;

        case NextPhase.f_delete:
          // Delete the key
          if (ctx.payload.key != null) {
            await ctx.access.storeDelete(ctx.payload.key!);
            if (ctx.config.usesMeta) {
              await ctx.access.metaDelete(ctx.payload.key!);
            }
          }
          return e.returnValue;

        case NextPhase.f_pop:
          // Pop the key and return its value
          if (ctx.payload.key != null) {
            final value = await ctx.access.storePop(ctx.payload.key!);
            return value ?? e.returnValue;
          }
          return e.returnValue;

        case NextPhase.f_skip:
        case NextPhase.f_continue:
        case NextPhase.f_panic:
          // These shouldn't reach here, but rethrow if they do
          rethrow;
      }
    }

    return result;
  }
}

class HHCtxDirectAccess extends HHCtxDirectAccessI {
  @override
  HHCtx get ctx => super.ctx as HHCtx;

  HHCtxDirectAccess(super.ctx);

  Future<CollectionBox<String>> get store async {
    return await HHiveCore.getBox(ctx.env);
  }

  Future<CollectionBox<String>?> get meta async {
    return await HHiveCore.getMetaBox(ctx.env);
  }

  @override
  Future<dynamic> storeGet(String key) async {
    final box = await store;
    final rawResult = await box.get(key);

    if (rawResult == null) return null;

    // Terminal deserialization first
    String valueStr = await ctx.control.emit(
      TriggerType.onValueTDeserialize.name,
      action: (ctx) async {
        String result = rawResult;
        for (var hook in this.ctx.config.storeTerminalSerializationHooks) {
          result = await hook.deserialize(result, ctx);
        }
        return result;
      },
    );

    // Then apply serialization hooks
    final deserializedValue = await ctx.control.emit(
      TriggerType.onValueDeserialize.name,
      action: (ctx) async {
        String result = valueStr;
        for (var hook in this.ctx.config.storeSerializationHooks) {
          if (hook.canHandle != null && !await hook.canHandle!(ctx)) {
            continue;
          }
          try {
            // Update payload so hook can read the current value
            ctx.payload = ctx.payload.copyWith(value: result);
            result = await hook.deserialize(ctx);
          } catch (e) {
            if (!hook.silentOnError) rethrow;
            if (hook.onError != null) await hook.onError!(ctx);
          }
        }
        return result;
      },
    );

    return deserializedValue;
  }

  @override
  Future<void> storePut(String key, dynamic value) async {
    // Apply serialization hooks first
    String serializedValue = await ctx.control.emit(
      TriggerType.onValueSerialize.name,
      action: (ctx) async {
        String result = value.toString();
        for (var hook in this.ctx.config.storeSerializationHooks) {
          if (hook.canHandle != null && !await hook.canHandle!(ctx)) {
            continue;
          }
          try {
            // Update payload so hook can read the current value
            ctx.payload = ctx.payload.copyWith(value: result);
            result = await hook.serialize(ctx);
          } catch (e) {
            if (!hook.silentOnError) rethrow;
            if (hook.onError != null) await hook.onError!(ctx);
          }
        }
        return result;
      },
    );

    // Then apply terminal serialization
    String finalValue = await ctx.control.emit(
      TriggerType.onValueTSerialize.name,
      action: (ctx) async {
        String result = serializedValue;
        for (var hook in this.ctx.config.storeTerminalSerializationHooks) {
          result = await hook.serialize(result, ctx);
        }
        return result;
      },
    );

    final box = await store;
    await box.put(key, finalValue);
  }

  @override
  Future<Map<String, dynamic>?> metaGet(String key) async {
    final box = await meta;
    if (box == null) return null;

    final rawResult = await box.get(key);
    if (rawResult == null) return null;

    // Terminal deserialization (e.g., decryption, decompression)
    String metaStr = await ctx.control.emit(
      TriggerType.onMetaTDeserialize.name,
      action: (ctx) async {
        String result = rawResult;
        for (var hook in this.ctx.config.metaTerminalSerializationHooks) {
          result = await hook.deserialize(result, ctx);
        }
        return result;
      },
    );

    // Metadata is always Map<String, dynamic> - just JSON decode
    return jsonDecode(metaStr) as Map<String, dynamic>;
  }

  @override
  Future<void> metaPut(String key, Map<String, dynamic> value) async {
    final box = await meta;
    if (box == null) return;

    // Metadata is always Map<String, dynamic> - just JSON encode
    String serializedMeta = jsonEncode(value);

    // Apply terminal serialization (e.g., encryption, compression)
    String finalMeta = await ctx.control.emit(
      TriggerType.onMetaTSerialize.name,
      action: (ctx) async {
        String result = serializedMeta;
        for (var hook in this.ctx.config.metaTerminalSerializationHooks) {
          result = await hook.serialize(result, ctx);
        }
        return result;
      },
    );

    await box.put(key, finalMeta);
  }

  @override
  Future<void> storeDelete(String key) async {
    final box = await store;
    await box.delete(key);
  }

  @override
  Future<dynamic> storePop(String key) async {
    // Get the value first
    final value = await storeGet(key);

    // Then delete it
    await storeDelete(key);

    return value;
  }

  @override
  Future<void> storeClear() async {
    final box = await store;
    await box.clear();
  }

  @override
  Future<void> metaDelete(String key) async {
    final box = await meta;
    if (box == null) return;
    await box.delete(key);
  }

  @override
  Future<Map<String, dynamic>?> metaPop(String key) async {
    // Get the value first
    final value = await metaGet(key);

    // Then delete it
    await metaDelete(key);

    return value;
  }

  @override
  Future<void> metaClear() async {
    final box = await meta;
    if (box == null) return;
    await box.clear();
  }
}

class HHCtx extends HHCtxI {
  final HHImmutableConfig config;

  HHCtx(HHPayload super.payload)
    : config = HHImmutableConfig.getInstance(payload.env!)! {
    control = HHCtxControl(this);
    data = HHCtxData(this);
    access = HHCtxDirectAccess(this);
  }

  @override
  String get env => config.env;
}
