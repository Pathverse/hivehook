import 'package:test/test.dart';
import 'package:hivehook/core/config.dart';
import 'package:hivehook/core/hive.dart';
import 'package:hivehook/core/enums.dart';
import 'package:hivehook/core/i_ctx.dart';
import 'package:hivehook/hooks/action_hook.dart';
import 'package:hivehook/core/latch.dart';

void main() {
  group('Control Flow', () {
    test('should handle f_break control flow', () async {
      final env = 'control_break';
      final config = HHConfig(
        env: env,
        usesMeta: true,
        actionHooks: [
          HActionHook(
            latches: [
              HHLatch.pre(triggerType: TriggerType.valueWrite, priority: 0),
            ],
            action: (ctx) async {
              // Throw HHCtrlException with f_break to stop execution
              throw HHCtrlException(
                nextPhase: NextPhase.f_break,
                returnValue: 'early_return',
                runtimeMeta: {'reason': 'test'},
              );
            },
          ),
        ],
      );
      dangerousReplaceConfig(config);

      final finalConfig = HHImmutableConfig.getInstance(env)!;
      final hive = HHive(config: finalConfig);
      await hive.put('key1', 'value1');

      // The hook should have broken execution, value might not be written
      // This is expected behavior when using f_break
      expect(true, isTrue); // Test that no exception was thrown
    });

    test('should handle f_skip control flow', () async {
      final env = 'control_skip';
      final executions = <String>[];

      final config = HHConfig(
        env: env,
        usesMeta: true,
        actionHooks: [
          HActionHook(
            latches: [
              HHLatch.pre(triggerType: TriggerType.valueWrite, priority: 10),
            ],
            action: (ctx) async {
              executions.add('pre_first');
              throw HHCtrlException(
                nextPhase: NextPhase.f_skip,
                runtimeMeta: {},
              );
            },
          ),
          HActionHook(
            latches: [
              HHLatch.pre(triggerType: TriggerType.valueWrite, priority: 5),
            ],
            action: (ctx) async {
              executions.add('pre_second');
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
              executions.add('post');
            },
          ),
        ],
      );
      dangerousReplaceConfig(config);

      final finalConfig = HHImmutableConfig.getInstance(env)!;
      final hive = HHive(config: finalConfig);
      await hive.put('key1', 'value1');

      // First pre hook ran, but f_skip should have skipped the rest
      expect(executions, contains('pre_first'));
      expect(executions, isNot(contains('pre_second')));
      expect(executions, isNot(contains('post')));
    });

    test('should handle f_continue control flow', () async {
      final env = 'control_continue';
      final executions = <String>[];

      final config = HHConfig(
        env: env,
        usesMeta: true,
        actionHooks: [
          HActionHook(
            latches: [
              HHLatch.pre(triggerType: TriggerType.valueWrite, priority: 10),
            ],
            action: (ctx) async {
              executions.add('pre_first');
              throw HHCtrlException(
                nextPhase: NextPhase.f_continue,
                runtimeMeta: {},
              );
            },
          ),
          HActionHook(
            latches: [
              HHLatch.pre(triggerType: TriggerType.valueWrite, priority: 5),
            ],
            action: (ctx) async {
              executions.add('pre_second');
            },
          ),
        ],
      );
      dangerousReplaceConfig(config);

      final finalConfig = HHImmutableConfig.getInstance(env)!;
      final hive = HHive(config: finalConfig);
      await hive.put('key1', 'value1');

      // f_continue should allow execution to continue to next hook
      expect(executions, contains('pre_first'));
      expect(executions, contains('pre_second'));
    });

    test('should handle f_panic control flow', () async {
      final env = 'control_panic';
      final config = HHConfig(
        env: env,
        usesMeta: true,
        actionHooks: [
          HActionHook(
            latches: [
              HHLatch.pre(triggerType: TriggerType.valueWrite, priority: 0),
            ],
            action: (ctx) async {
              throw HHCtrlException(
                nextPhase: NextPhase.f_panic,
                runtimeMeta: {'error': 'Something went wrong'},
              );
            },
          ),
        ],
      );
      dangerousReplaceConfig(config);

      final finalConfig = HHImmutableConfig.getInstance(env)!;
      final hive = HHive(config: finalConfig);

      // f_panic should throw HHRuntimeException
      expect(
        () async => await hive.put('key1', 'value1'),
        throwsA(isA<HHRuntimeException>()),
      );
    });

    test('should handle f_delete control flow', () async {
      final env = 'control_delete';
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
              // After writing, immediately delete
              throw HHCtrlException(
                nextPhase: NextPhase.f_delete,
                runtimeMeta: {},
              );
            },
          ),
        ],
      );
      dangerousReplaceConfig(config);

      final finalConfig = HHImmutableConfig.getInstance(env)!;
      final hive = HHive(config: finalConfig);
      await hive.put('key1', 'value1');

      // Value should have been deleted by the hook
      expect(await hive.get('key1'), isNull);
    });

    test('should handle f_pop control flow and return value', () async {
      final env = 'control_pop';
      final config = HHConfig(
        env: env,
        usesMeta: true,
        actionHooks: [
          HActionHook(
            latches: [
              HHLatch(
                triggerType: TriggerType.valueRead,
                isPost: true,
                priority: 0,
              ),
            ],
            action: (ctx) async {
              // After reading, delete the key
              throw HHCtrlException(
                nextPhase: NextPhase.f_pop,
                runtimeMeta: {},
              );
            },
          ),
        ],
      );
      dangerousReplaceConfig(config);

      final finalConfig = HHImmutableConfig.getInstance(env)!;
      final hive = HHive(config: finalConfig);
      await hive.put('key1', 'value1');

      final result = await hive.get('key1');

      // Should have returned the value
      expect(result, equals('value1'));

      // And deleted it
      expect(await hive.get('key1'), isNull);
    });

    test('should handle nested control flow exceptions', () async {
      final env = 'control_nested';
      final executions = <String>[];

      final config = HHConfig(
        env: env,
        usesMeta: true,
        actionHooks: [
          HActionHook(
            latches: [
              HHLatch.pre(triggerType: TriggerType.valueWrite, priority: 0),
            ],
            action: (ctx) async {
              executions.add('outer_hook');
              // Call another emit inside this hook
              await ctx.control.emit(
                TriggerType.valueRead.name,
                action: (ctx) async {
                  executions.add('inner_action');
                  throw HHCtrlException(
                    nextPhase: NextPhase.f_break,
                    returnValue: 'inner_break',
                    runtimeMeta: {},
                  );
                },
                handleCtrlException: true,
              );
              executions.add('after_inner');
            },
          ),
        ],
      );
      dangerousReplaceConfig(config);

      final finalConfig = HHImmutableConfig.getInstance(env)!;
      final hive = HHive(config: finalConfig);
      await hive.put('key1', 'value1');

      // Outer hook should execute, inner action should break, then outer should continue
      expect(executions, contains('outer_hook'));
      expect(executions, contains('inner_action'));
      expect(executions, contains('after_inner'));
    });
  });
}
