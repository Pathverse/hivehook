@TestOn('vm')
library;

import 'package:hivehook/hivehook.dart';
import 'package:test/test.dart';

import '../common/test_helpers.dart';

void main() {
  group('HBoxStore', () {
    setUp(() async {
      await resetHiveState();
    });

    tearDown(() async {
      await resetHiveState();
    });

    group('JSON mode', () {
      test('put and get string value', () async {
        await initHiveCore(configs: [
          HiveConfig(
            env: 'test',
            boxCollectionName: generateCollectionName(),
          ),
        ]);

        final store = await HHiveCore.getStore('test');

        await store.put('key1', 'hello world');
        final result = await store.get('key1');

        expect(result, 'hello world');
      });

      test('put and get map value', () async {
        await initHiveCore(configs: [
          HiveConfig(
            env: 'test',
            boxCollectionName: generateCollectionName(),
          ),
        ]);

        final store = await HHiveCore.getStore('test');

        await store.put('user', {'name': 'Alice', 'age': 30});
        final result = await store.get('user');

        expect(result, {'name': 'Alice', 'age': 30});
      });

      test('put and get list value', () async {
        await initHiveCore(configs: [
          HiveConfig(
            env: 'test',
            boxCollectionName: generateCollectionName(),
          ),
        ]);

        final store = await HHiveCore.getStore('test');

        await store.put('tags', ['flutter', 'dart', 'hive']);
        final result = await store.get('tags');

        expect(result, ['flutter', 'dart', 'hive']);
      });

      test('put and get nested structure', () async {
        await initHiveCore(configs: [
          HiveConfig(
            env: 'test',
            boxCollectionName: generateCollectionName(),
          ),
        ]);

        final store = await HHiveCore.getStore('test');

        final nested = {
          'users': [
            {'id': 1, 'name': 'Alice'},
            {'id': 2, 'name': 'Bob'},
          ],
          'meta': {
            'version': '1.0',
            'count': 2,
          },
        };

        await store.put('data', nested);
        final result = await store.get('data');

        expect(result, nested);
      });

      test('get returns null for non-existent key', () async {
        await initHiveCore(configs: [
          HiveConfig(
            env: 'test',
            boxCollectionName: generateCollectionName(),
          ),
        ]);

        final store = await HHiveCore.getStore('test');
        final result = await store.get('non-existent');

        expect(result, isNull);
      });

      test('delete removes value', () async {
        await initHiveCore(configs: [
          HiveConfig(
            env: 'test',
            boxCollectionName: generateCollectionName(),
          ),
        ]);

        final store = await HHiveCore.getStore('test');

        await store.put('key1', 'value1');
        expect(await store.get('key1'), 'value1');

        await store.delete('key1');
        expect(await store.get('key1'), isNull);
      });

      test('clear removes all values', () async {
        await initHiveCore(configs: [
          HiveConfig(
            env: 'test',
            boxCollectionName: generateCollectionName(),
          ),
        ]);

        final store = await HHiveCore.getStore('test');

        await store.put('key1', 'value1');
        await store.put('key2', 'value2');
        await store.put('key3', 'value3');

        await store.clear();

        expect(await store.get('key1'), isNull);
        expect(await store.get('key2'), isNull);
        expect(await store.get('key3'), isNull);
      });

      test('keys returns all keys', () async {
        await initHiveCore(configs: [
          HiveConfig(
            env: 'test',
            boxCollectionName: generateCollectionName(),
          ),
        ]);

        final store = await HHiveCore.getStore('test');

        await store.put('key1', 'value1');
        await store.put('key2', 'value2');
        await store.put('key3', 'value3');

        final keys = await store.keys().toList();

        expect(keys, containsAll(['key1', 'key2', 'key3']));
        expect(keys.length, 3);
      });

      test('values returns all values', () async {
        await initHiveCore(configs: [
          HiveConfig(
            env: 'test',
            boxCollectionName: generateCollectionName(),
          ),
        ]);

        final store = await HHiveCore.getStore('test');

        await store.put('key1', 'a');
        await store.put('key2', 'b');
        await store.put('key3', 'c');

        final values = await store.values().toList();

        expect(values, containsAll(['a', 'b', 'c']));
        expect(values.length, 3);
      });

      test('entries returns all entries', () async {
        await initHiveCore(configs: [
          HiveConfig(
            env: 'test',
            boxCollectionName: generateCollectionName(),
          ),
        ]);

        final store = await HHiveCore.getStore('test');

        await store.put('key1', 'a');
        await store.put('key2', 'b');

        final entries = await store.entries().toList();

        expect(entries.length, 2);
        expect(entries.map((e) => e.key), containsAll(['key1', 'key2']));
        expect(entries.map((e) => e.value), containsAll(['a', 'b']));
      });
    });

    group('Metadata', () {
      test('supports meta when withMeta is true', () async {
        await initHiveCore(configs: [
          HiveConfig(
            env: 'test',
            boxCollectionName: generateCollectionName(),
            withMeta: true,
          ),
        ]);

        final store = await HHiveCore.getStore('test');

        expect(store.supportsMeta, isTrue);
      });

      test('does not support meta when withMeta is false', () async {
        await initHiveCore(configs: [
          HiveConfig(
            env: 'test',
            boxCollectionName: generateCollectionName(),
            withMeta: false,
          ),
        ]);

        final store = await HHiveCore.getStore('test');

        expect(store.supportsMeta, isFalse);
      });

      test('put and get metadata', () async {
        await initHiveCore(configs: [
          HiveConfig(
            env: 'test',
            boxCollectionName: generateCollectionName(),
            withMeta: true,
          ),
        ]);

        final store = await HHiveCore.getStore('test');

        await store.putMeta('key1', {'ttl': 3600, 'created': 12345});
        final meta = await store.getMeta('key1');

        expect(meta, {'ttl': 3600, 'created': 12345});
      });

      test('delete metadata', () async {
        await initHiveCore(configs: [
          HiveConfig(
            env: 'test',
            boxCollectionName: generateCollectionName(),
            withMeta: true,
          ),
        ]);

        final store = await HHiveCore.getStore('test');

        await store.putMeta('key1', {'ttl': 3600});
        expect(await store.getMeta('key1'), isNotNull);

        await store.deleteMeta('key1');
        expect(await store.getMeta('key1'), isNull);
      });

      test('clearMeta clears only this env metadata', () async {
        final collName = generateCollectionName();
        
        await initHiveCore(configs: [
          HiveConfig(
            env: 'env1',
            boxCollectionName: collName,
            withMeta: true,
          ),
          HiveConfig(
            env: 'env2',
            boxCollectionName: collName,
            withMeta: true,
          ),
        ]);

        final store1 = await HHiveCore.getStore('env1');
        final store2 = await HHiveCore.getStore('env2');

        await store1.putMeta('key1', {'from': 'env1'});
        await store2.putMeta('key1', {'from': 'env2'});

        await store1.clearMeta();

        expect(await store1.getMeta('key1'), isNull);
        expect(await store2.getMeta('key1'), {'from': 'env2'}); // Preserved
      });
    });

    group('Primitives', () {
      test('stores null', () async {
        await initHiveCore(configs: [
          HiveConfig(
            env: 'test',
            boxCollectionName: generateCollectionName(),
          ),
        ]);

        final store = await HHiveCore.getStore('test');

        await store.put('key1', null);
        final result = await store.get('key1');

        expect(result, isNull);
      });

      test('stores integers', () async {
        await initHiveCore(configs: [
          HiveConfig(
            env: 'test',
            boxCollectionName: generateCollectionName(),
          ),
        ]);

        final store = await HHiveCore.getStore('test');

        await store.put('int', 42);
        await store.put('negative', -123);
        await store.put('zero', 0);

        expect(await store.get('int'), 42);
        expect(await store.get('negative'), -123);
        expect(await store.get('zero'), 0);
      });

      test('stores doubles', () async {
        await initHiveCore(configs: [
          HiveConfig(
            env: 'test',
            boxCollectionName: generateCollectionName(),
          ),
        ]);

        final store = await HHiveCore.getStore('test');

        await store.put('pi', 3.14159);
        expect(await store.get('pi'), 3.14159);
      });

      test('stores booleans', () async {
        await initHiveCore(configs: [
          HiveConfig(
            env: 'test',
            boxCollectionName: generateCollectionName(),
          ),
        ]);

        final store = await HHiveCore.getStore('test');

        await store.put('yes', true);
        await store.put('no', false);

        expect(await store.get('yes'), true);
        expect(await store.get('no'), false);
      });
    });
  });
}

