import 'dart:convert';
import 'package:hivehook/hivehook.dart';
import '../models/sample_data.dart';

/// Centralized HiveHook service for all test environments
class HiveService {
  static late HHive basicHive;
  static late HHive ttlHive;
  static late HHive lruHive;
  static late HHive jsonHive;
  static late HHive comboHive;

  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;

    // Basic environment - no plugins
    final basicConfig = HHConfig(env: 'basic');
    basicConfig.finalize();

    // TTL environment
    final ttlConfig = HHConfig(env: 'ttl_demo');
    ttlConfig.installPlugin(createTTLPlugin(defaultTTLSeconds: 10));
    ttlConfig.finalize();

    // LRU environment - max 5 items
    final lruConfig = HHConfig(env: 'lru_demo');
    lruConfig.installPlugin(createLRUPlugin(maxSize: 5));
    lruConfig.finalize();

    // JSON serialization environment for complex objects
    final jsonConfig = HHConfig(
      env: 'json_demo',
      serializationHooks: [
        SerializationHook(
          id: 'json',
          serialize: (ctx) async {
            final value = ctx.payload.value;
            if (value is User) return jsonEncode(value.toJson());
            if (value is Product) return jsonEncode(value.toJson());
            if (value is Session) return jsonEncode(value.toJson());
            if (value is Map) return jsonEncode(value);
            if (value is List) return jsonEncode(value);
            return value.toString();
          },
          deserialize: (ctx) async {
            final value = ctx.payload.value;
            if (value is String) {
              try {
                return jsonDecode(value);
              } catch (_) {
                return value;
              }
            }
            return value;
          },
        ),
      ],
    );
    jsonConfig.finalize();

    // Combo environment - TTL + LRU + validation
    final comboConfig = HHConfig(
      env: 'combo_demo',
      actionHooks: [
        HActionHook(
          latches: [HHLatch.pre(triggerType: TriggerType.valueWrite)],
          action: (ctx) async {
            if (ctx.payload.value == null) {
              throw ArgumentError('Value cannot be null');
            }
          },
        ),
      ],
    );
    comboConfig.installPlugin(createTTLPlugin(defaultTTLSeconds: 30));
    comboConfig.installPlugin(createLRUPlugin(maxSize: 10));
    comboConfig.finalize();

    // Initialize all boxes
    await HHiveCore.initialize();

    // Create HHive instances
    basicHive = HHive(config: HHImmutableConfig.getInstance('basic')!);
    ttlHive = HHive(config: HHImmutableConfig.getInstance('ttl_demo')!);
    lruHive = HHive(config: HHImmutableConfig.getInstance('lru_demo')!);
    jsonHive = HHive(config: HHImmutableConfig.getInstance('json_demo')!);
    comboHive = HHive(config: HHImmutableConfig.getInstance('combo_demo')!);

    _initialized = true;
  }
}
