@TestOn('vm')
library;

import 'package:hivehook/hivehook.dart';
import 'package:test/test.dart';

import '../common/test_helpers.dart';

void main() {
  group('HHive Hook Integration', () {
    setUp(() async {
      await resetHiveState();
    });

    tearDown(() async {
      await resetHiveState();
    });

    group('Basic hooks', () {
      test('hook receives write events', () async {
        final events = <String>[];

        final loggingHook = HiHook<dynamic, dynamic>(
          uid: 'test:logging',
          events: ['write'],
          handler: (payload, ctx) {
            events.add('write:${payload.key}');
            return HiContinue(payload: payload);
          },
        );

        await initHiveCore(configs: [
          HiveConfig(
            env: 'test',
            boxCollectionName: generateCollectionName(),
            hooks: [loggingHook],
          ),
        ]);

        final hive = await HHive.create('test');

        await hive.put('key1', 'value1');
        await hive.put('key2', 'value2');

        expect(events, ['write:key1', 'write:key2']);
      });

      test('hook receives read events', () async {
        final events = <String>[];

        final loggingHook = HiHook<dynamic, dynamic>(
          uid: 'test:logging',
          events: ['read'],
          handler: (payload, ctx) {
            events.add('read:${payload.key}');
            return HiContinue(payload: payload);
          },
        );

        await initHiveCore(configs: [
          HiveConfig(
            env: 'test',
            boxCollectionName: generateCollectionName(),
            hooks: [loggingHook],
          ),
        ]);

        final hive = await HHive.create('test');

        await hive.put('key1', 'value1');
        await hive.get('key1');
        await hive.get('key2'); // non-existent

        expect(events, ['read:key1', 'read:key2']);
      });

      test('hook receives delete events', () async {
        final events = <String>[];

        final loggingHook = HiHook<dynamic, dynamic>(
          uid: 'test:logging',
          events: ['delete'],
          handler: (payload, ctx) {
            events.add('delete:${payload.key}');
            return HiContinue(payload: payload);
          },
        );

        await initHiveCore(configs: [
          HiveConfig(
            env: 'test',
            boxCollectionName: generateCollectionName(),
            hooks: [loggingHook],
          ),
        ]);

        final hive = await HHive.create('test');

        await hive.put('key1', 'value1');
        await hive.delete('key1');

        expect(events, ['delete:key1']);
      });

      test('hook receives clear events', () async {
        var clearCalled = false;

        final loggingHook = HiHook<dynamic, dynamic>(
          uid: 'test:logging',
          events: ['clear'],
          handler: (payload, ctx) {
            clearCalled = true;
            return HiContinue(payload: payload);
          },
        );

        await initHiveCore(configs: [
          HiveConfig(
            env: 'test',
            boxCollectionName: generateCollectionName(),
            hooks: [loggingHook],
          ),
        ]);

        final hive = await HHive.create('test');

        await hive.put('key1', 'value1');
        await hive.clear();

        expect(clearCalled, isTrue);
      });
    });

    group('HiBreak behavior', () {
      test('HiBreak on read returns break value instead of stored value', () async {
        final breakHook = HiHook<dynamic, dynamic>(
          uid: 'test:break',
          events: ['read'],
          handler: (payload, ctx) {
            if (payload.key == 'intercepted') {
              return HiBreak<dynamic>(returnValue: 'intercepted-value');
            }
            return HiContinue(payload: payload);
          },
        );

        await initHiveCore(configs: [
          HiveConfig(
            env: 'test',
            boxCollectionName: generateCollectionName(),
            hooks: [breakHook],
          ),
        ]);

        final hive = await HHive.create('test');

        await hive.put('intercepted', 'stored-value');
        await hive.put('normal', 'normal-value');

        // Intercepted key returns hook-provided value
        expect(await hive.get('intercepted'), 'intercepted-value');

        // Normal key returns stored value
        expect(await hive.get('normal'), 'normal-value');
      });

      test('HiBreak on write prevents storage', () async {
        final breakHook = HiHook<dynamic, dynamic>(
          uid: 'test:break',
          events: ['write'],
          handler: (payload, ctx) {
            if (payload.key?.startsWith('blocked:') ?? false) {
              return HiBreak<dynamic>(returnValue: null);
            }
            return HiContinue(payload: payload);
          },
        );

        await initHiveCore(configs: [
          HiveConfig(
            env: 'test',
            boxCollectionName: generateCollectionName(),
            hooks: [breakHook],
          ),
        ]);

        final hive = await HHive.create('test');

        await hive.put('blocked:secret', 'sensitive-data');
        await hive.put('allowed:data', 'normal-data');

        // Blocked key should not be stored
        expect(await hive.get('blocked:secret'), isNull);

        // Allowed key should be stored
        expect(await hive.get('allowed:data'), 'normal-data');
      });
    });

    group('HiDelete behavior', () {
      test('HiDelete on read deletes the entry', () async {
        final deleteHook = HiHook<dynamic, dynamic>(
          uid: 'test:delete',
          events: ['read'],
          handler: (payload, ctx) {
            if (payload.key == 'ephemeral') {
              return const HiDelete();
            }
            return HiContinue(payload: payload);
          },
        );

        await initHiveCore(configs: [
          HiveConfig(
            env: 'test',
            boxCollectionName: generateCollectionName(),
            hooks: [deleteHook],
          ),
        ]);

        final hive = await HHive.create('test');

        await hive.put('ephemeral', 'temp-data');
        await hive.put('permanent', 'keep-data');

        // First read of ephemeral triggers delete
        expect(await hive.get('ephemeral'), isNull);

        // Subsequent read confirms it's gone
        expect(await hive.get('ephemeral'), isNull);

        // Permanent key unaffected
        expect(await hive.get('permanent'), 'keep-data');
      });
    });

    group('HiContinue with modified payload', () {
      test('hook can modify value on write', () async {
        final transformHook = HiHook<dynamic, dynamic>(
          uid: 'test:transform',
          events: ['write'],
          handler: (payload, ctx) {
            if (payload.value is String) {
              final modified = HiPayload<dynamic>(
                key: payload.key,
                value: (payload.value as String).toUpperCase(),
                env: payload.env,
                metadata: payload.metadata,
              );
              return HiContinue(payload: modified);
            }
            return HiContinue(payload: payload);
          },
        );

        await initHiveCore(configs: [
          HiveConfig(
            env: 'test',
            boxCollectionName: generateCollectionName(),
            hooks: [transformHook],
          ),
        ]);

        final hive = await HHive.create('test');

        await hive.put('message', 'hello world');

        // Value should be transformed to uppercase
        expect(await hive.get('message'), 'HELLO WORLD');
      });
    });

    group('Multiple hooks', () {
      test('hooks run in order', () async {
        final order = <String>[];

        final hook1 = HiHook<dynamic, dynamic>(
          uid: 'test:first',
          events: ['write'],
          handler: (payload, ctx) {
            order.add('first');
            return HiContinue(payload: payload);
          },
        );

        final hook2 = HiHook<dynamic, dynamic>(
          uid: 'test:second',
          events: ['write'],
          handler: (payload, ctx) {
            order.add('second');
            return HiContinue(payload: payload);
          },
        );

        await initHiveCore(configs: [
          HiveConfig(
            env: 'test',
            boxCollectionName: generateCollectionName(),
            hooks: [hook1, hook2],
          ),
        ]);

        final hive = await HHive.create('test');

        await hive.put('key', 'value');

        expect(order, ['first', 'second']);
      });

      test('early hook break stops subsequent hooks', () async {
        final order = <String>[];

        final hook1 = HiHook<dynamic, dynamic>(
          uid: 'test:first',
          events: ['write'],
          handler: (payload, ctx) {
            order.add('first');
            return HiBreak<dynamic>(returnValue: null); // Stop here
          },
        );

        final hook2 = HiHook<dynamic, dynamic>(
          uid: 'test:second',
          events: ['write'],
          handler: (payload, ctx) {
            order.add('second'); // Should not run
            return HiContinue(payload: payload);
          },
        );

        await initHiveCore(configs: [
          HiveConfig(
            env: 'test',
            boxCollectionName: generateCollectionName(),
            hooks: [hook1, hook2],
          ),
        ]);

        final hive = await HHive.create('test');

        await hive.put('key', 'value');

        expect(order, ['first']); // Only first hook ran
      });
    });

    group('Global hooks', () {
      test('global hooks apply to all environments', () async {
        final events = <String>[];

        final globalHook = HiHook<dynamic, dynamic>(
          uid: 'test:global',
          events: ['write'],
          handler: (payload, ctx) {
            events.add('${payload.env}:${payload.key}');
            return HiContinue(payload: payload);
          },
        );

        HHiveCore.globalHooks.add(globalHook);

        await initHiveCore(configs: [
          HiveConfig(
            env: 'env1',
            boxCollectionName: generateCollectionName(),
          ),
          HiveConfig(
            env: 'env2',
            boxCollectionName: generateCollectionName(),
          ),
        ]);

        final hive1 = await HHive.create('env1');
        final hive2 = await HHive.create('env2');

        await hive1.put('key1', 'value1');
        await hive2.put('key2', 'value2');

        expect(events, ['env1:key1', 'env2:key2']);
      });
    });
  });
}


