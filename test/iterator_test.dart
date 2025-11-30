import 'package:test/test.dart';
import 'package:hivehook/core/base.dart'; // Import HHiveCore for initialization
import 'package:hivehook/core/hive.dart'; // Import HHive for iterator tests
import 'test_configs.dart';

void main() {
  late HHive hive;

  setUpAll(() async {
    // Initialize test environment
    initializeAllTestConfigs();
    await HHiveCore.initialize();

    // Create a test instance of HHive
    hive = HHive(env: 'test_env');

    // Populate with test data
    await hive.put('key1', 'value1');
    await hive.put('key2', 'value2');
    await hive.put('key3', 'value3');
  });

  tearDownAll(() async {
    // Clear test data
    await hive.clear();
  });

  group('Iterator Methods', () {
    test('keys() returns all keys', () async {
      final keys = await hive.keys().toList();
      expect(keys, containsAll(['key1', 'key2', 'key3']));
    });

    test('values() returns all values', () async {
      final values = await hive.values().toList();
      expect(values, containsAll(['value1', 'value2', 'value3']));
    });

    test('entries() returns all entries', () async {
      final entries = await hive.entries().toList();
      expect(entries.length, 3);
      expect(
        entries,
        containsAll([
          predicate(
            (entry) =>
                (entry as MapEntry<String, dynamic>).key == 'key1' &&
                entry.value == 'value1',
          ),
          predicate(
            (entry) =>
                (entry as MapEntry<String, dynamic>).key == 'key2' &&
                entry.value == 'value2',
          ),
          predicate(
            (entry) =>
                (entry as MapEntry<String, dynamic>).key == 'key3' &&
                entry.value == 'value3',
          ),
        ]),
      );
    });
  });
}
