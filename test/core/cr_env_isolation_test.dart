@TestOn('vm')
library;

import 'package:hivehook/hivehook.dart';
import 'package:test/test.dart';

import '../common/test_helpers.dart';

/// Tests for env uniqueness and boxName isolation.
///
/// Design:
/// - env is unique (register once only, throws on duplicate)
/// - boxName defaults to env, but can be customized
/// - Multiple envs can share the same boxName (keys prefixed with {env}::)
/// - Keys are transparent to users (prefix stripped on read)
/// - clear() only clears keys for that env
void main() {
  group('Env Uniqueness', () {
    setUp(() async {
      await resetHiveState();
    });

    tearDown(() async {
      await resetHiveState();
    });

    test('register throws on duplicate env', () async {
      HHiveCore.register(HiveConfig(
        env: 'users',
        boxCollectionName: generateCollectionName(),
      ));

      expect(
        () => HHiveCore.register(HiveConfig(
          env: 'users',
          boxCollectionName: generateCollectionName(),
        )),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('already registered'),
        )),
      );
    });

    test('different envs can be registered', () async {
      final collectionName = generateCollectionName();
      
      HHiveCore.register(HiveConfig(
        env: 'env1',
        boxCollectionName: collectionName,
      ));
      HHiveCore.register(HiveConfig(
        env: 'env2',
        boxCollectionName: collectionName,
      ));

      expect(HHiveCore.configs.length, 2);
    });

    test('reset allows re-registration of same env', () async {
      HHiveCore.register(HiveConfig(
        env: 'users',
        boxCollectionName: generateCollectionName(),
      ));

      await HHiveCore.reset();

      // Should not throw after reset
      HHiveCore.register(HiveConfig(
        env: 'users',
        boxCollectionName: generateCollectionName(),
      ));

      expect(HHiveCore.configs.containsKey('users'), isTrue);
    });
  });

  group('BoxName Configuration', () {
    setUp(() async {
      await resetHiveState();
    });

    tearDown(() async {
      await resetHiveState();
    });

    test('boxName defaults to env', () async {
      final config = HiveConfig(
        env: 'users',
        boxCollectionName: generateCollectionName(),
      );

      expect(config.boxName, 'users');
    });

    test('boxName can be customized', () async {
      final config = HiveConfig(
        env: 'users_v1',
        boxName: 'users',
        boxCollectionName: generateCollectionName(),
      );

      expect(config.boxName, 'users');
      expect(config.env, 'users_v1');
    });
  });

  group('Env Key Isolation', () {
    setUp(() async {
      await resetHiveState();
    });

    tearDown(() async {
      await resetHiveState();
    });

    test('keys are prefixed with env internally', () async {
      final collectionName = generateCollectionName();
      
      await initHiveCore(configs: [
        HiveConfig(
          env: 'env1',
          boxName: 'shared',
          boxCollectionName: collectionName,
        ),
        HiveConfig(
          env: 'env2',
          boxName: 'shared',
          boxCollectionName: collectionName,
        ),
      ]);

      final hive1 = await HHive.create('env1');
      final hive2 = await HHive.create('env2');

      // Both write to same box but with different prefixes
      await hive1.put('key', 'value1');
      await hive2.put('key', 'value2');

      // Each env sees its own value
      expect(await hive1.get('key'), 'value1');
      expect(await hive2.get('key'), 'value2');
    });

    test('keys returns only this env keys (prefix stripped)', () async {
      final collectionName = generateCollectionName();
      
      await initHiveCore(configs: [
        HiveConfig(
          env: 'env1',
          boxName: 'shared',
          boxCollectionName: collectionName,
        ),
        HiveConfig(
          env: 'env2',
          boxName: 'shared',
          boxCollectionName: collectionName,
        ),
      ]);

      final hive1 = await HHive.create('env1');
      final hive2 = await HHive.create('env2');

      await hive1.put('a', 'v1');
      await hive1.put('b', 'v1');
      await hive2.put('x', 'v2');
      await hive2.put('y', 'v2');

      final keys1 = await hive1.keys().toList();
      final keys2 = await hive2.keys().toList();

      // Each env only sees its own keys (without prefix)
      expect(keys1, unorderedEquals(['a', 'b']));
      expect(keys2, unorderedEquals(['x', 'y']));
    });

    test('values returns only this env values', () async {
      final collectionName = generateCollectionName();
      
      await initHiveCore(configs: [
        HiveConfig(
          env: 'env1',
          boxName: 'shared',
          boxCollectionName: collectionName,
        ),
        HiveConfig(
          env: 'env2',
          boxName: 'shared',
          boxCollectionName: collectionName,
        ),
      ]);

      final hive1 = await HHive.create('env1');
      final hive2 = await HHive.create('env2');

      await hive1.put('a', 100);
      await hive1.put('b', 200);
      await hive2.put('x', 999);

      final values1 = await hive1.values().toList();
      final values2 = await hive2.values().toList();

      expect(values1, unorderedEquals([100, 200]));
      expect(values2, [999]);
    });

    test('entries returns only this env entries (key prefix stripped)', () async {
      final collectionName = generateCollectionName();
      
      await initHiveCore(configs: [
        HiveConfig(
          env: 'env1',
          boxName: 'shared',
          boxCollectionName: collectionName,
        ),
        HiveConfig(
          env: 'env2',
          boxName: 'shared',
          boxCollectionName: collectionName,
        ),
      ]);

      final hive1 = await HHive.create('env1');
      final hive2 = await HHive.create('env2');

      await hive1.put('key1', 'val1');
      await hive2.put('key2', 'val2');

      final entries1 = await hive1.entries().toList();
      final entries2 = await hive2.entries().toList();

      expect(entries1.length, 1);
      expect(entries1[0].key, 'key1');
      expect(entries1[0].value, 'val1');

      expect(entries2.length, 1);
      expect(entries2[0].key, 'key2');
      expect(entries2[0].value, 'val2');
    });

    test('clear only clears this env keys', () async {
      final collectionName = generateCollectionName();
      
      await initHiveCore(configs: [
        HiveConfig(
          env: 'env1',
          boxName: 'shared',
          boxCollectionName: collectionName,
        ),
        HiveConfig(
          env: 'env2',
          boxName: 'shared',
          boxCollectionName: collectionName,
        ),
      ]);

      final hive1 = await HHive.create('env1');
      final hive2 = await HHive.create('env2');

      await hive1.put('a', 'v1');
      await hive1.put('b', 'v1');
      await hive2.put('x', 'v2');
      await hive2.put('y', 'v2');

      // Clear only env1
      await hive1.clear();

      // env1 should be empty
      expect(await hive1.keys().toList(), isEmpty);
      expect(await hive1.get('a'), isNull);

      // env2 should still have its data
      final keys2 = await hive2.keys().toList();
      expect(keys2, unorderedEquals(['x', 'y']));
      expect(await hive2.get('x'), 'v2');
    });

    test('delete only deletes from this env', () async {
      final collectionName = generateCollectionName();
      
      await initHiveCore(configs: [
        HiveConfig(
          env: 'env1',
          boxName: 'shared',
          boxCollectionName: collectionName,
        ),
        HiveConfig(
          env: 'env2',
          boxName: 'shared',
          boxCollectionName: collectionName,
        ),
      ]);

      final hive1 = await HHive.create('env1');
      final hive2 = await HHive.create('env2');

      // Both envs have 'key'
      await hive1.put('key', 'val1');
      await hive2.put('key', 'val2');

      // Delete from env1
      await hive1.delete('key');

      // env1 key gone
      expect(await hive1.get('key'), isNull);

      // env2 key still exists
      expect(await hive2.get('key'), 'val2');
    });
  });

  group('Separate BoxName (no sharing)', () {
    setUp(() async {
      await resetHiveState();
    });

    tearDown(() async {
      await resetHiveState();
    });

    test('envs with different boxNames are completely isolated', () async {
      final collectionName = generateCollectionName();
      
      await initHiveCore(configs: [
        HiveConfig(
          env: 'env1',
          boxName: 'box1',
          boxCollectionName: collectionName,
        ),
        HiveConfig(
          env: 'env2',
          boxName: 'box2',
          boxCollectionName: collectionName,
        ),
      ]);

      final hive1 = await HHive.create('env1');
      final hive2 = await HHive.create('env2');

      await hive1.put('key', 'value1');
      await hive2.put('key', 'value2');

      expect(await hive1.get('key'), 'value1');
      expect(await hive2.get('key'), 'value2');

      // Clear one doesn't affect other
      await hive1.clear();
      expect(await hive1.get('key'), isNull);
      expect(await hive2.get('key'), 'value2');
    });
  });

  group('Metadata Isolation', () {
    setUp(() async {
      await resetHiveState();
    });

    tearDown(() async {
      await resetHiveState();
    });

    test('metadata is isolated per env', () async {
      final collectionName = generateCollectionName();
      
      await initHiveCore(configs: [
        HiveConfig(
          env: 'env1',
          boxName: 'shared',
          boxCollectionName: collectionName,
          withMeta: true,
        ),
        HiveConfig(
          env: 'env2',
          boxName: 'shared',
          boxCollectionName: collectionName,
          withMeta: true,
        ),
      ]);

      final store1 = await HHiveCore.getStore('env1');
      final store2 = await HHiveCore.getStore('env2');

      await store1.put('key', 'val1');
      await store1.putMeta('key', {'ttl': 1000});

      await store2.put('key', 'val2');
      await store2.putMeta('key', {'ttl': 2000});

      // Metadata is isolated
      expect(await store1.getMeta('key'), {'ttl': 1000});
      expect(await store2.getMeta('key'), {'ttl': 2000});
    });

    test('clearMeta only clears this env metadata', () async {
      final collectionName = generateCollectionName();
      
      await initHiveCore(configs: [
        HiveConfig(
          env: 'env1',
          boxName: 'shared',
          boxCollectionName: collectionName,
          withMeta: true,
        ),
        HiveConfig(
          env: 'env2',
          boxName: 'shared',
          boxCollectionName: collectionName,
          withMeta: true,
        ),
      ]);

      final store1 = await HHiveCore.getStore('env1');
      final store2 = await HHiveCore.getStore('env2');

      await store1.putMeta('key', {'data': 1});
      await store2.putMeta('key', {'data': 2});

      await store1.clearMeta();

      expect(await store1.getMeta('key'), isNull);
      expect(await store2.getMeta('key'), {'data': 2});
    });
  });
}
