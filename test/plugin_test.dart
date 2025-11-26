import 'package:test/test.dart';
import 'package:hivehook/core/config.dart';
import 'package:hivehook/core/hive.dart';
import 'package:hivehook/core/base.dart';
import 'package:hivehook/hooks/action_hook.dart';
import 'package:hivehook/helper/plugin.dart';
import 'package:hivehook/core/latch.dart';
import 'package:hivehook/core/enums.dart';

void main() {
  late List<String> executionLog;

  setUpAll(() async {
    // Initialize test configs BEFORE HHiveCore.initialize() so box names are registered
    // These placeholder configs will be replaced with actual hooks via dangerousReplaceConfig
    HHImmutableConfig(env: 'plugin_install', usesMeta: true);
    HHImmutableConfig(env: 'plugin_duplicate', usesMeta: true);
    HHImmutableConfig(env: 'plugin_missing', usesMeta: true);
    HHImmutableConfig(env: 'plugin_immutable_install', usesMeta: true);
    HHImmutableConfig(env: 'plugin_immutable_uninstall', usesMeta: true);
    HHImmutableConfig(env: 'plugin_uninstall', usesMeta: true);
    HHImmutableConfig(env: 'plugin_multiple', usesMeta: true);

    await HHiveCore.initialize();
  });

  setUp(() async {
    executionLog = [];
  });

  group('Plugin System', () {
    test('should install plugin and execute its hooks', () async {
      final env = 'plugin_install';

      // Create a plugin with hooks
      final loggingPlugin = HHPlugin(
        actionHooks: [
          HActionHook(
            latches: [
              HHLatch.pre(triggerType: TriggerType.valueWrite, priority: 0),
            ],
            action: (ctx) async {
              executionLog.add('plugin_write_${ctx.payload.key}');
            },
          ),
          HActionHook(
            latches: [
              HHLatch.pre(triggerType: TriggerType.valueRead, priority: 0),
            ],
            action: (ctx) async {
              executionLog.add('plugin_read_${ctx.payload.key}');
            },
          ),
        ],
      );

      final config = HHConfig(env: env, usesMeta: true);
      config.installPlugin(loggingPlugin);

      expect(config.installedPlugins, hasLength(1));
      expect(config.installedPlugins[loggingPlugin.uid], isNotNull);
      expect(config.actionHooks, hasLength(2));

      dangerousReplaceConfig(config);

      final finalConfig = HHImmutableConfig.getInstance(env)!;
      final hive = HHive(config: finalConfig);

      await hive.put('key1', 'value1');
      await hive.get('key1');

      expect(executionLog, contains('plugin_write_key1'));
      expect(executionLog, contains('plugin_read_key1'));
    });

    test('should uninstall plugin and stop executing its hooks', () async {
      final env = 'plugin_uninstall';

      final plugin = HHPlugin(
        actionHooks: [
          HActionHook(
            latches: [
              HHLatch.pre(triggerType: TriggerType.valueWrite, priority: 0),
            ],
            action: (ctx) async {
              executionLog.add('temp_hook');
            },
          ),
        ],
      );

      final config = HHConfig(env: env, usesMeta: true);
      config.installPlugin(plugin);

      expect(config.installedPlugins, hasLength(1));
      expect(config.actionHooks, hasLength(1));

      config.uninstallPlugin(plugin.uid);

      expect(config.installedPlugins, hasLength(0));
      expect(config.actionHooks, hasLength(0));
    });

    test('should prevent installing same plugin twice', () async {
      final plugin = HHPlugin(
        actionHooks: [
          HActionHook(
            latches: [HHLatch.pre(triggerType: TriggerType.valueWrite)],
            action: (ctx) async {},
          ),
        ],
      );
      final config = HHConfig(env: 'plugin_duplicate', usesMeta: true);

      config.installPlugin(plugin);

      expect(() => config.installPlugin(plugin), throwsArgumentError);
    });

    test('should prevent uninstalling non-existent plugin', () async {
      final config = HHConfig(env: 'plugin_missing', usesMeta: true);

      expect(() => config.uninstallPlugin('nonexistent'), throwsArgumentError);
    });

    test(
      'should throw error when installing plugin on immutable config',
      () async {
        final env = 'plugin_immutable_install';
        final config = HHConfig(env: env, usesMeta: true);
        final immutableConfig = config.finalize();

        final plugin = HHPlugin(
          actionHooks: [
            HActionHook(
              latches: [HHLatch.pre(triggerType: TriggerType.valueWrite)],
              action: (ctx) async {},
            ),
          ],
        );

        expect(
          () => immutableConfig.installPlugin(plugin),
          throwsUnsupportedError,
        );
      },
    );

    test(
      'should throw error when uninstalling plugin from immutable config',
      () async {
        final env = 'plugin_immutable_uninstall';
        final plugin = HHPlugin(
          actionHooks: [
            HActionHook(
              latches: [HHLatch.pre(triggerType: TriggerType.valueWrite)],
              action: (ctx) async {},
            ),
          ],
        );
        final config = HHConfig(env: env, usesMeta: true);
        config.installPlugin(plugin);

        dangerousReplaceConfig(config);
        final immutableConfig = HHImmutableConfig.getInstance(env)!;

        expect(
          () => immutableConfig.uninstallPlugin(plugin.uid),
          throwsUnsupportedError,
        );
      },
    );

    test('should assign unique UIDs to hooks', () async {
      final hook1 = HActionHook(
        latches: [HHLatch.pre(triggerType: TriggerType.valueWrite)],
        action: (ctx) async {},
      );

      final hook2 = HActionHook(
        latches: [HHLatch.pre(triggerType: TriggerType.valueRead)],
        action: (ctx) async {},
      );

      expect(hook1.uid, isNotEmpty);
      expect(hook2.uid, isNotEmpty);
      expect(hook1.uid, isNot(equals(hook2.uid)));
    });

    test('should install multiple plugins', () async {
      final env = 'plugin_multiple';

      final plugin1 = HHPlugin(
        actionHooks: [
          HActionHook(
            latches: [HHLatch.pre(triggerType: TriggerType.valueWrite)],
            action: (ctx) async {
              executionLog.add('plugin1');
            },
          ),
        ],
      );

      final plugin2 = HHPlugin(
        actionHooks: [
          HActionHook(
            latches: [HHLatch.pre(triggerType: TriggerType.valueWrite)],
            action: (ctx) async {
              executionLog.add('plugin2');
            },
          ),
        ],
      );

      final config = HHConfig(env: env, usesMeta: true);
      config.installPlugin(plugin1);
      config.installPlugin(plugin2);

      expect(config.installedPlugins, hasLength(2));
      expect(config.actionHooks, hasLength(2));

      dangerousReplaceConfig(config);

      final finalConfig = HHImmutableConfig.getInstance(env)!;
      final hive = HHive(config: finalConfig);

      await hive.put('key', 'value');

      expect(executionLog, contains('plugin1'));
      expect(executionLog, contains('plugin2'));
    });
  });
}
