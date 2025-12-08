import 'package:test/test.dart';
import 'package:hivehook/core/hive.dart';

void main() {
  group('Basic CRUD Operations', () {
    test('should put and get a value', () async {
      final hive = HHive(env: 'crud_put_get');

      await hive.put('key1', 'value1');
      final result = await hive.get('key1');

      expect(result, equals('value1'));
    });

    test('should return null for non-existent key', () async {
      final hive = HHive(env: 'crud_null');
      final result = await hive.get('nonexistent');

      expect(result, isNull);
    });

    test('should delete a value', () async {
      final hive = HHive(env: 'crud_delete');

      await hive.put('key1', 'value1');
      expect(await hive.get('key1'), equals('value1'));

      await hive.delete('key1');
      expect(await hive.get('key1'), isNull);
    });

    test('should pop a value (get then delete)', () async {
      final hive = HHive(env: 'crud_pop');

      await hive.put('key1', 'value1');
      final poppedValue = await hive.pop('key1');

      expect(poppedValue, equals('value1'));
      expect(await hive.get('key1'), isNull);
    });

    test('should clear all values', () async {
      final hive = HHive(env: 'crud_clear');

      await hive.put('key1', 'value1');
      await hive.put('key2', 'value2');
      await hive.put('key3', 'value3');

      await hive.clear();

      expect(await hive.get('key1'), isNull);
      expect(await hive.get('key2'), isNull);
      expect(await hive.get('key3'), isNull);
    });

    test('should update existing value', () async {
      final hive = HHive(env: 'crud_update');

      await hive.put('key1', 'value1');
      expect(await hive.get('key1'), equals('value1'));

      await hive.put('key1', 'value2');
      expect(await hive.get('key1'), equals('value2'));
    });

    test('should handle multiple keys independently', () async {
      final hive = HHive(env: 'crud_test');

      await hive.put('key1', 'value1');
      await hive.put('key2', 'value2');
      await hive.put('key3', 'value3');

      expect(await hive.get('key1'), equals('value1'));
      expect(await hive.get('key2'), equals('value2'));
      expect(await hive.get('key3'), equals('value3'));

      await hive.delete('key2');

      expect(await hive.get('key1'), equals('value1'));
      expect(await hive.get('key2'), isNull);
      expect(await hive.get('key3'), equals('value3'));
    });

    test('should handle different value types', () async {
      final hive = HHive(env: 'crud_test');

      await hive.put('string', 'text');
      await hive.put('number', 123);
      await hive.put('bool', true);

      expect(await hive.get('string'), equals('text'));
      expect(
        await hive.get('number'),
        equals(123),
      ); // JSON preserves number type
      expect(await hive.get('bool'), equals(true)); // JSON preserves bool type
    });
  });

  group('HHive Singleton Pattern', () {
    test('should return same instance for same env', () async {
      final hive1 = HHive(env: 'crud_test');
      final hive2 = HHive(env: 'crud_test');

      expect(identical(hive1, hive2), isTrue);
    });

    test('should throw error if env does not exist', () {
      expect(() => HHive(env: 'nonexistent_env'), throwsArgumentError);
    });

    test('should throw error if neither config nor env provided', () {
      expect(() => HHive(), throwsArgumentError);
    });
  });
}
