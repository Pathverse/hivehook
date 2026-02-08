import 'package:flutter/material.dart';
import 'package:hivehook/hivehook.dart';

import '../main.dart';
import 'scenario.dart';

/// Demonstrates BoxCollection architecture:
/// - Multiple BoxCollections
/// - Multiple envs sharing one collection
/// - Env isolation within shared boxName
/// - Error handling for post-init registration
class MultiCollectionScenario extends Scenario {
  @override
  String get name => 'Multi-Collection Architecture';

  @override
  String get description =>
      'Demonstrates BoxCollection setup with multiple envs, '
      'shared boxNames, and registration constraints.';

  @override
  IconData get icon => Icons.account_tree_rounded;

  @override
  List<String> get tags => ['architecture', 'collections', 'advanced'];

  @override
  Future<void> run(LogCallback log) async {
    // Note: This scenario demonstrates the architecture concepts.
    // In a real app, you'd register all configs at startup before initialize().
    // Since the demo app already called initialize(), we show the concepts
    // using the existing 'demo' env and explain the patterns.

    log('📦 BoxCollection Architecture Overview');
    log('');

    // Part 1: Explain the registration pattern
    log('1️⃣ Registration Pattern (must be before initialize):');
    log('');
    log('   // Collection "ecommerce" with 3 envs:');
    log('   HHiveCore.register(HiveConfig(');
    log('     env: "users",');
    log('     boxCollectionName: "ecommerce",');
    log('   ));');
    log('   HHiveCore.register(HiveConfig(');
    log('     env: "orders",');
    log('     boxCollectionName: "ecommerce",');
    log('   ));');
    log('   HHiveCore.register(HiveConfig(');
    log('     env: "products",');
    log('     boxCollectionName: "ecommerce",');
    log('   ));');
    log('');
    log('   // Separate collection for analytics:');
    log('   HHiveCore.register(HiveConfig(');
    log('     env: "metrics",');
    log('     boxCollectionName: "analytics",');
    log('   ));');
    log('');
    log('   await HHiveCore.initialize();');
    log('');

    // Part 2: Show post-init registration constraints
    log('2️⃣ Post-Init Registration Constraints:');
    log('');
    log('   BoxCollection type (default):');
    log('   • New boxes cannot be added to an opened collection');
    log('   • But NEW envs can reuse EXISTING boxes in opened collection');
    log('');
    log('   HiveBoxType.box:');
    log('   • No registration constraint - boxes open lazily');
    log('   • Ideal for dynamic scenarios like createFromConfig()');
    log('');
    
    // Demonstrate reusing existing box works
    try {
      // This should work - 'demo' box exists in 'hivehook_demo' collection
      HHiveCore.register(HiveConfig(
        env: 'demo_alias_${DateTime.now().millisecondsSinceEpoch}',
        boxName: 'demo', // Same box as main demo
        boxCollectionName: 'hivehook_demo',
      ));
      log('   ✓ Reusing existing box in opened collection: works!', level: LogLevel.success);
    } catch (e) {
      log('   ✗ Unexpected error: $e', level: LogLevel.error);
    }
    
    // Demonstrate adding NEW box to opened collection fails
    try {
      HHiveCore.register(HiveConfig(
        env: 'new_box_env_${DateTime.now().millisecondsSinceEpoch}',
        boxName: 'brand_new_box', // New box - should fail
        boxCollectionName: 'hivehook_demo',
      ));
      log('   ✗ Should have thrown!', level: LogLevel.error);
    } on StateError catch (e) {
      log('   ✓ Adding new box to opened collection: correctly throws', level: LogLevel.success);
      log('     "${e.message.substring(0, 60)}..."', level: LogLevel.data);
    }
    log('');

    // Part 3: Demonstrate env isolation using existing demo env
    log('3️⃣ Env Isolation (using existing demo env):');
    log('');

    final hive = await HHive.create('demo');

    // Show how keys are prefixed internally
    await hive.put('user:alice', {'name': 'Alice', 'role': 'admin'});
    await hive.put('user:bob', {'name': 'Bob', 'role': 'user'});

    log('   Stored 2 users with env prefix:');
    log('   • "demo::user:alice" → {name: Alice, role: admin}');
    log('   • "demo::user:bob" → {name: Bob, role: user}');
    log('');

    // Show key iteration (transparent - no prefix visible)
    final keys = await hive.keys().toList();
    log('   hive.keys() returns (prefix stripped):');
    for (final key in keys.where((k) => k.startsWith('user:'))) {
      final value = await hive.get(key);
      log('   • "$key" → $value');
    }
    log('');

    // Part 4: Explain shared boxName pattern
    log('4️⃣ Shared BoxName Pattern:');
    log('');
    log('   // Two envs sharing same physical box:');
    log('   HiveConfig(env: "v1", boxName: "users")');
    log('   HiveConfig(env: "v2", boxName: "users")');
    log('');
    log('   // Storage layout in box "users":');
    log('   //   v1::alice → {...}');
    log('   //   v1::bob → {...}');
    log('   //   v2::alice → {...}  // No collision!');
    log('');
    log('   // Each HHive only sees its own keys:');
    log('   // v1.keys() → [alice, bob]');
    log('   // v2.keys() → [alice]');
    log('');

    // Part 5: Show boxName defaults to env
    log('5️⃣ BoxName Defaults:');
    log('');
    log('   HiveConfig(env: "users")');
    log('   // boxName defaults to "users"');
    log('');
    log('   HiveConfig(env: "users_v2", boxName: "users")');
    log('   // Explicitly uses "users" box');
    log('');

    // Cleanup
    await hive.delete('user:alice');
    await hive.delete('user:bob');

    log('6️⃣ Summary:');
    log('');
    log('   BoxCollection (default):');
    log('   • Register configs before initialize() for new boxes');
    log('   • New envs can reuse existing boxes after init');
    log('   • Group related envs in same boxCollectionName');
    log('');
    log('   HiveBoxType.box:');
    log('   • Use for dynamic/on-demand box creation');
    log('   • No upfront registration required');
    log('');
    log('   Both types:');
    log('   • Keys auto-prefixed with env:: for isolation');
    log('   • Users see clean keys (prefix is transparent)');
  }
}
