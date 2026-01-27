import 'package:flutter/material.dart';
import '../models/log_entry.dart';
import '../models/sample_data.dart';
import '../services/hive_service.dart';

/// Complex Objects test panel with User, Product, Session models
class JsonTestPanel extends StatefulWidget {
  final LogController log;

  const JsonTestPanel({super.key, required this.log});

  @override
  State<JsonTestPanel> createState() => _JsonTestPanelState();
}

class _JsonTestPanelState extends State<JsonTestPanel> {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Complex Objects',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Store and retrieve complex objects with nested data.',
            style: TextStyle(color: Colors.grey[400]),
          ),
          const SizedBox(height: 32),

          // User section
          _buildSection(
            title: '👤 User Model',
            description: 'Nested address, roles array, timestamps',
            onStore: _storeUser,
            onRetrieve: _retrieveUser,
          ),

          const SizedBox(height: 24),

          // Product section
          _buildSection(
            title: '📦 Product Model',
            description: 'Price, quantity, tags, nested attributes',
            onStore: _storeProduct,
            onRetrieve: _retrieveProduct,
          ),

          const SizedBox(height: 24),

          // Session section
          _buildSection(
            title: '🔐 Session Model',
            description: 'Token, expiration, permissions map',
            onStore: _storeSession,
            onRetrieve: _retrieveSession,
          ),

          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 16),

          // Bulk operations
          Text(
            'Bulk Operations',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey[300],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.icon(
                onPressed: _storeAll,
                icon: const Icon(Icons.save_alt),
                label: const Text('Store All Sample Data'),
              ),
              OutlinedButton.icon(
                onPressed: _listAll,
                icon: const Icon(Icons.list),
                label: const Text('List All Keys'),
              ),
              TextButton.icon(
                onPressed: _clearAll,
                icon: const Icon(Icons.clear_all),
                label: const Text('Clear All'),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required String description,
    required VoidCallback onStore,
    required VoidCallback onRetrieve,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[700]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: TextStyle(color: Colors.grey[500], fontSize: 13),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              FilledButton.icon(
                onPressed: onStore,
                icon: const Icon(Icons.save, size: 18),
                label: const Text('Store'),
              ),
              const SizedBox(width: 12),
              FilledButton.tonalIcon(
                onPressed: onRetrieve,
                icon: const Icon(Icons.download, size: 18),
                label: const Text('Retrieve'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _storeUser() async {
    try {
      final user = SampleData.sampleUser();
      await HiveService.jsonHive.put('user_sample', user.toJson());
      widget.log.success('Stored User: ${user.name}', category: 'json');
      widget.log.info('  → email: ${user.email}', category: 'json');
      widget.log.info('  → address: ${user.address}', category: 'json');
      widget.log.info('  → roles: ${user.roles.join(", ")}', category: 'json');
    } catch (e) {
      widget.log.error('Store User failed: $e', category: 'json');
    }
  }

  Future<void> _retrieveUser() async {
    try {
      final data = await HiveService.jsonHive.get('user_sample');
      if (data != null) {
        final user = User.fromJson(data as Map<String, dynamic>);
        widget.log.success('Retrieved User: ${user.name}', category: 'json');
        widget.log.info('  → email: ${user.email}', category: 'json');
        widget.log.info('  → age: ${user.age}', category: 'json');
        widget.log.info('  → address: ${user.address}', category: 'json');
      } else {
        widget.log.warning('User not found', category: 'json');
      }
    } catch (e) {
      widget.log.error('Retrieve User failed: $e', category: 'json');
    }
  }

  Future<void> _storeProduct() async {
    try {
      final product = SampleData.sampleProduct();
      await HiveService.jsonHive.put('product_sample', product.toJson());
      widget.log.success('Stored Product: ${product.name}', category: 'json');
      widget.log.info('  → price: \$${product.price}', category: 'json');
      widget.log.info('  → tags: ${product.tags.join(", ")}', category: 'json');
      widget.log.info('  → attributes: ${product.attributes}', category: 'json');
    } catch (e) {
      widget.log.error('Store Product failed: $e', category: 'json');
    }
  }

  Future<void> _retrieveProduct() async {
    try {
      final data = await HiveService.jsonHive.get('product_sample');
      if (data != null) {
        final product = Product.fromJson(data as Map<String, dynamic>);
        widget.log.success('Retrieved Product: ${product.name}', category: 'json');
        widget.log.info('  → SKU: ${product.sku}', category: 'json');
        widget.log.info('  → price: \$${product.price}', category: 'json');
        widget.log.info('  → quantity: ${product.quantity}', category: 'json');
      } else {
        widget.log.warning('Product not found', category: 'json');
      }
    } catch (e) {
      widget.log.error('Retrieve Product failed: $e', category: 'json');
    }
  }

  Future<void> _storeSession() async {
    try {
      final session = SampleData.sampleSession(ttlSeconds: 300);
      await HiveService.jsonHive.put('session_sample', session.toJson());
      widget.log.success('Stored Session: ${session.token.substring(0, 20)}...', category: 'json');
      widget.log.info('  → userId: ${session.userId}', category: 'json');
      widget.log.info('  → expiresAt: ${session.expiresAt}', category: 'json');
      widget.log.info('  → permissions: ${session.permissions}', category: 'json');
    } catch (e) {
      widget.log.error('Store Session failed: $e', category: 'json');
    }
  }

  Future<void> _retrieveSession() async {
    try {
      final data = await HiveService.jsonHive.get('session_sample');
      if (data != null) {
        final session = Session.fromJson(data as Map<String, dynamic>);
        widget.log.success('Retrieved Session', category: 'json');
        widget.log.info('  → userId: ${session.userId}', category: 'json');
        widget.log.info('  → expired: ${session.isExpired}', category: 'json');
        widget.log.info('  → permissions: ${session.permissions}', category: 'json');
      } else {
        widget.log.warning('Session not found', category: 'json');
      }
    } catch (e) {
      widget.log.error('Retrieve Session failed: $e', category: 'json');
    }
  }

  Future<void> _storeAll() async {
    widget.log.info('--- Storing all sample data ---', category: 'json');
    await _storeUser();
    await _storeProduct();
    await _storeSession();
    widget.log.success('All sample data stored!', category: 'json');
  }

  Future<void> _listAll() async {
    try {
      final keys = await HiveService.jsonHive.keys().toList();
      widget.log.info('All keys: ${keys.isEmpty ? "(empty)" : keys.join(", ")}', category: 'json');
    } catch (e) {
      widget.log.error('List failed: $e', category: 'json');
    }
  }

  Future<void> _clearAll() async {
    try {
      await HiveService.jsonHive.clear();
      widget.log.success('All data cleared', category: 'json');
    } catch (e) {
      widget.log.error('Clear failed: $e', category: 'json');
    }
  }
}
