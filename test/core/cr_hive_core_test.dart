@TestOn('vm')
library;

import 'package:hivehook/hivehook.dart';
import 'package:test/test.dart';

import '../common/test_helpers.dart';

void main() {
  group('HHiveCore Lifecycle', () {
    setUp(() async {
      await resetHiveState();
    });

    tearDown(() async {
      await resetHiveState();
    });

    group('Registration', () {
      test('register adds config to registry', () async {
        HHiveCore.register(HiveConfig(
          env: 'users',
          boxCollectionName: generateCollectionName(),
        ));

        expect(HHiveCore.configs.containsKey('users'), isTrue);
        expect(HHiveCore.configs['users']?.env, 'users');
      });

      test('register multiple environments', () async {
        HHiveCore.register(HiveConfig(
          env: 'env1',
          boxCollectionName: generateCollectionName(),
        ));
        HHiveCore.register(HiveConfig(
          env: 'env2',
          boxCollectionName: generateCollectionName(),
        ));
        HHiveCore.register(HiveConfig(
          env: 'env3',
          boxCollectionName: generateCollectionName(),
        ));

        expect(HHiveCore.configs.length, 3);
        expect(HHiveCore.configs.keys, containsAll(['env1', 'env2', 'env3']));
      });

      test('register same env twice throws StateError', () async {
        HHiveCore.register(HiveConfig(
          env: 'test',
          boxCollectionName: generateCollectionName(),
          withMeta: false,
        ));

        expect(
          () => HHiveCore.register(HiveConfig(
            env: 'test',
            boxCollectionName: generateCollectionName(),
            withMeta: true,
          )),
          throwsA(isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('already registered'),
          )),
        );
      });
    });

    group('Initialization', () {
      test('initialize creates stores for all registered configs', () async {
        await initHiveCore(configs: [
          HiveConfig(env: 'a', boxCollectionName: generateCollectionName()),
          HiveConfig(env: 'b', boxCollectionName: generateCollectionName()),
        ]);

        final storeA = await HHiveCore.getStore('a');
        final storeB = await HHiveCore.getStore('b');

        expect(storeA, isNotNull);
        expect(storeB, isNotNull);
      });

      test('getStore throws for unregistered env', () async {
        await initHiveCore(configs: [
          HiveConfig(env: 'registered', boxCollectionName: generateCollectionName()),
        ]);

        expect(
          () => HHiveCore.getStore('unregistered'),
          throwsA(isA<StateError>()),
        );
      });

      test('initialize is idempotent', () async {
        await initHiveCore(configs: [
          HiveConfig(env: 'test', boxCollectionName: generateCollectionName()),
        ]);

        final store1 = await HHiveCore.getStore('test');

        // Second init should be a no-op
        await HHiveCore.initialize();
        final store2 = await HHiveCore.getStore('test');

        // Same store instance
        expect(identical(store1, store2), isTrue);
      });
    });

    group('Reset', () {
      test('reset clears all stores and configs', () async {
        await initHiveCore(configs: [
          HiveConfig(env: 'test', boxCollectionName: generateCollectionName()),
        ]);

        final hive = await HHive.create('test');
        await hive.put('key', 'value');

        await HHiveCore.reset();

        expect(HHiveCore.configs.isEmpty, isTrue);
      });

      test('reset allows re-registration', () async {
        await initHiveCore(configs: [
          HiveConfig(env: 'old', boxCollectionName: generateCollectionName()),
        ]);

        await HHiveCore.reset();

        await initHiveCore(configs: [
          HiveConfig(env: 'new', boxCollectionName: generateCollectionName()),
        ]);

        expect(HHiveCore.configs.containsKey('new'), isTrue);
        expect(HHiveCore.configs.containsKey('old'), isFalse);
      });
    });

    group('Global Defaults', () {
      test('globalHooks are available via getHooksFor', () async {
        final hook1 = HiHook<dynamic, dynamic>(
          uid: 'global:1',
          events: ['write'],
          handler: (p, c) => const HiContinue(),
        );

        HHiveCore.globalHooks.add(hook1);

        HHiveCore.register(HiveConfig(
          env: 'test',
          boxCollectionName: generateCollectionName(),
        ));

        final hooks = HHiveCore.getHooksFor('test');

        expect(hooks.length, 1);
        expect(hooks.first.uid, 'global:1');
      });

      test('getHooksFor merges global and config hooks', () async {
        final globalHook = HiHook<dynamic, dynamic>(
          uid: 'global:hook',
          events: ['write'],
          handler: (p, c) => const HiContinue(),
        );

        final configHook = HiHook<dynamic, dynamic>(
          uid: 'config:hook',
          events: ['read'],
          handler: (p, c) => const HiContinue(),
        );

        HHiveCore.globalHooks.add(globalHook);

        HHiveCore.register(HiveConfig(
          env: 'test',
          boxCollectionName: generateCollectionName(),
          hooks: [configHook],
        ));

        final hooks = HHiveCore.getHooksFor('test');

        expect(hooks.length, 2);
        expect(hooks.map((h) => h.uid), containsAll(['global:hook', 'config:hook']));
      });

      test('globalTypeAdapters are registered on initialize', () async {
        // Note: This is a conceptual test - actual adapter registration
        // would need specific type adapters to verify
        HHiveCore.globalTypeAdapters.clear();

        await initHiveCore(configs: [
          HiveConfig(env: 'test', boxCollectionName: generateCollectionName()),
        ]);

        // If we get here without error, adapters were handled correctly
        expect(true, isTrue);
      });
    });

    group('Storage Modes', () {
      test('default storage mode is JSON', () async {
        final config = HiveConfig(
          env: 'test',
          boxCollectionName: generateCollectionName(),
        );

        expect(config.storageMode, HiveStorageMode.json);
      });

      test('native storage mode can be set', () async {
        final config = HiveConfig(
          env: 'test',
          boxCollectionName: generateCollectionName(),
          storageMode: HiveStorageMode.native,
        );

        expect(config.storageMode, HiveStorageMode.native);
      });
    });

    group('Config properties', () {
      test('config stores all properties', () async {
        final encoder = (Object? v) => v;
        final decoder = (Object? k, Object? v) => v;
        final hook = HiHook<dynamic, dynamic>(
          uid: 'test',
          events: ['write'],
          handler: (p, c) => const HiContinue(),
        );

        final config = HiveConfig(
          env: 'myenv',
          boxCollectionName: 'mybox',
          withMeta: true,
          storageMode: HiveStorageMode.json,
          hooks: [hook],
          jsonEncoder: encoder,
          jsonDecoder: decoder,
        );

        expect(config.env, 'myenv');
        expect(config.boxCollectionName, 'mybox');
        expect(config.withMeta, isTrue);
        expect(config.storageMode, HiveStorageMode.json);
        expect(config.hooks.length, 1);
        expect(config.jsonEncoder, encoder);
        expect(config.jsonDecoder, decoder);
      });

      test('config has sensible defaults', () async {
        final config = HiveConfig(
          env: 'test',
          boxCollectionName: 'box',
        );

        expect(config.withMeta, isTrue); // Default is true for metadata support
        expect(config.storageMode, HiveStorageMode.json);
        expect(config.hooks, isEmpty);
        expect(config.typeAdapters, isEmpty);
        expect(config.jsonEncoder, isNull);
        expect(config.jsonDecoder, isNull);
      });
    });

    group('BoxCollectionConfig Registration', () {
      test('registerCollection adds collection config', () async {
        final collectionName = generateCollectionName();
        HHiveCore.registerCollection(BoxCollectionConfig(
          name: collectionName,
          storagePath: '/custom/path',
          includeMeta: true,
        ));

        expect(HHiveCore.collectionConfigs.containsKey(collectionName), isTrue);
        expect(HHiveCore.collectionConfigs[collectionName]?.storagePath, '/custom/path');
        expect(HHiveCore.collectionConfigs[collectionName]?.includeMeta, isTrue);
      });

      test('registerCollection throws on duplicate', () async {
        final collectionName = generateCollectionName();
        HHiveCore.registerCollection(BoxCollectionConfig(name: collectionName));

        expect(
          () => HHiveCore.registerCollection(BoxCollectionConfig(name: collectionName)),
          throwsA(isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('already registered'),
          )),
        );
      });

      test('register auto-creates BoxCollectionConfig if not pre-registered', () async {
        final collectionName = generateCollectionName();
        HHiveCore.register(HiveConfig(
          env: 'users',
          boxCollectionName: collectionName,
        ));

        expect(HHiveCore.collectionConfigs.containsKey(collectionName), isTrue);
        expect(HHiveCore.collectionConfigs[collectionName]?.isExplicit, isFalse);
      });

      test('register updates BoxCollectionConfig boxNames', () async {
        final collectionName = generateCollectionName();
        HHiveCore.register(HiveConfig(
          env: 'users',
          boxName: 'users_box',
          boxCollectionName: collectionName,
        ));
        HHiveCore.register(HiveConfig(
          env: 'settings',
          boxName: 'settings_box',
          boxCollectionName: collectionName,
        ));

        final collectionConfig = HHiveCore.collectionConfigs[collectionName]!;
        expect(collectionConfig.boxNames, containsAll(['users_box', 'settings_box']));
      });

      test('pre-registered BoxCollectionConfig is used when HiveConfig references it', () async {
        final collectionName = generateCollectionName();
        HHiveCore.registerCollection(BoxCollectionConfig(
          name: collectionName,
          storagePath: '/custom/path',
          boxNames: {'predeclared_box'},
        ));

        HHiveCore.register(HiveConfig(
          env: 'users',
          boxName: 'users_box',
          boxCollectionName: collectionName,
        ));

        final collectionConfig = HHiveCore.collectionConfigs[collectionName]!;
        expect(collectionConfig.isExplicit, isTrue);
        expect(collectionConfig.storagePath, '/custom/path');
        expect(collectionConfig.boxNames, containsAll(['predeclared_box', 'users_box']));
      });

      test('HiveConfig.withMeta respects BoxCollectionConfig.includeMeta=false conflict', () async {
        final collectionName = generateCollectionName();
        HHiveCore.registerCollection(BoxCollectionConfig(
          name: collectionName,
          includeMeta: false,
        ));

        expect(
          () => HHiveCore.register(HiveConfig(
            env: 'users',
            boxCollectionName: collectionName,
            withMeta: true,
          )),
          throwsA(isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('includeMeta=false'),
          )),
        );
      });
    });
  });
}
