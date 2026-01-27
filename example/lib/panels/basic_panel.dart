import 'package:flutter/material.dart';
import '../models/log_entry.dart';
import '../services/hive_service.dart';

/// Basic CRUD test panel
class BasicTestPanel extends StatefulWidget {
  final LogController log;

  const BasicTestPanel({super.key, required this.log});

  @override
  State<BasicTestPanel> createState() => _BasicTestPanelState();
}

class _BasicTestPanelState extends State<BasicTestPanel> {
  final keyController = TextEditingController(text: 'myKey');
  final valueController = TextEditingController(text: 'Hello HiveHook!');

  @override
  void dispose() {
    keyController.dispose();
    valueController.dispose();
    super.dispose();
  }

  Future<void> _put() async {
    try {
      await HiveService.basicHive.put(keyController.text, valueController.text);
      widget.log.success('PUT "${keyController.text}" = "${valueController.text}"', category: 'basic');
    } catch (e) {
      widget.log.error('PUT failed: $e', category: 'basic');
    }
  }

  Future<void> _get() async {
    try {
      final value = await HiveService.basicHive.get(keyController.text);
      if (value != null) {
        widget.log.success('GET "${keyController.text}" → "$value"', category: 'basic');
      } else {
        widget.log.warning('GET "${keyController.text}" → null (not found)', category: 'basic');
      }
    } catch (e) {
      widget.log.error('GET failed: $e', category: 'basic');
    }
  }

  Future<void> _delete() async {
    try {
      await HiveService.basicHive.delete(keyController.text);
      widget.log.success('DELETE "${keyController.text}"', category: 'basic');
    } catch (e) {
      widget.log.error('DELETE failed: $e', category: 'basic');
    }
  }

  Future<void> _listAll() async {
    try {
      final keys = await HiveService.basicHive.keys().toList();
      widget.log.info('All keys: ${keys.isEmpty ? "(empty)" : keys.join(", ")}', category: 'basic');
    } catch (e) {
      widget.log.error('LIST failed: $e', category: 'basic');
    }
  }

  Future<void> _clear() async {
    try {
      await HiveService.basicHive.clear();
      widget.log.success('CLEAR - all data deleted', category: 'basic');
    } catch (e) {
      widget.log.error('CLEAR failed: $e', category: 'basic');
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
            'Basic CRUD Operations',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Simple key-value storage without any plugins.',
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
                onPressed: _delete,
                icon: const Icon(Icons.delete),
                label: const Text('DELETE'),
              ),
              OutlinedButton.icon(
                onPressed: _listAll,
                icon: const Icon(Icons.list),
                label: const Text('LIST ALL'),
              ),
              TextButton.icon(
                onPressed: _clear,
                icon: const Icon(Icons.clear_all),
                label: const Text('CLEAR'),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
