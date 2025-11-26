import 'package:test/test.dart';
import 'package:hivehook/core/config.dart';
import 'package:hivehook/core/hive.dart';
import 'package:hivehook/hooks/action_hook.dart';
import 'package:hivehook/core/latch.dart';
import 'package:hivehook/core/enums.dart';

void main() {
  late List<String> hookExecutions;

  setUp(() async {
    hookExecutions = [];
  });

  group('Hook Execution', () {
    test('should execute pre-action hooks before operation', () async {
      final env = 'hooks_pre';
      final config = HHConfig(
        env: env,
        usesMeta: true,
        actionHooks: [
          HActionHook(
            latches: [
              HHLatch.pre(triggerType: TriggerType.valueWrite, priority: 0),
            ],
            action: (ctx) async {
              hookExecutions.add('pre_write');
            },
          ),
        ],
      );
      dangerousReplaceConfig(config);

      final finalConfig = HHImmutableConfig.getInstance(env)!;
      final hive = HHive(config: finalConfig);
      await hive.put('key1', 'value1');

      expect(hookExecutions, contains('pre_write'));
    });

    test('should execute post-action hooks after operation', () async {
      final env = 'hooks_post';
      final config = HHConfig(
        env: env,
        usesMeta: true,
        actionHooks: [
          HActionHook(
            latches: [
              HHLatch(
                triggerType: TriggerType.valueWrite,
                isPost: true,
                priority: 0,
              ),
            ],
            action: (ctx) async {
              hookExecutions.add('post_write');
            },
          ),
        ],
      );
      dangerousReplaceConfig(config);

      final finalConfig = HHImmutableConfig.getInstance(env)!;
      final hive = HHive(config: finalConfig);
      await hive.put('key1', 'value1');

      expect(hookExecutions, contains('post_write'));
    });

    test('should execute hooks in priority order (higher first)', () async {
      final env = 'hooks_priority';
      final config = HHConfig(
        env: env,
        usesMeta: true,
        actionHooks: [
          HActionHook(
            latches: [
              HHLatch.pre(triggerType: TriggerType.valueWrite, priority: 10),
            ],
            action: (ctx) async {
              hookExecutions.add('priority_10');
            },
          ),
          HActionHook(
            latches: [
              HHLatch.pre(triggerType: TriggerType.valueWrite, priority: 20),
            ],
            action: (ctx) async {
              hookExecutions.add('priority_20');
            },
          ),
          HActionHook(
            latches: [
              HHLatch.pre(triggerType: TriggerType.valueWrite, priority: 5),
            ],
            action: (ctx) async {
              hookExecutions.add('priority_5');
            },
          ),
        ],
      );
      dangerousReplaceConfig(config);

      final finalConfig = HHImmutableConfig.getInstance(env)!;
      final hive = HHive(config: finalConfig);
      await hive.put('key1', 'value1');

      expect(
        hookExecutions,
        equals(['priority_20', 'priority_10', 'priority_5']),
      );
    });

    test('should pass context data through hooks', () async {
      final env = 'hooks_context';
      String? capturedKey;
      dynamic capturedValue;

      final config = HHConfig(
        env: env,
        usesMeta: true,
        actionHooks: [
          HActionHook(
            latches: [
              HHLatch.pre(triggerType: TriggerType.valueWrite, priority: 0),
            ],
            action: (ctx) async {
              capturedKey = ctx.payload.key;
              capturedValue = ctx.payload.value;
            },
          ),
        ],
      );
      dangerousReplaceConfig(config);

      final finalConfig = HHImmutableConfig.getInstance(env)!;
      final hive = HHive(config: finalConfig);
      await hive.put('test_key', 'test_value');

      expect(capturedKey, equals('test_key'));
      expect(capturedValue, equals('test_value'));
    });

    test('should execute both pre and post hooks in order', () async {
      final env = 'hooks_both';
      final config = HHConfig(
        env: env,
        usesMeta: true,
        actionHooks: [
          HActionHook(
            latches: [
              HHLatch.pre(triggerType: TriggerType.valueWrite, priority: 0),
            ],
            action: (ctx) async {
              hookExecutions.add('pre');
            },
          ),
          HActionHook(
            latches: [
              HHLatch(
                triggerType: TriggerType.valueWrite,
                isPost: true,
                priority: 0,
              ),
            ],
            action: (ctx) async {
              hookExecutions.add('post');
            },
          ),
        ],
      );
      dangerousReplaceConfig(config);

      final finalConfig = HHImmutableConfig.getInstance(env)!;
      final hive = HHive(config: finalConfig);
      await hive.put('key1', 'value1');

      expect(hookExecutions, equals(['pre', 'post']));
    });

    test('should execute hooks for different trigger types', () async {
      final env = 'hooks_types';
      final config = HHConfig(
        env: env,
        usesMeta: true,
        actionHooks: [
          HActionHook(
            latches: [
              HHLatch.pre(triggerType: TriggerType.valueWrite, priority: 0),
            ],
            action: (ctx) async {
              hookExecutions.add('write');
            },
          ),
          HActionHook(
            latches: [
              HHLatch.pre(triggerType: TriggerType.valueRead, priority: 0),
            ],
            action: (ctx) async {
              hookExecutions.add('read');
            },
          ),
          HActionHook(
            latches: [
              HHLatch.pre(triggerType: TriggerType.onDelete, priority: 0),
            ],
            action: (ctx) async {
              hookExecutions.add('delete');
            },
          ),
        ],
      );
      dangerousReplaceConfig(config);

      final finalConfig = HHImmutableConfig.getInstance(env)!;
      final hive = HHive(config: finalConfig);

      await hive.put('key1', 'value1');
      expect(hookExecutions, contains('write'));

      hookExecutions.clear();
      await hive.get('key1');
      expect(hookExecutions, contains('read'));

      hookExecutions.clear();
      await hive.delete('key1');
      expect(hookExecutions, contains('delete'));
    });

    test('should allow metadata in hook context', () async {
      final env = 'hooks_meta';
      Map<String, dynamic>? capturedMeta;

      final config = HHConfig(
        env: env,
        usesMeta: true,
        actionHooks: [
          HActionHook(
            latches: [
              HHLatch.pre(triggerType: TriggerType.valueWrite, priority: 0),
            ],
            action: (ctx) async {
              capturedMeta = ctx.payload.metadata;
            },
          ),
        ],
      );
      dangerousReplaceConfig(config);

      final finalConfig = HHImmutableConfig.getInstance(env)!;
      final hive = HHive(config: finalConfig);
      await hive.put('key1', 'value1', meta: {'custom': 'data'});

      expect(capturedMeta, isNotNull);
      expect(capturedMeta!['custom'], equals('data'));
    });
  });
}
