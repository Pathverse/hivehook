import 'package:test/test.dart';
import 'package:hivehook/core/hive.dart';
import 'package:hivehook/core/payload.dart';

void main() {
  group('ifNotCached Operations', () {
    test('should compute and cache value on first call', () async {
      final hive = HHive(env: 'if_not_cached_first');
      int computeCount = 0;

      final result = await hive.ifNotCached('key1', () async {
        computeCount++;
        return 'computed_value';
      });

      expect(result, equals('computed_value'));
      expect(computeCount, equals(1));

      // Verify value was cached
      final cached = await hive.get('key1');
      expect(cached, equals('computed_value'));
    });

    test('should return cached value without recomputing', () async {
      final hive = HHive(env: 'if_not_cached_cached');
      int computeCount = 0;

      // First call - should compute
      final result1 = await hive.ifNotCached('key1', () async {
        computeCount++;
        return 'first_value';
      });

      expect(result1, equals('first_value'));
      expect(computeCount, equals(1));

      // Second call - should use cached value
      final result2 = await hive.ifNotCached('key1', () async {
        computeCount++;
        return 'second_value';
      });

      expect(result2, equals('first_value')); // Returns cached, not new
      expect(computeCount, equals(1)); // Compute function NOT called again
    });

    test('should compute different values for different keys', () async {
      final hive = HHive(env: 'if_not_cached_keys');

      final result1 = await hive.ifNotCached('key1', () async => 'value1');
      final result2 = await hive.ifNotCached('key2', () async => 'value2');

      expect(result1, equals('value1'));
      expect(result2, equals('value2'));
    });

    test('should work with async computations', () async {
      final hive = HHive(env: 'if_not_cached_async');

      final result = await hive.ifNotCached('async_key', () async {
        await Future.delayed(Duration(milliseconds: 10));
        return 'async_result';
      });

      expect(result, equals('async_result'));
    });

    test('should support metadata', () async {
      final hive = HHive(env: 'if_not_cached_meta');

      final result = await hive.ifNotCached(
        'meta_key',
        () async => 'value_with_meta',
        meta: {'timestamp': '2025-11-28', 'source': 'test'},
      );

      expect(result, equals('value_with_meta'));

      // Verify metadata was stored
      final metadata = await hive.getMeta('meta_key');
      expect(metadata, isNotNull);
      expect(metadata!['timestamp'], equals('2025-11-28'));
      expect(metadata['source'], equals('test'));
    });

    test('should handle complex value types', () async {
      final hive = HHive(env: 'if_not_cached_complex');

      final complexValue = {
        'name': 'test',
        'count': 42,
        'active': true,
        'nested': {'key': 'value'},
      };

      final result = await hive.ifNotCached('complex_key', () async {
        return complexValue;
      });

      expect(result, equals(complexValue));

      // Verify cached correctly
      final cached = await hive.get('complex_key');
      expect(cached, equals(complexValue));
    });

    test('should handle null as cached value', () async {
      final hive = HHive(env: 'if_not_cached_null');
      int computeCount = 0;

      // Pre-populate with null
      await hive.put('null_key', null);

      // ifNotCached should treat null as "not cached" and recompute
      final result = await hive.ifNotCached('null_key', () async {
        computeCount++;
        return 'computed_after_null';
      });

      // This behavior depends on implementation - null means "not cached"
      expect(result, equals('computed_after_null'));
      expect(computeCount, equals(1));
    });

    test('staticIfNotCached should work with payload', () async {
      final hive = HHive(env: 'if_not_cached_static');
      int computeCount = 0;

      final result = await HHive.ifNotCachedStatic(
        HHPayload(env: 'if_not_cached_static', key: 'static_key'),
        () async {
          computeCount++;
          return 'static_value';
        },
      );

      expect(result, equals('static_value'));
      expect(computeCount, equals(1));

      // Verify it was cached
      final cached = await hive.get('static_key');
      expect(cached, equals('static_value'));

      // Second call should use cache
      final result2 = await HHive.ifNotCachedStatic(
        HHPayload(env: 'if_not_cached_static', key: 'static_key'),
        () async {
          computeCount++;
          return 'different_value';
        },
      );

      expect(result2, equals('static_value'));
      expect(computeCount, equals(1)); // Not called again
    });

    test('should handle compute function errors', () async {
      final hive = HHive(env: 'if_not_cached_error');

      expect(
        () => hive.ifNotCached('error_key', () async {
          throw Exception('Computation failed');
        }),
        throwsException,
      );

      // Key should not be cached on error
      final cached = await hive.get('error_key');
      expect(cached, isNull);
    });
  });
}
