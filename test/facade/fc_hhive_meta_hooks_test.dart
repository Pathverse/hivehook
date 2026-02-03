@TestOn('vm')
library;

import 'package:hivehook/hivehook.dart';
import 'package:test/test.dart';

import '../common/test_helpers.dart';

void main() {
  group('HHive Meta Hooks', () {
    setUp(() async {
      await resetHiveState();
    });

    tearDown(() async {
      await resetHiveState();
    });

    group('Meta events emission', () {
      test('get() emits readMeta before read', () async {
        final events = <String>[];

        final loggingHook = HiHook<dynamic, dynamic>(
          uid: 'test:logging',
          events: ['read'],
          handler: (payload, ctx) {
            events.add('read:${payload.key}');
            return HiContinue(payload: payload);
          },
        );

        final metaLoggingHook = HiHook<dynamic, dynamic>(
          uid: 'test:meta-logging',
          events: ['readMeta'],
          handler: (payload, ctx) {
            events.add('readMeta:${payload.key}');
            return HiContinue(payload: payload);
          },
        );

        await initHiveCore(configs: [
          HiveConfig(
            env: 'test',
            boxCollectionName: generateCollectionName(),
            withMeta: true,
            hooks: [loggingHook],
            metaHooks: [metaLoggingHook],
          ),
        ]);

        final hive = await HHive.create('test');

        await hive.put('key1', 'value1', meta: {'ttl': 3600});
        events.clear(); // Clear write events

        await hive.get('key1');

        // readMeta should come BEFORE read
        expect(events, ['readMeta:key1', 'read:key1']);
      });

      test('put() emits write then writeMeta', () async {
        final events = <String>[];

        final loggingHook = HiHook<dynamic, dynamic>(
          uid: 'test:logging',
          events: ['write'],
          handler: (payload, ctx) {
            events.add('write:${payload.key}');
            return HiContinue(payload: payload);
          },
        );

        final metaLoggingHook = HiHook<dynamic, dynamic>(
          uid: 'test:meta-logging',
          events: ['writeMeta'],
          handler: (payload, ctx) {
            events.add('writeMeta:${payload.key}');
            return HiContinue(payload: payload);
          },
        );

        await initHiveCore(configs: [
          HiveConfig(
            env: 'test',
            boxCollectionName: generateCollectionName(),
            withMeta: true,
            hooks: [loggingHook],
            metaHooks: [metaLoggingHook],
          ),
        ]);

        final hive = await HHive.create('test');

        await hive.put('key1', 'value1', meta: {'ttl': 3600});

        // write should come BEFORE writeMeta
        expect(events, ['write:key1', 'writeMeta:key1']);
      });

      test('delete() emits delete then deleteMeta', () async {
        final events = <String>[];

        final loggingHook = HiHook<dynamic, dynamic>(
          uid: 'test:logging',
          events: ['delete'],
          handler: (payload, ctx) {
            events.add('delete:${payload.key}');
            return HiContinue(payload: payload);
          },
        );

        final metaLoggingHook = HiHook<dynamic, dynamic>(
          uid: 'test:meta-logging',
          events: ['deleteMeta'],
          handler: (payload, ctx) {
            events.add('deleteMeta:${payload.key}');
            return HiContinue(payload: payload);
          },
        );

        await initHiveCore(configs: [
          HiveConfig(
            env: 'test',
            boxCollectionName: generateCollectionName(),
            withMeta: true,
            hooks: [loggingHook],
            metaHooks: [metaLoggingHook],
          ),
        ]);

        final hive = await HHive.create('test');

        await hive.put('key1', 'value1', meta: {'ttl': 3600});
        events.clear();

        await hive.delete('key1');

        expect(events, ['delete:key1', 'deleteMeta:key1']);
      });

      test('clear() emits clear then clearMeta', () async {
        final events = <String>[];

        final loggingHook = HiHook<dynamic, dynamic>(
          uid: 'test:logging',
          events: ['clear'],
          handler: (payload, ctx) {
            events.add('clear');
            return HiContinue(payload: payload);
          },
        );

        final metaLoggingHook = HiHook<dynamic, dynamic>(
          uid: 'test:meta-logging',
          events: ['clearMeta'],
          handler: (payload, ctx) {
            events.add('clearMeta');
            return HiContinue(payload: payload);
          },
        );

        await initHiveCore(configs: [
          HiveConfig(
            env: 'test',
            boxCollectionName: generateCollectionName(),
            withMeta: true,
            hooks: [loggingHook],
            metaHooks: [metaLoggingHook],
          ),
        ]);

        final hive = await HHive.create('test');

        await hive.put('key1', 'value1', meta: {'ttl': 3600});
        events.clear();

        await hive.clear();

        expect(events, ['clear', 'clearMeta']);
      });
    });

    group('Standalone meta methods', () {
      test('getMeta() emits readMeta and returns meta', () async {
        final events = <String>[];

        final metaLoggingHook = HiHook<dynamic, dynamic>(
          uid: 'test:meta-logging',
          events: ['readMeta'],
          handler: (payload, ctx) {
            events.add('readMeta:${payload.key}');
            return HiContinue(payload: payload);
          },
        );

        await initHiveCore(configs: [
          HiveConfig(
            env: 'test',
            boxCollectionName: generateCollectionName(),
            withMeta: true,
            metaHooks: [metaLoggingHook],
          ),
        ]);

        final hive = await HHive.create('test');

        await hive.put('key1', 'value1', meta: {'ttl': 3600});
        events.clear();

        final meta = await hive.getMeta('key1');

        expect(events, ['readMeta:key1']);
        expect(meta, {'ttl': 3600});
      });

      test('putMeta() emits writeMeta and stores meta', () async {
        final events = <String>[];

        final metaLoggingHook = HiHook<dynamic, dynamic>(
          uid: 'test:meta-logging',
          events: ['writeMeta'],
          handler: (payload, ctx) {
            events.add('writeMeta:${payload.key}');
            return HiContinue(payload: payload);
          },
        );

        await initHiveCore(configs: [
          HiveConfig(
            env: 'test',
            boxCollectionName: generateCollectionName(),
            withMeta: true,
            metaHooks: [metaLoggingHook],
          ),
        ]);

        final hive = await HHive.create('test');

        await hive.put('key1', 'value1');
        events.clear();

        await hive.putMeta('key1', {'updated': true});

        expect(events, ['writeMeta:key1']);

        final meta = await hive.store.getMeta('key1');
        expect(meta, {'updated': true});
      });

      test('deleteMeta() emits deleteMeta and removes meta only', () async {
        final events = <String>[];

        final metaLoggingHook = HiHook<dynamic, dynamic>(
          uid: 'test:meta-logging',
          events: ['deleteMeta'],
          handler: (payload, ctx) {
            events.add('deleteMeta:${payload.key}');
            return HiContinue(payload: payload);
          },
        );

        await initHiveCore(configs: [
          HiveConfig(
            env: 'test',
            boxCollectionName: generateCollectionName(),
            withMeta: true,
            metaHooks: [metaLoggingHook],
          ),
        ]);

        final hive = await HHive.create('test');

        await hive.put('key1', 'value1', meta: {'ttl': 3600});
        events.clear();

        await hive.deleteMeta('key1');

        expect(events, ['deleteMeta:key1']);

        // Value should still exist
        expect(await hive.get('key1'), 'value1');
        // Meta should be gone
        expect(await hive.store.getMeta('key1'), isNull);
      });
    });

    group('Meta hook transformation', () {
      test('writeMeta hook can transform metadata', () async {
        final encryptMetaHook = HiHook<dynamic, dynamic>(
          uid: 'test:encrypt-meta',
          events: ['writeMeta'],
          handler: (payload, ctx) {
            final meta = payload.value as Map<String, dynamic>?;
            if (meta != null) {
              final encrypted = {
                'encrypted': true,
                'data': 'encrypted:${meta.toString()}',
              };
              return HiContinue(payload: payload.copyWith(value: encrypted));
            }
            return HiContinue(payload: payload);
          },
        );

        await initHiveCore(configs: [
          HiveConfig(
            env: 'test',
            boxCollectionName: generateCollectionName(),
            withMeta: true,
            metaHooks: [encryptMetaHook],
          ),
        ]);

        final hive = await HHive.create('test');

        await hive.put('key1', 'value1', meta: {'secret': 'password'});

        // Stored meta should be transformed
        final storedMeta = await hive.store.getMeta('key1');
        expect(storedMeta?['encrypted'], isTrue);
        expect(storedMeta?['data'], contains('secret'));
      });

      test('readMeta hook can transform metadata on read', () async {
        final decryptMetaHook = HiHook<dynamic, dynamic>(
          uid: 'test:decrypt-meta',
          events: ['readMeta'],
          handler: (payload, ctx) {
            final meta = payload.value as Map<String, dynamic>?;
            if (meta != null && meta['encrypted'] == true) {
              // Simulate decryption
              final decrypted = {'decrypted': true, 'original': meta['data']};
              return HiContinue(payload: payload.copyWith(value: decrypted));
            }
            return HiContinue(payload: payload);
          },
        );

        await initHiveCore(configs: [
          HiveConfig(
            env: 'test',
            boxCollectionName: generateCollectionName(),
            withMeta: true,
            metaHooks: [decryptMetaHook],
          ),
        ]);

        final hive = await HHive.create('test');

        // Store encrypted meta directly
        await hive.store.putMeta('key1', {'encrypted': true, 'data': 'secret'});
        await hive.store.put('key1', 'value1');

        // getMeta should decrypt
        final meta = await hive.getMeta('key1');
        expect(meta?['decrypted'], isTrue);
        expect(meta?['original'], 'secret');
      });
    });

    group('Meta-first invalidation pattern', () {
      test('readMeta HiDelete causes early exit and deletion', () async {
        final ttlHook = HiHook<dynamic, dynamic>(
          uid: 'test:ttl',
          events: ['readMeta'],
          handler: (payload, ctx) {
            final meta = payload.value as Map<String, dynamic>?;
            if (meta != null && meta['expired'] == true) {
              return HiDelete<dynamic>();
            }
            return HiContinue(payload: payload);
          },
        );

        final readEvents = <String>[];
        final readHook = HiHook<dynamic, dynamic>(
          uid: 'test:read-log',
          events: ['read'],
          handler: (payload, ctx) {
            readEvents.add('read:${payload.key}');
            return HiContinue(payload: payload);
          },
        );

        await initHiveCore(configs: [
          HiveConfig(
            env: 'test',
            boxCollectionName: generateCollectionName(),
            withMeta: true,
            hooks: [readHook],
            metaHooks: [ttlHook],
          ),
        ]);

        final hive = await HHive.create('test');

        // Store with expired meta
        await hive.store.put('key1', 'value1');
        await hive.store.putMeta('key1', {'expired': true});

        // get() should return null due to TTL check
        final result = await hive.get('key1');

        expect(result, isNull);
        // 'read' event should NOT have been emitted (early exit)
        expect(readEvents, isEmpty);
        // Data should be deleted
        expect(await hive.store.get('key1'), isNull);
        expect(await hive.store.getMeta('key1'), isNull);
      });

      test('readMeta HiBreak causes early exit with return value', () async {
        final cacheHook = HiHook<dynamic, dynamic>(
          uid: 'test:cache',
          events: ['readMeta'],
          handler: (payload, ctx) {
            final meta = payload.value as Map<String, dynamic>?;
            if (meta != null && meta['cached'] != null) {
              return HiBreak<dynamic>(returnValue: meta['cached']);
            }
            return HiContinue(payload: payload);
          },
        );

        final readEvents = <String>[];
        final readHook = HiHook<dynamic, dynamic>(
          uid: 'test:read-log',
          events: ['read'],
          handler: (payload, ctx) {
            readEvents.add('read:${payload.key}');
            return HiContinue(payload: payload);
          },
        );

        await initHiveCore(configs: [
          HiveConfig(
            env: 'test',
            boxCollectionName: generateCollectionName(),
            withMeta: true,
            hooks: [readHook],
            metaHooks: [cacheHook],
          ),
        ]);

        final hive = await HHive.create('test');

        // Store with cached value in meta
        await hive.store.put('key1', 'actual-value');
        await hive.store.putMeta('key1', {'cached': 'cached-value'});

        // get() should return cached value from meta
        final result = await hive.get('key1');

        expect(result, 'cached-value');
        // 'read' event should NOT have been emitted (early exit)
        expect(readEvents, isEmpty);
      });
    });

    group('Separate meta engine', () {
      test('metaHooks run on meta events, hooks run on value events', () async {
        final valueEvents = <String>[];
        final metaEvents = <String>[];

        final valueHook = HiHook<dynamic, dynamic>(
          uid: 'test:value',
          events: ['read', 'write', 'delete', 'clear'],
          handler: (payload, ctx) {
            valueEvents.add(payload.key ?? 'null');
            return HiContinue(payload: payload);
          },
        );

        final metaHook = HiHook<dynamic, dynamic>(
          uid: 'test:meta',
          events: ['readMeta', 'writeMeta', 'deleteMeta', 'clearMeta'],
          handler: (payload, ctx) {
            metaEvents.add(payload.key ?? 'null');
            return HiContinue(payload: payload);
          },
        );

        await initHiveCore(configs: [
          HiveConfig(
            env: 'test',
            boxCollectionName: generateCollectionName(),
            withMeta: true,
            hooks: [valueHook],
            metaHooks: [metaHook],
          ),
        ]);

        final hive = await HHive.create('test');

        await hive.put('key1', 'value1', meta: {'ttl': 3600});
        await hive.get('key1');
        await hive.delete('key1');

        // Value hooks triggered
        expect(valueEvents, ['key1', 'key1', 'key1']); // write, read, delete

        // Meta hooks triggered separately
        expect(metaEvents, ['key1', 'key1', 'key1']); // writeMeta, readMeta, deleteMeta
      });

      test('hooks list does not receive meta events', () async {
        final allEvents = <String>[];

        final catchAllHook = HiHook<dynamic, dynamic>(
          uid: 'test:catch-all',
          events: ['read', 'write', 'delete', 'clear', 'readMeta', 'writeMeta'],
          handler: (payload, ctx) {
            allEvents.add('event');
            return HiContinue(payload: payload);
          },
        );

        await initHiveCore(configs: [
          HiveConfig(
            env: 'test',
            boxCollectionName: generateCollectionName(),
            withMeta: true,
            hooks: [catchAllHook], // Only in hooks, not metaHooks
          ),
        ]);

        final hive = await HHive.create('test');

        await hive.put('key1', 'value1', meta: {'ttl': 3600});

        // hooks should only see value events (write), not meta events
        // Even though hook registers for 'writeMeta', it's in hooks list not metaHooks
        expect(allEvents.length, 1); // Only 'write'
      });
    });
  });
}
