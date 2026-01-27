import 'package:flutter/material.dart';
import '../models/log_entry.dart';
import '../services/hive_service.dart';

/// Combined plugins test panel (TTL + LRU + Validation)
class ComboTestPanel extends StatefulWidget {
  final LogController log;

  const ComboTestPanel({super.key, required this.log});

  @override
  State<ComboTestPanel> createState() => _ComboTestPanelState();
}

class _ComboTestPanelState extends State<ComboTestPanel> {
  final keyController = TextEditingController(text: 'combo_item');
  final valueController = TextEditingController(text: 'test data');
  final ttlController = TextEditingController(text: '30');

  @override
  void dispose() {
    keyController.dispose();
    valueController.dispose();
    ttlController.dispose();
    super.dispose();
  }

  Future<void> _put() async {
    try {
      final ttl = int.tryParse(ttlController.text) ?? 30;
      await HiveService.comboHive.put(
        keyController.text,
        valueController.text,
        meta: {'ttl': ttl},
      );
      widget.log.success(
        'PUT "${keyController.text}" with TTL=${ttl}s (validated ✓)',
        category: 'combo',
      );
    } catch (e) {
      widget.log.error('PUT failed: $e', category: 'combo');
    }
  }

  Future<void> _putNull() async {
    try {
      await HiveService.comboHive.put(keyController.text, null);
      widget.log.error('Should have failed validation!', category: 'combo');
    } catch (e) {
      widget.log.warning('Validation blocked null value: $e', category: 'combo');
    }
  }

  Future<void> _get() async {
    try {
      final value = await HiveService.comboHive.get(keyController.text);
      if (value != null) {
        widget.log.success('GET "${keyController.text}" → "$value"', category: 'combo');
      } else {
        widget.log.warning('GET "${keyController.text}" → null', category: 'combo');
      }
    } catch (e) {
      widget.log.error('GET failed: $e', category: 'combo');
    }
  }

  Future<void> _listAll() async {
    try {
      final keys = await HiveService.comboHive.keys().toList();
      widget.log.info('Cache (${keys.length}/10): ${keys.isEmpty ? "(empty)" : keys.join(", ")}', category: 'combo');
    } catch (e) {
      widget.log.error('LIST failed: $e', category: 'combo');
    }
  }

  Future<void> _fillCache() async {
    widget.log.info('--- Filling cache with 12 items (max: 10) ---', category: 'combo');
    for (var i = 1; i <= 12; i++) {
      try {
        await HiveService.comboHive.put(
          'item_$i',
          'value_$i',
          meta: {'ttl': 60},
        );
        widget.log.info('Added item_$i', category: 'combo');
      } catch (e) {
        widget.log.error('Failed: $e', category: 'combo');
      }
      await Future.delayed(const Duration(milliseconds: 100));
    }
    await _listAll();
    widget.log.success('LRU should have evicted 2 oldest items!', category: 'combo');
  }

  Future<void> _clear() async {
    try {
      await HiveService.comboHive.clear();
      widget.log.success('CLEAR - all data deleted', category: 'combo');
    } catch (e) {
      widget.log.error('CLEAR failed: $e', category: 'combo');
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
            'Combined Plugins',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'TTL (30s) + LRU (max 10) + Validation (no nulls)',
            style: TextStyle(color: Colors.grey[400]),
          ),
          const SizedBox(height: 8),

          // Active plugins badges
          Wrap(
            spacing: 8,
            children: [
              _badge('TTL: 30s', Colors.orange),
              _badge('LRU: 10 items', Colors.blue),
              _badge('Validation', Colors.green),
            ],
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
              const SizedBox(width: 16),
              SizedBox(
                width: 100,
                child: TextField(
                  controller: ttlController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'TTL (s)',
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
                onPressed: _listAll,
                icon: const Icon(Icons.list),
                label: const Text('LIST'),
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

          // Demos
          Text(
            'Demos',
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
                onPressed: _putNull,
                icon: const Icon(Icons.block),
                label: const Text('Try PUT null (test validation)'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.orange[700],
                ),
              ),
              FilledButton.icon(
                onPressed: _fillCache,
                icon: const Icon(Icons.add_box),
                label: const Text('Fill Cache (test LRU eviction)'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 12, color: color),
      ),
    );
  }
}
