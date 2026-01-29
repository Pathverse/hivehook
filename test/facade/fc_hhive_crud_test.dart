@TestOn('vm')
library;

import 'package:hivehook/hivehook.dart';
import 'package:test/test.dart';

import '../common/test_helpers.dart';

void main() {
  group('HHive Facade', () {
    setUp(() async {
      await resetHiveState();
    });

    tearDown(() async {
      await resetHiveState();
    });

    group('CRUD operations', () {
      test('put and get string via facade', () async {
        await initHiveCore(configs: [
          HiveConfig(
            env: 'test',
            boxCollectionName: generateCollectionName(),
          ),
        ]);

        final hive = await HHive.create('test');

        await hive.put('greeting', 'hello');
        final result = await hive.get('greeting');

        expect(result, 'hello');
      });

      test('put and get map via facade', () async {
        await initHiveCore(configs: [
          HiveConfig(
            env: 'test',
            boxCollectionName: generateCollectionName(),
          ),
        ]);

        final hive = await HHive.create('test');

        await hive.put('user', {'name': 'Bob', 'age': 25});
        final result = await hive.get('user');

        expect(result, {'name': 'Bob', 'age': 25});
      });

      test('delete key via facade', () async {
        await initHiveCore(configs: [
          HiveConfig(
            env: 'test',
            boxCollectionName: generateCollectionName(),
          ),
        ]);

        final hive = await HHive.create('test');

        await hive.put('temp', 'data');
        expect(await hive.get('temp'), 'data');

        await hive.delete('temp');
        expect(await hive.get('temp'), isNull);
      });

      test('check key existence via get', () async {
        await initHiveCore(configs: [
          HiveConfig(
            env: 'test',
            boxCollectionName: generateCollectionName(),
          ),
        ]);

        final hive = await HHive.create('test');

        // Non-existent key returns null
        expect(await hive.get('missing'), isNull);
        
        // After putting, get returns the value
        await hive.put('exists', 'value');
        expect(await hive.get('exists'), 'value');
      });

      test('clear all keys via facade', () async {
        await initHiveCore(configs: [
          HiveConfig(
            env: 'test',
            boxCollectionName: generateCollectionName(),
          ),
        ]);

        final hive = await HHive.create('test');

        await hive.put('key1', 'value1');
        await hive.put('key2', 'value2');
        await hive.put('key3', 'value3');

        await hive.clear();

        expect(await hive.get('key1'), isNull);
        expect(await hive.get('key2'), isNull);
        expect(await hive.get('key3'), isNull);
      });
    });

    group('Singleton per env', () {
      test('HHive returns same instance for same env', () async {
        await initHiveCore(configs: [
          HiveConfig(
            env: 'test',
            boxCollectionName: generateCollectionName(),
          ),
        ]);

        final hive1 = await HHive.create('test');
        final hive2 = await HHive.create('test');

        expect(identical(hive1, hive2), isTrue);
      });

      test('HHive returns different instances for different envs', () async {
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

        expect(identical(hive1, hive2), isFalse);
      });

      test('data is isolated between environments', () async {
        await initHiveCore(configs: [
          HiveConfig(
            env: 'env_a',
            boxCollectionName: generateCollectionName(),
          ),
          HiveConfig(
            env: 'env_b',
            boxCollectionName: generateCollectionName(),
          ),
        ]);

        final hiveA = await HHive.create('env_a');
        final hiveB = await HHive.create('env_b');

        await hiveA.put('key', 'value_a');
        await hiveB.put('key', 'value_b');

        expect(await hiveA.get('key'), 'value_a');
        expect(await hiveB.get('key'), 'value_b');
      });
    });

    group('dispose', () {
      test('dispose single environment', () async {
        await initHiveCore(configs: [
          HiveConfig(
            env: 'disposable',
            boxCollectionName: generateCollectionName(),
          ),
        ]);

        final hive = await HHive.create('disposable');
        await hive.put('key', 'value');

        HHive.dispose('disposable');

        // After dispose, getting a new instance should work
        // (it's a new instance, not cached)
        final hive2 = await HHive.create('disposable');
        expect(identical(hive, hive2), isFalse);
      });

      test('disposeAll clears all instances', () async {
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

        HHive.disposeAll();

        final newHive1 = await HHive.create('env1');
        final newHive2 = await HHive.create('env2');

        expect(identical(hive1, newHive1), isFalse);
        expect(identical(hive2, newHive2), isFalse);
      });
    });

    group('store accessor', () {
      test('facade provides access to underlying store', () async {
        await initHiveCore(configs: [
          HiveConfig(
            env: 'test',
            boxCollectionName: generateCollectionName(),
          ),
        ]);

        final hive = await HHive.create('test');

        expect(hive.store, isA<HBoxStore>());
      });

      test('store operations match facade operations', () async {
        await initHiveCore(configs: [
          HiveConfig(
            env: 'test',
            boxCollectionName: generateCollectionName(),
          ),
        ]);

        final hive = await HHive.create('test');

        // Put via facade
        await hive.put('via_facade', 'facade_value');

        // Get via store
        final result = await hive.store.get('via_facade');

        expect(result, 'facade_value');
      });
    });

    group('primitive types', () {
      test('stores and retrieves int', () async {
        await initHiveCore(configs: [
          HiveConfig(
            env: 'test',
            boxCollectionName: generateCollectionName(),
          ),
        ]);

        final hive = await HHive.create('test');

        await hive.put('int', 42);
        expect(await hive.get('int'), 42);
      });

      test('stores and retrieves double', () async {
        await initHiveCore(configs: [
          HiveConfig(
            env: 'test',
            boxCollectionName: generateCollectionName(),
          ),
        ]);

        final hive = await HHive.create('test');

        await hive.put('double', 3.14159);
        expect(await hive.get('double'), closeTo(3.14159, 0.00001));
      });

      test('stores and retrieves bool', () async {
        await initHiveCore(configs: [
          HiveConfig(
            env: 'test',
            boxCollectionName: generateCollectionName(),
          ),
        ]);

        final hive = await HHive.create('test');

        await hive.put('bool_true', true);
        await hive.put('bool_false', false);

        expect(await hive.get('bool_true'), true);
        expect(await hive.get('bool_false'), false);
      });

      test('stores and retrieves null explicitly', () async {
        await initHiveCore(configs: [
          HiveConfig(
            env: 'test',
            boxCollectionName: generateCollectionName(),
          ),
        ]);

        final hive = await HHive.create('test');

        await hive.put('null_value', null);

        // This should return null
        expect(await hive.get('null_value'), isNull);
        
        // For null values, we need keys() to distinguish from non-existent
        final allKeys = await hive.keys().toList();
        expect(allKeys.contains('null_value'), isTrue);
      });
    });

    group('metadata operations', () {
      test('put and get with metadata', () async {
        await initHiveCore(configs: [
          HiveConfig(
            env: 'test',
            boxCollectionName: generateCollectionName(),
            withMeta: true,
          ),
        ]);

        final hive = await HHive.create('test');

        await hive.put(
          'user',
          {'name': 'Alice'},
          meta: {'createdAt': 1234567890},
        );

        final record = await hive.getWithMeta('user');

        expect(record.value, {'name': 'Alice'});
        expect(record.meta, {'createdAt': 1234567890});
      });
    });
  });
}
