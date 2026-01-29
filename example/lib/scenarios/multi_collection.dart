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

    // Part 2: Show post-init registration error
    log('2️⃣ Post-Init Registration (throws error):');
    log('');
    try {
      HHiveCore.register(HiveConfig(
        env: 'late_env',
        boxCollectionName: 'new_collection',
      ));
      log('   ✗ Should have thrown!', level: LogLevel.error);
    } on StateError catch (e) {
      log('   ✓ Correctly throws StateError:', level: LogLevel.success);
      log('   "${e.message}"');
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
    log('   • Register all BoxCollection configs before initialize()');
    log('   • Group related envs in same boxCollectionName');
    log('   • Use boxName to share physical boxes between envs');
    log('   • Keys are auto-prefixed with env:: for isolation');
    log('   • Users see clean keys (prefix is transparent)');
  }
}
