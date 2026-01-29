@TestOn('vm')
library;

import 'package:hivehook/hivehook.dart';
import 'package:test/test.dart';

import '../common/test_helpers.dart';

/// Custom class for testing JSON serialization
class User {
  final String name;
  final int age;
  final DateTime createdAt;

  User({required this.name, required this.age, required this.createdAt});

  Map<String, dynamic> toJson() => {
        'name': name,
        'age': age,
        'createdAt': createdAt.toIso8601String(),
      };

  factory User.fromJson(Map<String, dynamic> json) => User(
        name: json['name'] as String,
        age: json['age'] as int,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  @override
  bool operator ==(Object other) =>
      other is User &&
      other.name == name &&
      other.age == age &&
      other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(name, age, createdAt);
}

void main() {
  group('Custom JSON Encoder/Decoder', () {
    setUp(() async {
      await resetHiveState();
    });

    tearDown(() async {
      await resetHiveState();
    });

    group('Per-config custom encoder', () {
      test('custom encoder serializes DateTime', () async {
        Object? customEncoder(Object? value) {
          if (value is DateTime) {
            return {'__type': 'DateTime', 'value': value.toIso8601String()};
          }
          return value;
        }

        await initHiveCore(configs: [
          HiveConfig(
            env: 'test',
            boxCollectionName: generateCollectionName(),
            jsonEncoder: customEncoder,
          ),
        ]);

        final hive = await HHive.create('test');

        final now = DateTime(2026, 1, 29, 12, 0, 0);
        await hive.put('timestamp', now);

        // Read raw from store to verify encoding
        final rawValue = await hive.store.get('timestamp');

        expect(rawValue, isA<Map>());
        expect((rawValue as Map)['__type'], 'DateTime');
        expect(rawValue['value'], '2026-01-29T12:00:00.000');
      });

      test('custom decoder deserializes DateTime', () async {
        Object? customEncoder(Object? value) {
          if (value is DateTime) {
            return {'__type': 'DateTime', 'value': value.toIso8601String()};
          }
          return value;
        }

        Object? customDecoder(Object? key, Object? value) {
          if (value is Map && value['__type'] == 'DateTime') {
            return DateTime.parse(value['value'] as String);
          }
          return value;
        }

        await initHiveCore(configs: [
          HiveConfig(
            env: 'test',
            boxCollectionName: generateCollectionName(),
            jsonEncoder: customEncoder,
            jsonDecoder: customDecoder,
          ),
        ]);

        final hive = await HHive.create('test');

        final now = DateTime(2026, 1, 29, 12, 0, 0);
        await hive.put('timestamp', now);

        final result = await hive.get('timestamp');

        expect(result, isA<DateTime>());
        expect(result, now);
      });

      test('custom encoder handles User class', () async {
        Object? customEncoder(Object? value) {
          if (value is User) {
            return {'__type': 'User', ...value.toJson()};
          }
          return value;
        }

        Object? customDecoder(Object? key, Object? value) {
          if (value is Map && value['__type'] == 'User') {
            return User.fromJson(value.cast<String, dynamic>());
          }
          return value;
        }

        await initHiveCore(configs: [
          HiveConfig(
            env: 'test',
            boxCollectionName: generateCollectionName(),
            jsonEncoder: customEncoder,
            jsonDecoder: customDecoder,
          ),
        ]);

        final hive = await HHive.create('test');

        final user = User(
          name: 'Alice',
          age: 30,
          createdAt: DateTime(2026, 1, 1),
        );

        await hive.put('user:1', user);
        final result = await hive.get('user:1');

        expect(result, isA<User>());
        expect(result, user);
      });
    });

    group('Global custom encoder/decoder', () {
      test('global encoder applies to all environments', () async {
        Object? globalEncoder(Object? value) {
          if (value is DateTime) {
            return {'__dt': value.millisecondsSinceEpoch};
          }
          return value;
        }

        Object? globalDecoder(Object? key, Object? value) {
          if (value is Map && value.containsKey('__dt')) {
            return DateTime.fromMillisecondsSinceEpoch(value['__dt'] as int);
          }
          return value;
        }

        HHiveCore.globalJsonEncoder = globalEncoder;
        HHiveCore.globalJsonDecoder = globalDecoder;

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

        final time1 = DateTime(2026, 1, 1);
        final time2 = DateTime(2026, 6, 15);

        await hive1.put('time', time1);
        await hive2.put('time', time2);

        expect(await hive1.get('time'), time1);
        expect(await hive2.get('time'), time2);
      });

      test('per-config encoder overrides global', () async {
        Object? globalEncoder(Object? value) {
          if (value is DateTime) {
            return {'__global': value.toIso8601String()};
          }
          return value;
        }

        Object? configEncoder(Object? value) {
          if (value is DateTime) {
            return {'__config': value.millisecondsSinceEpoch};
          }
          return value;
        }

        HHiveCore.globalJsonEncoder = globalEncoder;

        await initHiveCore(configs: [
          HiveConfig(
            env: 'global_env',
            boxCollectionName: generateCollectionName(),
          ),
          HiveConfig(
            env: 'config_env',
            boxCollectionName: generateCollectionName(),
            jsonEncoder: configEncoder,
          ),
        ]);

        final globalHive = await HHive.create('global_env');
        final configHive = await HHive.create('config_env');

        final time = DateTime(2026, 1, 29);

        await globalHive.put('time', time);
        await configHive.put('time', time);

        final globalRaw = await globalHive.store.get('time');
        final configRaw = await configHive.store.get('time');

        // Global env uses global encoder
        expect((globalRaw as Map).containsKey('__global'), isTrue);

        // Config env uses config encoder
        expect((configRaw as Map).containsKey('__config'), isTrue);
      });
    });

    group('Complex nested structures', () {
      test('encoder handles nested custom types', () async {
        Object? customEncoder(Object? value) {
          if (value is DateTime) {
            return {'__type': 'DateTime', 'value': value.toIso8601String()};
          }
          if (value is User) {
            return {'__type': 'User', ...value.toJson()};
          }
          return value;
        }

        Object? customDecoder(Object? key, Object? value) {
          if (value is Map) {
            if (value['__type'] == 'DateTime') {
              return DateTime.parse(value['value'] as String);
            }
            if (value['__type'] == 'User') {
              return User.fromJson(value.cast<String, dynamic>());
            }
          }
          return value;
        }

        await initHiveCore(configs: [
          HiveConfig(
            env: 'test',
            boxCollectionName: generateCollectionName(),
            jsonEncoder: customEncoder,
            jsonDecoder: customDecoder,
          ),
        ]);

        final hive = await HHive.create('test');

        final data = {
          'users': [
            User(name: 'Alice', age: 30, createdAt: DateTime(2026, 1, 1)),
            User(name: 'Bob', age: 25, createdAt: DateTime(2026, 2, 1)),
          ],
          'lastUpdated': DateTime(2026, 1, 29),
          'meta': {
            'version': 1,
            'createdAt': DateTime(2025, 12, 1),
          },
        };

        await hive.put('complex', data);
        final result = await hive.get('complex');

        expect(result, isA<Map>());
        final resultMap = result as Map;

        expect(resultMap['lastUpdated'], DateTime(2026, 1, 29));
        expect(resultMap['meta']['createdAt'], DateTime(2025, 12, 1));

        final users = resultMap['users'] as List;
        expect(users.length, 2);
        expect(users[0], isA<User>());
        expect((users[0] as User).name, 'Alice');
      });

      test('encoder handles list of custom types', () async {
        Object? customEncoder(Object? value) {
          if (value is User) {
            return {'__type': 'User', ...value.toJson()};
          }
          return value;
        }

        Object? customDecoder(Object? key, Object? value) {
          if (value is Map && value['__type'] == 'User') {
            return User.fromJson(value.cast<String, dynamic>());
          }
          return value;
        }

        await initHiveCore(configs: [
          HiveConfig(
            env: 'test',
            boxCollectionName: generateCollectionName(),
            jsonEncoder: customEncoder,
            jsonDecoder: customDecoder,
          ),
        ]);

        final hive = await HHive.create('test');

        final users = [
          User(name: 'Alice', age: 30, createdAt: DateTime(2026, 1, 1)),
          User(name: 'Bob', age: 25, createdAt: DateTime(2026, 2, 1)),
          User(name: 'Charlie', age: 35, createdAt: DateTime(2026, 3, 1)),
        ];

        await hive.put('users', users);
        final result = await hive.get('users');

        expect(result, isA<List>());
        final resultList = result as List;
        expect(resultList.length, 3);
        expect(resultList.every((e) => e is User), isTrue);
        expect((resultList[0] as User).name, 'Alice');
        expect((resultList[2] as User).name, 'Charlie');
      });
    });

    group('Edge cases', () {
      test('null encoder uses default jsonEncode', () async {
        await initHiveCore(configs: [
          HiveConfig(
            env: 'test',
            boxCollectionName: generateCollectionName(),
            jsonEncoder: null,
          ),
        ]);

        final hive = await HHive.create('test');

        await hive.put('data', {'key': 'value', 'number': 42});
        final result = await hive.get('data');

        expect(result, {'key': 'value', 'number': 42});
      });

      test('encoder handles objects with toJson', () async {
        // The toEncodable callback is called when json encoder
        // encounters an object it can't directly serialize
        Object? customEncoder(Object? value) {
          if (value is User) {
            // Can filter or transform during encoding
            return {
              'type': 'user',
              'name': value.name,
              'age': value.age,
              // Intentionally omit createdAt
            };
          }
          return value;
        }

        await initHiveCore(configs: [
          HiveConfig(
            env: 'test',
            boxCollectionName: generateCollectionName(),
            jsonEncoder: customEncoder,
          ),
        ]);

        final hive = await HHive.create('test');

        final user = User(
          name: 'Alice',
          age: 30,
          createdAt: DateTime(2026, 1, 1),
        );

        await hive.put('user', user);

        final result = await hive.get('user');

        expect(result, isA<Map>());
        expect((result as Map)['type'], 'user');
        expect(result['name'], 'Alice');
        expect(result['age'], 30);
        // createdAt was intentionally not included
        expect(result.containsKey('createdAt'), isFalse);
      });
    });
  });
}
