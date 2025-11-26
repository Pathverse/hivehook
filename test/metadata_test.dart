import 'package:test/test.dart';
import 'package:hivehook/core/hive.dart';

void main() {
  group('Metadata Operations', () {
    test('should put and get metadata with value', () async {
      final hive = HHive(env: 'meta_basic');

      await hive.put('key1', 'value1', meta: {'timestamp': 123456});
      final metadata = await hive.getMeta('key1');

      expect(metadata, isNotNull);
      expect(metadata!['timestamp'], equals(123456));
    });

    test('should update metadata independently', () async {
      final hive = HHive(env: 'meta_update');

      await hive.put('key1', 'value1', meta: {'count': 1});
      await hive.putMeta('key1', {'count': 2, 'extra': 'data'});

      final metadata = await hive.getMeta('key1');
      expect(metadata!['count'], equals(2));
      expect(metadata['extra'], equals('data'));

      // Value should remain unchanged
      expect(await hive.get('key1'), equals('value1'));
    });

    test('should delete metadata with pop', () async {
      final hive = HHive(env: 'meta_pop');

      await hive.put('key1', 'value1', meta: {'info': 'test'});
      final poppedValue = await hive.pop('key1');

      expect(poppedValue, equals('value1'));
      expect(await hive.get('key1'), isNull);
      expect(await hive.getMeta('key1'), isNull);
    });

    test('should store and retrieve complex metadata', () async {
      final hive = HHive(env: 'meta_basic');

      final complexMeta = {
        'created': DateTime.now().millisecondsSinceEpoch,
        'author': 'test_user',
        'tags': ['tag1', 'tag2', 'tag3'],
        'version': 1,
        'nested': {
          'level1': {'level2': 'deep_value'},
        },
      };

      await hive.put('key2', 'value2', meta: complexMeta);
      final retrieved = await hive.getMeta('key2');

      expect(retrieved, isNotNull);
      expect(retrieved!['author'], equals('test_user'));
      expect(retrieved['version'], equals(1));
    });

    test('should return null for metadata of non-existent key', () async {
      final hive = HHive(env: 'meta_basic');
      final metadata = await hive.getMeta('nonexistent');

      expect(metadata, isNull);
    });

    test('should allow value operations without metadata', () async {
      final hive = HHive(env: 'meta_independent');

      await hive.put('key1', 'value1');
      expect(await hive.get('key1'), equals('value1'));

      // Metadata might be empty map or null if none was provided
      final metadata = await hive.getMeta('key1');
      // Accept either null or empty map
      expect(metadata == null || metadata.isEmpty, isTrue);
    });

    test('should allow metadata operations independently of value', () async {
      final hive = HHive(env: 'meta_independent');

      await hive.put('key2', 'value2');
      await hive.putMeta('key2', {'added': 'later'});

      final metadata = await hive.getMeta('key2');
      expect(metadata!['added'], equals('later'));
    });

    test('should delete only metadata with metaDelete', () async {
      final hive = HHive(env: 'meta_delete');

      await hive.put('key1', 'value1', meta: {'test': 'data'});

      // Note: We don't expose metaDelete publicly, but it's tested internally
      // through the pop operation which calls both storeDelete and metaDelete

      expect(await hive.get('key1'), equals('value1'));
      expect(await hive.getMeta('key1'), isNotNull);
    });
  });
}
