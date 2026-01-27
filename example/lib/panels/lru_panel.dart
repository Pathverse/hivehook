import 'package:flutter/material.dart';
import '../models/log_entry.dart';
import '../services/hive_service.dart';

/// LRU Plugin test panel
class LRUTestPanel extends StatefulWidget {
  final LogController log;

  const LRUTestPanel({super.key, required this.log});

  @override
  State<LRUTestPanel> createState() => _LRUTestPanelState();
}

class _LRUTestPanelState extends State<LRUTestPanel> {
  final keyController = TextEditingController(text: 'item');
  final valueController = TextEditingController(text: 'data');
  int _counter = 1;

  @override
  void dispose() {
    keyController.dispose();
    valueController.dispose();
    super.dispose();
  }

  Future<void> _put() async {
    try {
      await HiveService.lruHive.put(keyController.text, valueController.text);
      widget.log.success('PUT "${keyController.text}" = "${valueController.text}"', category: 'lru');
      await _listKeys();
    } catch (e) {
      widget.log.error('PUT failed: $e', category: 'lru');
    }
  }

  Future<void> _get() async {
    try {
      final value = await HiveService.lruHive.get(keyController.text);
      if (value != null) {
        widget.log.success('GET "${keyController.text}" → "$value" (access updated)', category: 'lru');
      } else {
        widget.log.warning('GET "${keyController.text}" → null (evicted or not found)', category: 'lru');
      }
    } catch (e) {
      widget.log.error('GET failed: $e', category: 'lru');
    }
  }

  Future<void> _listKeys() async {
    try {
      final keys = await HiveService.lruHive.keys().toList();
      widget.log.info('Cache (${keys.length}/5): ${keys.isEmpty ? "(empty)" : keys.join(", ")}', category: 'lru');
    } catch (e) {
      widget.log.error('LIST failed: $e', category: 'lru');
    }
  }

  Future<void> _addMultiple() async {
    widget.log.info('--- Adding 7 items (max size: 5) ---', category: 'lru');
    for (var i = 0; i < 7; i++) {
      final key = 'item_$_counter';
      await HiveService.lruHive.put(key, 'value_$_counter');
      widget.log.info('Added "$key"', category: 'lru');
      _counter++;
      await Future.delayed(const Duration(milliseconds: 100));
    }
    await _listKeys();
    widget.log.success('Oldest items should be evicted!', category: 'lru');
  }

  Future<void> _clear() async {
    try {
      await HiveService.lruHive.clear();
      widget.log.success('CLEAR - cache emptied', category: 'lru');
    } catch (e) {
      widget.log.error('CLEAR failed: $e', category: 'lru');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'LRU Plugin',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Least Recently Used eviction when cache exceeds max size (5 items).',
            style: TextStyle(color: Colors.grey[400]),
          ),
          const SizedBox(height: 24),

          // Input fields
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: keyController,
                  decoration: const InputDecoration(
                    labelText: 'Key',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: valueController,
                  decoration: const InputDecoration(
                    labelText: 'Value',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Action buttons
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.icon(
                onPressed: _put,
                icon: const Icon(Icons.save),
                label: const Text('PUT'),
              ),
              FilledButton.tonalIcon(
                onPressed: _get,
                icon: const Icon(Icons.search),
                label: const Text('GET'),
              ),
              OutlinedButton.icon(
                onPressed: _listKeys,
                icon: const Icon(Icons.list),
                label: const Text('LIST KEYS'),
              ),
              TextButton.icon(
                onPressed: _clear,
                icon: const Icon(Icons.clear_all),
                label: const Text('CLEAR'),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
              ),
            ],
          ),

          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 16),

          // Quick demo
          Text(
            'Quick Demo',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey[300],
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _addMultiple,
            icon: const Icon(Icons.add_box),
            label: const Text('Add 7 Items (watch eviction)'),
          ),
        ],
      ),
    );
  }
}
