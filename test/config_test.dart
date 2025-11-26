import 'package:test/test.dart';
import 'package:hivehook/core/config.dart';
import 'package:hivehook/hooks/action_hook.dart';
import 'package:hivehook/core/latch.dart';
import 'package:hivehook/core/enums.dart';

void main() {
  group('Config Validation', () {
    test('should create config with valid parameters', () {
      final config = HHImmutableConfig(env: 'test_valid', usesMeta: false);

      expect(config.env, equals('test_valid'));
      expect(config.usesMeta, equals(false));
    });

    test('should throw error if env starts with underscore', () {
      expect(
        () => HHImmutableConfig(env: '_invalid', usesMeta: false),
        throwsArgumentError,
      );
    });

    test(
      'should throw error if action hooks provided but usesMeta is false',
      () {
        expect(
          () => HHImmutableConfig(
            env: 'test_invalid_hooks',
            usesMeta: false,
            actionHooks: [
              HActionHook(
                latches: [
                  HHLatch.pre(triggerType: TriggerType.valueWrite, priority: 0),
                ],
                action: (ctx) async {},
              ),
            ],
          ),
          throwsArgumentError,
        );
      },
    );

    test(
      'should return same instance for same env with identical settings',
      () {
        final config1 = HHImmutableConfig(
          env: 'test_singleton',
          usesMeta: true,
        );

        final config2 = HHImmutableConfig(
          env: 'test_singleton',
          usesMeta: true,
        );

        expect(identical(config1, config2), isTrue);
        expect(config1 == config2, isTrue);
      },
    );

    test('should retrieve config by getInstance', () {
      HHImmutableConfig(env: 'test_get_instance', usesMeta: false);

      final retrieved = HHImmutableConfig.getInstance('test_get_instance');
      expect(retrieved, isNotNull);
      expect(retrieved!.env, equals('test_get_instance'));
    });

    test('should return null for non-existent env', () {
      final retrieved = HHImmutableConfig.getInstance('nonexistent');
      expect(retrieved, isNull);
    });

    test('should allow action hooks when usesMeta is true', () {
      final config = HHImmutableConfig(
        env: 'test_with_hooks',
        usesMeta: true,
        actionHooks: [
          HActionHook(
            latches: [
              HHLatch.pre(triggerType: TriggerType.valueWrite, priority: 0),
            ],
            action: (ctx) async {},
          ),
        ],
      );

      expect(config.actionHooks.length, equals(1));
    });

    test('should organize hooks into pre and post maps', () {
      final config = HHImmutableConfig(
        env: 'test_hook_organization',
        usesMeta: true,
        actionHooks: [
          HActionHook(
            latches: [
              HHLatch.pre(triggerType: TriggerType.valueWrite, priority: 0),
            ],
            action: (ctx) async {},
          ),
          HActionHook(
            latches: [
              HHLatch(
                triggerType: TriggerType.valueWrite,
                isPost: true,
                priority: 0,
              ),
            ],
            action: (ctx) async {},
          ),
        ],
      );

      expect(config.preActionHooks.containsKey('valueWrite'), isTrue);
      expect(config.postActionHooks.containsKey('valueWrite'), isTrue);
    });

    test('should sort hooks by priority (higher first)', () {
      final config = HHImmutableConfig(
        env: 'test_priority_sort',
        usesMeta: true,
        actionHooks: [
          HActionHook(
            latches: [
              HHLatch.pre(triggerType: TriggerType.valueWrite, priority: 10),
            ],
            action: (ctx) async {},
          ),
          HActionHook(
            latches: [
              HHLatch.pre(triggerType: TriggerType.valueWrite, priority: 20),
            ],
            action: (ctx) async {},
          ),
          HActionHook(
            latches: [
              HHLatch.pre(triggerType: TriggerType.valueWrite, priority: 5),
            ],
            action: (ctx) async {},
          ),
        ],
      );

      final preHooks = config.preActionHooks['valueWrite']!;
      expect(preHooks.length, equals(3));

      // Verify they are sorted by priority (highest first)
      final priorities = preHooks
          .map(
            (h) => h.latches
                .where(
                  (l) => l.triggerType == TriggerType.valueWrite && !l.isPost,
                )
                .map((l) => l.priority)
                .fold(0, (max, p) => p > max ? p : max),
          )
          .toList();

      expect(priorities, equals([20, 10, 5]));
    });
  });
}
