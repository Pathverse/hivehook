@TestOn('vm')
library;

import 'package:hivehook/hivehook.dart';
import 'package:test/test.dart';

import '../common/test_helpers.dart';

void main() {
  group('Complex Nested Structures', () {
    setUp(() async {
      await resetHiveState();
    });

    tearDown(() async {
      await resetHiveState();
    });

    group('Deep nesting', () {
      test('5-level deep nested maps', () async {
        await initHiveCore(configs: [
          HiveConfig(
            env: 'test',
            boxCollectionName: generateCollectionName(),
          ),
        ]);

        final hive = await HHive.create('test');

        final deep = {
          'level1': {
            'level2': {
              'level3': {
                'level4': {
                  'level5': {
                    'value': 'deep-value',
                    'number': 42,
                  },
                },
              },
            },
          },
        };

        await hive.put('deep', deep);
        final result = await hive.get('deep');

        expect(result, deep);
        expect(
          (result as Map)['level1']['level2']['level3']['level4']['level5']['value'],
          'deep-value',
        );
      });

      test('mixed nested lists and maps', () async {
        await initHiveCore(configs: [
          HiveConfig(
            env: 'test',
            boxCollectionName: generateCollectionName(),
          ),
        ]);

        final hive = await HHive.create('test');

        final complex = {
          'users': [
            {
              'id': 1,
              'name': 'Alice',
              'addresses': [
                {'type': 'home', 'city': 'NYC', 'zip': '10001'},
                {'type': 'work', 'city': 'Boston', 'zip': '02101'},
              ],
              'preferences': {
                'notifications': {
                  'email': true,
                  'push': false,
                  'channels': ['marketing', 'updates'],
                },
              },
            },
            {
              'id': 2,
              'name': 'Bob',
              'addresses': [
                {'type': 'home', 'city': 'LA', 'zip': '90001'},
              ],
              'preferences': {
                'notifications': {
                  'email': false,
                  'push': true,
                  'channels': ['security'],
                },
              },
            },
          ],
          'meta': {
            'version': 2,
            'schema': 'user_v2',
          },
        };

        await hive.put('org', complex);
        final result = await hive.get('org');

        expect(result, complex);

        final users = (result as Map)['users'] as List;
        expect(users.length, 2);
        expect(users[0]['addresses'][1]['city'], 'Boston');
        expect(users[1]['preferences']['notifications']['channels'], ['security']);
      });

      test('list of lists', () async {
        await initHiveCore(configs: [
          HiveConfig(
            env: 'test',
            boxCollectionName: generateCollectionName(),
          ),
        ]);

        final hive = await HHive.create('test');

        final matrix = [
          [1, 2, 3],
          [4, 5, 6],
          [7, 8, 9],
        ];

        await hive.put('matrix', matrix);
        final result = await hive.get('matrix');

        expect(result, matrix);
        expect((result as List)[1][1], 5);
      });

      test('3D matrix (list of lists of lists)', () async {
        await initHiveCore(configs: [
          HiveConfig(
            env: 'test',
            boxCollectionName: generateCollectionName(),
          ),
        ]);

        final hive = await HHive.create('test');

        final cube = [
          [
            [1, 2],
            [3, 4],
          ],
          [
            [5, 6],
            [7, 8],
          ],
        ];

        await hive.put('cube', cube);
        final result = await hive.get('cube');

        expect(result, cube);
        expect((result as List)[1][0][1], 6);
      });
    });

    group('Large data structures', () {
      test('large list (1000 items)', () async {
        await initHiveCore(configs: [
          HiveConfig(
            env: 'test',
            boxCollectionName: generateCollectionName(),
          ),
        ]);

        final hive = await HHive.create('test');

        final items = List.generate(1000, (i) => {
          'id': i,
          'name': 'Item $i',
          'value': i * 1.5,
        });

        await hive.put('items', items);
        final result = await hive.get('items');

        expect((result as List).length, 1000);
        expect(result[500]['id'], 500);
        expect(result[999]['name'], 'Item 999');
      });

      test('wide map (100 keys)', () async {
        await initHiveCore(configs: [
          HiveConfig(
            env: 'test',
            boxCollectionName: generateCollectionName(),
          ),
        ]);

        final hive = await HHive.create('test');

        final wide = <String, dynamic>{};
        for (var i = 0; i < 100; i++) {
          wide['key_$i'] = {
            'index': i,
            'data': 'value_$i',
            'nested': {'a': i, 'b': i * 2},
          };
        }

        await hive.put('wide', wide);
        final result = await hive.get('wide');

        expect((result as Map).length, 100);
        expect(result['key_50']['index'], 50);
        expect(result['key_99']['nested']['b'], 198);
      });
    });

    group('Mixed primitive types', () {
      test('all JSON primitive types together', () async {
        await initHiveCore(configs: [
          HiveConfig(
            env: 'test',
            boxCollectionName: generateCollectionName(),
          ),
        ]);

        final hive = await HHive.create('test');

        final mixed = {
          'string': 'hello',
          'int': 42,
          'double': 3.14159,
          'bool_true': true,
          'bool_false': false,
          'null_value': null,
          'list_mixed': [1, 'two', 3.0, true, null],
          'nested': {
            'also_mixed': [
              {'num': 1},
              {'str': 'abc'},
            ],
          },
        };

        await hive.put('mixed', mixed);
        final result = await hive.get('mixed');

        expect(result, mixed);
        expect((result as Map)['string'], 'hello');
        expect(result['int'], 42);
        expect(result['double'], closeTo(3.14159, 0.00001));
        expect(result['bool_true'], true);
        expect(result['bool_false'], false);
        expect(result['null_value'], isNull);
        expect(result['list_mixed'][4], isNull);
      });

      test('unicode strings', () async {
        await initHiveCore(configs: [
          HiveConfig(
            env: 'test',
            boxCollectionName: generateCollectionName(),
          ),
        ]);

        final hive = await HHive.create('test');

        final unicode = {
          'emoji': '🎉🚀✨',
          'chinese': '你好世界',
          'japanese': 'こんにちは',
          'arabic': 'مرحبا',
          'russian': 'Привет',
          'mixed': 'Hello 世界 🌍',
        };

        await hive.put('unicode', unicode);
        final result = await hive.get('unicode');

        expect(result, unicode);
        expect((result as Map)['emoji'], '🎉🚀✨');
        expect(result['chinese'], '你好世界');
      });

      test('special string values', () async {
        await initHiveCore(configs: [
          HiveConfig(
            env: 'test',
            boxCollectionName: generateCollectionName(),
          ),
        ]);

        final hive = await HHive.create('test');

        final special = {
          'empty': '',
          'whitespace': '   ',
          'newlines': 'line1\nline2\nline3',
          'tabs': 'col1\tcol2\tcol3',
          'quotes': '"quoted" and \'single\'',
          'backslash': 'path\\to\\file',
          'json_like': '{"key": "value"}',
        };

        await hive.put('special', special);
        final result = await hive.get('special');

        expect(result, special);
        expect((result as Map)['empty'], '');
        expect(result['newlines'], 'line1\nline2\nline3');
        expect(result['json_like'], '{"key": "value"}');
      });

      test('numeric edge cases', () async {
        await initHiveCore(configs: [
          HiveConfig(
            env: 'test',
            boxCollectionName: generateCollectionName(),
          ),
        ]);

        final hive = await HHive.create('test');

        final numbers = {
          'zero': 0,
          'negative': -42,
          'large_int': 9007199254740991, // Max safe integer in JS
          'small_double': 0.000001,
          'large_double': 1e308,
          'negative_double': -3.14,
        };

        await hive.put('numbers', numbers);
        final result = await hive.get('numbers');

        expect((result as Map)['zero'], 0);
        expect(result['negative'], -42);
        expect(result['large_int'], 9007199254740991);
        expect(result['small_double'], closeTo(0.000001, 0.0000001));
      });
    });

    group('Real-world scenarios', () {
      test('e-commerce order with nested items', () async {
        await initHiveCore(configs: [
          HiveConfig(
            env: 'test',
            boxCollectionName: generateCollectionName(),
            withMeta: true,
          ),
        ]);

        final hive = await HHive.create('test');

        final order = {
          'orderId': 'ORD-2026-001',
          'customer': {
            'id': 'CUST-123',
            'name': 'John Doe',
            'email': 'john@example.com',
            'addresses': {
              'billing': {
                'street': '123 Main St',
                'city': 'New York',
                'state': 'NY',
                'zip': '10001',
                'country': 'USA',
              },
              'shipping': {
                'street': '456 Oak Ave',
                'city': 'Brooklyn',
                'state': 'NY',
                'zip': '11201',
                'country': 'USA',
              },
            },
          },
          'items': [
            {
              'sku': 'PROD-001',
              'name': 'Widget Pro',
              'quantity': 2,
              'price': 29.99,
              'options': {
                'color': 'blue',
                'size': 'medium',
              },
              'discount': {
                'type': 'percentage',
                'value': 10,
              },
            },
            {
              'sku': 'PROD-002',
              'name': 'Gadget Plus',
              'quantity': 1,
              'price': 149.99,
              'options': {
                'warranty': '2-year',
              },
              'discount': null,
            },
          ],
          'totals': {
            'subtotal': 209.97,
            'discount': 6.00,
            'tax': 16.32,
            'shipping': 9.99,
            'total': 230.28,
          },
          'payment': {
            'method': 'credit_card',
            'last4': '4242',
            'status': 'captured',
          },
          'timestamps': {
            'created': 1706544000000,
            'updated': 1706547600000,
            'shipped': null,
          },
        };

        await hive.put(
          'order:ORD-2026-001',
          order,
          meta: {'version': 1, 'source': 'web'},
        );

        final record = await hive.getWithMeta<Map>('order:ORD-2026-001');

        expect(record.value, order);
        expect(record.meta?['version'], 1);

        final items = record.value!['items'] as List;
        expect(items.length, 2);
        expect(items[0]['options']['color'], 'blue');
        expect(items[1]['discount'], isNull);
      });

      test('social media post with reactions and comments', () async {
        await initHiveCore(configs: [
          HiveConfig(
            env: 'test',
            boxCollectionName: generateCollectionName(),
          ),
        ]);

        final hive = await HHive.create('test');

        final post = {
          'id': 'post-abc123',
          'author': {
            'id': 'user-456',
            'username': 'alice',
            'displayName': 'Alice Smith',
            'avatar': 'https://example.com/avatars/alice.jpg',
            'verified': true,
          },
          'content': {
            'text': 'Just launched my new app! 🚀',
            'media': [
              {
                'type': 'image',
                'url': 'https://example.com/img1.jpg',
                'alt': 'App screenshot',
                'dimensions': {'width': 1200, 'height': 800},
              },
              {
                'type': 'image',
                'url': 'https://example.com/img2.jpg',
                'alt': 'Features overview',
                'dimensions': {'width': 1200, 'height': 600},
              },
            ],
            'links': [
              {'url': 'https://myapp.com', 'title': 'Download Now'},
            ],
          },
          'reactions': {
            'like': 1542,
            'love': 234,
            'celebrate': 89,
            'users': {
              'like': ['user-1', 'user-2', 'user-3'],
              'love': ['user-4', 'user-5'],
            },
          },
          'comments': [
            {
              'id': 'comment-1',
              'author': {'id': 'user-789', 'username': 'bob'},
              'text': 'Looks amazing! 🎉',
              'reactions': {'like': 23},
              'replies': [
                {
                  'id': 'reply-1',
                  'author': {'id': 'user-456', 'username': 'alice'},
                  'text': 'Thanks Bob!',
                  'reactions': {'like': 5},
                },
              ],
            },
          ],
          'stats': {
            'views': 15420,
            'shares': 342,
            'bookmarks': 89,
          },
        };

        await hive.put('post:abc123', post);
        final result = await hive.get('post:abc123');

        expect(result, post);

        final content = (result as Map)['content'];
        expect(content['media'].length, 2);
        expect(content['media'][0]['dimensions']['width'], 1200);

        final comments = result['comments'] as List;
        expect(comments[0]['replies'][0]['text'], 'Thanks Bob!');
      });

      test('configuration with environment overrides', () async {
        await initHiveCore(configs: [
          HiveConfig(
            env: 'test',
            boxCollectionName: generateCollectionName(),
          ),
        ]);

        final hive = await HHive.create('test');

        final config = {
          'app': {
            'name': 'MyApp',
            'version': '2.1.0',
            'features': {
              'darkMode': true,
              'analytics': true,
              'experimental': {
                'newUI': false,
                'betaFeatures': ['feature-a', 'feature-b'],
              },
            },
          },
          'environments': {
            'development': {
              'apiUrl': 'http://localhost:3000',
              'debug': true,
              'logLevel': 'verbose',
              'features': {
                'experimental': {
                  'newUI': true,
                },
              },
            },
            'staging': {
              'apiUrl': 'https://staging.api.example.com',
              'debug': true,
              'logLevel': 'info',
            },
            'production': {
              'apiUrl': 'https://api.example.com',
              'debug': false,
              'logLevel': 'error',
              'cdn': {
                'enabled': true,
                'url': 'https://cdn.example.com',
              },
            },
          },
          'services': {
            'auth': {
              'provider': 'oauth2',
              'endpoints': {
                'login': '/auth/login',
                'logout': '/auth/logout',
                'refresh': '/auth/refresh',
              },
              'scopes': ['profile', 'email', 'openid'],
            },
            'storage': {
              'provider': 's3',
              'bucket': 'myapp-uploads',
              'region': 'us-east-1',
              'limits': {
                'maxFileSize': 10485760,
                'allowedTypes': ['image/*', 'application/pdf'],
              },
            },
          },
        };

        await hive.put('config', config);
        final result = await hive.get('config');

        expect(result, config);

        final services = (result as Map)['services'];
        expect(services['auth']['scopes'], ['profile', 'email', 'openid']);
        expect(services['storage']['limits']['maxFileSize'], 10485760);
      });
    });

    group('Edge cases', () {
      test('empty structures', () async {
        await initHiveCore(configs: [
          HiveConfig(
            env: 'test',
            boxCollectionName: generateCollectionName(),
          ),
        ]);

        final hive = await HHive.create('test');

        final empty = {
          'emptyMap': <String, dynamic>{},
          'emptyList': <dynamic>[],
          'nested': {
            'alsoEmpty': <String, dynamic>{},
            'emptyInList': [<String, dynamic>{}, <dynamic>[]],
          },
        };

        await hive.put('empty', empty);
        final result = await hive.get('empty');

        expect((result as Map)['emptyMap'], <String, dynamic>{});
        expect(result['emptyList'], <dynamic>[]);
        expect(result['nested']['emptyInList'][0], <String, dynamic>{});
      });

      test('keys with special characters', () async {
        await initHiveCore(configs: [
          HiveConfig(
            env: 'test',
            boxCollectionName: generateCollectionName(),
          ),
        ]);

        final hive = await HHive.create('test');

        final special = {
          'key with spaces': 'value1',
          'key.with.dots': 'value2',
          'key:with:colons': 'value3',
          'key/with/slashes': 'value4',
          'key@with@at': 'value5',
          'key#with#hash': 'value6',
        };

        await hive.put('special_keys', special);
        final result = await hive.get('special_keys');

        expect(result, special);
        expect((result as Map)['key with spaces'], 'value1');
        expect(result['key:with:colons'], 'value3');
      });
    });
  });
}
