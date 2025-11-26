import 'package:test/test.dart';
import 'package:hivehook/core/config.dart';
import 'package:hivehook/core/hive.dart';
import 'package:hivehook/core/base.dart';
import 'package:hivehook/templates/ttl_plugin.dart';
import 'package:hivehook/templates/lru_plugin.dart';

void main() {
  setUpAll(() async {
    // Register test environments
    HHImmutableConfig(env: 'ttl_test', usesMeta: true);
    HHImmutableConfig(env: 'lru_test', usesMeta: true);

    await HiveBase.initialize();
  });

  group('TTL Plugin', () {
    test('should expire data after TTL', () async {
      final env = 'ttl_test';

      // Create config with TTL plugin (2 second TTL for testing)
      final ttlPlugin = createTTLPlugin(defaultTTLSeconds: 2);
      final config = HHConfig(env: env, usesMeta: true);
      config.installPlugin(ttlPlugin);

      dangerousReplaceConfig(config);
      final hive = HHive(config: HHImmutableConfig.getInstance(env)!);

      // Store value
      await hive.put('test_key', 'test_value');

      // Should exist immediately
      expect(await hive.get('test_key'), equals('test_value'));

      // Wait for expiration
      await Future.delayed(Duration(seconds: 3));

      // Should be expired (returns null)
      expect(await hive.get('test_key'), isNull);
    });

    test('should use custom TTL from metadata', () async {
      final env = 'ttl_test';
      final hive = HHive(config: HHImmutableConfig.getInstance(env)!);

      // Store with 1 second TTL
      await hive.put('short_ttl', 'expires_soon', meta: {'ttl': '1'});

      expect(await hive.get('short_ttl'), equals('expires_soon'));

      await Future.delayed(Duration(milliseconds: 1500));

      expect(await hive.get('short_ttl'), isNull);
    });
  });

  group('LRU Plugin', () {
    test('should evict least recently used item', () async {
      final env = 'lru_test';

      // Create config with LRU plugin (max 3 items)
      final lruPlugin = createLRUPlugin(maxSize: 3);
      final config = HHConfig(env: env, usesMeta: true);
      config.installPlugin(lruPlugin);

      dangerousReplaceConfig(config);
      final hive = HHive(config: HHImmutableConfig.getInstance(env)!);

      // Add 3 items (fills cache)
      await hive.put('key1', 'value1');
      await hive.put('key2', 'value2');
      await hive.put('key3', 'value3');

      // Access key1 to make it recently used
      await hive.get('key1');

      // Add 4th item - should evict key2 (least recently used)
      await hive.put('key4', 'value4');

      expect(await hive.get('key1'), equals('value1')); // Still exists
      expect(await hive.get('key2'), isNull); // Evicted
      expect(await hive.get('key3'), equals('value3')); // Still exists
      expect(await hive.get('key4'), equals('value4')); // New item
    });
  });
}
