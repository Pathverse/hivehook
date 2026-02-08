@TestOn('vm')
library;

import 'package:hivehook/hivehook.dart';
import 'package:test/test.dart';

import '../common/test_helpers.dart';

/// Tests for BoxCollection constraints and dynamic registration.
///
/// BoxCollection rules:
/// 1. Cannot add new box to an already-OPENED BoxCollection
/// 2. Can register BoxCollection config after init IF collection not yet opened
/// 3. When accessing store from unopened collection, it opens and locks it
/// 4. Normal Box can open anytime (lazy)
void main() {
  group('BoxCollection - Opened Collection Lock', () {
    setUp(() async {
      await resetHiveState();
    });

    tearDown(() async {
      await resetHiveState();
    });

    test('cannot register new box to already-opened collection', () async {
      final collectionName = generateCollectionName();

      HHiveCore.register(HiveConfig(
        env: 'users',
        boxCollectionName: collectionName,
      ));

      await initWithTempPath();

      // Collection is now opened, cannot add NEW box to it
      expect(
        () => HHiveCore.register(HiveConfig(
          env: 'orders',
          boxName: 'orders_box', // NEW box name
          boxCollectionName: collectionName,
        )),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('already opened'),
        )),
      );
    });

    test('can reuse existing box in opened collection with new env', () async {
      final collectionName = generateCollectionName();

      HHiveCore.register(HiveConfig(
        env: 'users_v1',
        boxName: 'users',
        boxCollectionName: collectionName,
      ));

      await initWithTempPath();

      // Collection is opened, but we can reuse the existing 'users' box
      expect(
        () => HHiveCore.register(HiveConfig(
          env: 'users_v2',
          boxName: 'users', // EXISTING box name
          boxCollectionName: collectionName,
        )),
        returnsNormally,
      );

      // Both envs should work and be isolated
      final v1 = await HHive.create('users_v1');
      final v2 = await HHive.create('users_v2');

      await v1.put('key1', 'from_v1');
      await v2.put('key1', 'from_v2');

      expect(await v1.get('key1'), 'from_v1');
      expect(await v2.get('key1'), 'from_v2');
    });

    test('can register to different collection after init', () async {
      final collection1 = generateCollectionName();
      final collection2 = generateCollectionName();

      HHiveCore.register(HiveConfig(
        env: 'users',
        boxCollectionName: collection1,
      ));

      await initWithTempPath();

      // collection1 is opened, but collection2 is not
      // Should be able to register to collection2
      expect(
        () => HHiveCore.register(HiveConfig(
          env: 'orders',
          boxCollectionName: collection2,
        )),
        returnsNormally,
      );
    });

    test('accessing store opens and locks collection', () async {
      final collection1 = generateCollectionName();
      final collection2 = generateCollectionName();

      HHiveCore.register(HiveConfig(
        env: 'users',
        boxCollectionName: collection1,
      ));

      await initWithTempPath();

      // Register to collection2 (not yet opened)
      HHiveCore.register(HiveConfig(
        env: 'orders',
        boxCollectionName: collection2,
      ));

      // Can still add more to collection2 before accessing
      HHiveCore.register(HiveConfig(
        env: 'products',
        boxCollectionName: collection2,
      ));

      // Access orders - this opens collection2
      final ordersHive = await HHive.create('orders');
      await ordersHive.put('o1', {'total': 100});

      // Now collection2 is opened, cannot add more
      expect(
        () => HHiveCore.register(HiveConfig(
          env: 'inventory',
          boxCollectionName: collection2,
        )),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('already opened'),
        )),
      );

      // But products (registered before open) should work
      final productsHive = await HHive.create('products');
      await productsHive.put('p1', {'sku': 'ABC'});
      expect(await productsHive.get('p1'), {'sku': 'ABC'});
    });
  });

  group('BoxCollection - Pre-init Registration', () {
    setUp(() async {
      await resetHiveState();
    });

    tearDown(() async {
      await resetHiveState();
    });

    test('multiple envs in same collection before init', () async {
      final collectionName = generateCollectionName();

      HHiveCore.register(HiveConfig(
        env: 'users',
        boxCollectionName: collectionName,
      ));
      HHiveCore.register(HiveConfig(
        env: 'orders',
        boxCollectionName: collectionName,
      ));
      HHiveCore.register(HiveConfig(
        env: 'products',
        boxCollectionName: collectionName,
      ));

      await initWithTempPath();

      final usersHive = await HHive.create('users');
      final ordersHive = await HHive.create('orders');
      final productsHive = await HHive.create('products');

      await usersHive.put('u1', {'name': 'Alice'});
      await ordersHive.put('o1', {'total': 100});
      await productsHive.put('p1', {'sku': 'ABC'});

      expect(await usersHive.get('u1'), {'name': 'Alice'});
      expect(await ordersHive.get('o1'), {'total': 100});
      expect(await productsHive.get('p1'), {'sku': 'ABC'});
    });

    test('multiple collections before init', () async {
      HHiveCore.register(HiveConfig(
        env: 'users',
        boxCollectionName: 'collection_a',
      ));
      HHiveCore.register(HiveConfig(
        env: 'orders',
        boxCollectionName: 'collection_b',
      ));

      await initWithTempPath();

      final usersHive = await HHive.create('users');
      final ordersHive = await HHive.create('orders');

      await usersHive.put('key', 'from_a');
      await ordersHive.put('key', 'from_b');

      expect(await usersHive.get('key'), 'from_a');
      expect(await ordersHive.get('key'), 'from_b');
    });
  });

  group('BoxCollection - Lazy Collection Opening', () {
    setUp(() async {
      await resetHiveState();
    });

    tearDown(() async {
      await resetHiveState();
    });

    test('collection not opened until first store access', () async {
      final collection1 = generateCollectionName();
      final collection2 = generateCollectionName();

      HHiveCore.register(HiveConfig(
        env: 'env1',
        boxCollectionName: collection1,
      ));

      await initWithTempPath();

      // Register to collection2 after init
      HHiveCore.register(HiveConfig(
        env: 'env2',
        boxCollectionName: collection2,
      ));

      // collection2 not opened yet
      expect(HHiveCore.isCollectionOpened(collection2), isFalse);

      // Access env2 - opens collection2
      await HHive.create('env2');

      expect(HHiveCore.isCollectionOpened(collection2), isTrue);
    });

    test('initialize opens registered collections', () async {
      final collectionName = generateCollectionName();

      HHiveCore.register(HiveConfig(
        env: 'users',
        boxCollectionName: collectionName,
      ));

      expect(HHiveCore.isCollectionOpened(collectionName), isFalse);

      await initWithTempPath();

      expect(HHiveCore.isCollectionOpened(collectionName), isTrue);
    });
  });

  group('BoxCollection - Env Isolation', () {
    setUp(() async {
      await resetHiveState();
    });

    tearDown(() async {
      await resetHiveState();
    });

    test('envs sharing boxName in same collection', () async {
      final collectionName = generateCollectionName();

      HHiveCore.register(HiveConfig(
        env: 'v1',
        boxName: 'shared',
        boxCollectionName: collectionName,
      ));
      HHiveCore.register(HiveConfig(
        env: 'v2',
        boxName: 'shared',
        boxCollectionName: collectionName,
      ));

      await initWithTempPath();

      final v1 = await HHive.create('v1');
      final v2 = await HHive.create('v2');

      await v1.put('key', 'val1');
      await v2.put('key', 'val2');

      expect(await v1.get('key'), 'val1');
      expect(await v2.get('key'), 'val2');
    });
  });

  group('HiveBoxType.box (Lazy Individual)', () {
    setUp(() async {
      await resetHiveState();
    });

    tearDown(() async {
      await resetHiveState();
    });

    test('Box type can be registered anytime', () async {
      await initWithTempPath();

      // Box type allowed after init
      expect(
        () => HHiveCore.register(HiveConfig(
          env: 'lazy1',
          type: HiveBoxType.box,
        )),
        returnsNormally,
      );

      // Multiple times
      expect(
        () => HHiveCore.register(HiveConfig(
          env: 'lazy2',
          type: HiveBoxType.box,
        )),
        returnsNormally,
      );
    });

    test('Box type creates store lazily on getStore', () async {
      HHiveCore.register(HiveConfig(
        env: 'lazy',
        type: HiveBoxType.box,
      ));

      await initWithTempPath();

      // Should create store successfully
      final store = await HHiveCore.getStore('lazy');
      expect(store, isNotNull);

      // Verify store is cached
      final store2 = await HHiveCore.getStore('lazy');
      expect(identical(store, store2), isTrue);
    });

    test('Box type with meta creates separate meta box', () async {
      HHiveCore.register(HiveConfig(
        env: 'boxmeta',
        type: HiveBoxType.box,
        withMeta: true,
      ));

      await initWithTempPath();

      final store = await HHiveCore.getStore('boxmeta');
      expect(store.supportsMeta, isTrue);

      // Test meta operations work
      await store.putMeta('key1', {'ttl': 3600});
      final meta = await store.getMeta('key1');
      expect(meta, {'ttl': 3600});
    });
  });

  group('Info Methods', () {
    setUp(() async {
      await resetHiveState();
    });

    tearDown(() async {
      await resetHiveState();
    });

    test('isInitialized reflects state', () async {
      expect(HHiveCore.isInitialized, isFalse);

      HHiveCore.register(HiveConfig(
        env: 'test',
        boxCollectionName: generateCollectionName(),
      ));

      expect(HHiveCore.isInitialized, isFalse);

      await initWithTempPath();

      expect(HHiveCore.isInitialized, isTrue);
    });

    test('configs map is unmodifiable', () async {
      HHiveCore.register(HiveConfig(
        env: 'test',
        boxCollectionName: generateCollectionName(),
      ));

      expect(
        () => HHiveCore.configs['test2'] = HiveConfig(env: 'test2'),
        throwsA(isA<UnsupportedError>()),
      );
    });
  });
}
