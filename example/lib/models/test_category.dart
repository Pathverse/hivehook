import 'package:flutter/material.dart';

/// Test category definition
class TestCategory {
  final String id;
  final String name;
  final String description;
  final IconData icon;

  const TestCategory({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
  });
}

/// Available test categories
class TestCategories {
  static const basic = TestCategory(
    id: 'basic',
    name: 'Basic CRUD',
    description: 'Simple put/get/delete operations',
    icon: Icons.storage,
  );

  static const ttl = TestCategory(
    id: 'ttl',
    name: 'TTL Plugin',
    description: 'Auto-expiring cache entries',
    icon: Icons.timer,
  );

  static const lru = TestCategory(
    id: 'lru',
    name: 'LRU Plugin',
    description: 'Least Recently Used eviction',
    icon: Icons.delete_sweep,
  );

  static const json = TestCategory(
    id: 'json',
    name: 'Complex Objects',
    description: 'User, Product, Session models',
    icon: Icons.data_object,
  );

  static const combo = TestCategory(
    id: 'combo',
    name: 'Combined Plugins',
    description: 'TTL + LRU + Validation',
    icon: Icons.layers,
  );

  static const custom = TestCategory(
    id: 'custom',
    name: 'Custom Playground',
    description: 'Freeform testing area',
    icon: Icons.science,
  );

  static List<TestCategory> get all => [basic, ttl, lru, json, combo, custom];
}
