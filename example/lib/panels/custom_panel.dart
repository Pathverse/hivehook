import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hivehook/hivehook.dart';
import '../models/log_entry.dart';
import '../services/hive_service.dart';

/// Custom playground for freeform testing
class CustomTestPanel extends StatefulWidget {
  final LogController log;

  const CustomTestPanel({super.key, required this.log});

  @override
  State<CustomTestPanel> createState() => _CustomTestPanelState();
}

class _CustomTestPanelState extends State<CustomTestPanel> {
  final codeController = TextEditingController(text: '''// Example operations
await hive.put('test', {'hello': 'world'});
final value = await hive.get('test');
print('Got: \$value');
''');

  String _selectedEnv = 'basic';
  final List<String> _envs = ['basic', 'ttl_demo', 'lru_demo', 'json_demo', 'combo_demo'];

  HHive get _currentHive => switch (_selectedEnv) {
        'basic' => HiveService.basicHive,
        'ttl_demo' => HiveService.ttlHive,
        'lru_demo' => HiveService.lruHive,
        'json_demo' => HiveService.jsonHive,
        'combo_demo' => HiveService.comboHive,
        _ => HiveService.basicHive,
      };

  @override
  void dispose() {
    codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Custom Playground',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Freeform testing area for experimenting with HiveHook.',
            style: TextStyle(color: Colors.grey[400]),
          ),
          const SizedBox(height: 24),

          // Environment selector
          Row(
            children: [
              const Text('Environment: '),
              const SizedBox(width: 12),
              DropdownButton<String>(
                value: _selectedEnv,
                items: _envs
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedEnv = v!),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Quick actions grid
          Text(
            'Quick Actions',
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
              _actionButton('Put String', Icons.text_fields, _putString),
              _actionButton('Put Map', Icons.data_object, _putMap),
              _actionButton('Put List', Icons.list, _putList),
              _actionButton('Put Nested', Icons.account_tree, _putNested),
              _actionButton('Get All', Icons.download, _getAll),
              _actionButton('List Keys', Icons.key, _listKeys),
              _actionButton('Clear', Icons.clear_all, _clear, isDestructive: true),
            ],
          ),

          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 16),

          // Debug info
          Text(
            'Debug Info',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey[300],
            ),
          ),
          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[850],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[700]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _infoRow('Debug Mode', HHiveCore.kDebugMode ? 'ON' : 'OFF'),
                _infoRow('DEBUG_OBJ', HHiveCore.DEBUG_OBJ ? 'ON' : 'OFF'),
                _infoRow('Current Env', _selectedEnv),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Stress test
          Text(
            'Stress Test',
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
                onPressed: () => _stressTest(10),
                icon: const Icon(Icons.speed),
                label: const Text('10 ops'),
              ),
              FilledButton.icon(
                onPressed: () => _stressTest(100),
                icon: const Icon(Icons.speed),
                label: const Text('100 ops'),
              ),
              FilledButton.icon(
                onPressed: () => _stressTest(1000),
                icon: const Icon(Icons.speed),
                label: const Text('1000 ops'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.orange[700],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionButton(
    String label,
    IconData icon,
    VoidCallback onPressed, {
    bool isDestructive = false,
  }) {
    if (isDestructive) {
      return OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
      );
    }
    return FilledButton.tonalIcon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: TextStyle(color: Colors.grey[500]),
          ),
          Text(
            value,
            style: const TextStyle(fontFamily: 'monospace'),
          ),
        ],
      ),
    );
  }

  Future<void> _putString() async {
    try {
      await _currentHive.put('test_string', 'Hello, HiveHook!');
      widget.log.success('PUT string: "Hello, HiveHook!"', category: 'custom');
    } catch (e) {
      widget.log.error('PUT failed: $e', category: 'custom');
    }
  }

  Future<void> _putMap() async {
    try {
      final data = {'name': 'John', 'age': 30, 'active': true};
      await _currentHive.put('test_map', jsonEncode(data));
      widget.log.success('PUT map: $data', category: 'custom');
    } catch (e) {
      widget.log.error('PUT failed: $e', category: 'custom');
    }
  }

  Future<void> _putList() async {
    try {
      final data = ['apple', 'banana', 'cherry', 1, 2, 3];
      await _currentHive.put('test_list', jsonEncode(data));
      widget.log.success('PUT list: $data', category: 'custom');
    } catch (e) {
      widget.log.error('PUT failed: $e', category: 'custom');
    }
  }

  Future<void> _putNested() async {
    try {
      final data = {
        'user': {
          'name': 'Alice',
          'contacts': [
            {'type': 'email', 'value': 'alice@example.com'},
            {'type': 'phone', 'value': '+1234567890'},
          ],
          'settings': {
            'theme': 'dark',
            'notifications': {'email': true, 'push': false},
          },
        },
      };
      await _currentHive.put('test_nested', jsonEncode(data));
      widget.log.success('PUT nested object', category: 'custom');
      widget.log.info('  → ${jsonEncode(data).substring(0, 60)}...', category: 'custom');
    } catch (e) {
      widget.log.error('PUT failed: $e', category: 'custom');
    }
  }

  Future<void> _getAll() async {
    try {
      widget.log.info('--- All entries ---', category: 'custom');
      await for (final entry in _currentHive.entries()) {
        widget.log.info('${entry.key}: ${entry.value}', category: 'custom');
      }
    } catch (e) {
      widget.log.error('GET ALL failed: $e', category: 'custom');
    }
  }

  Future<void> _listKeys() async {
    try {
      final keys = await _currentHive.keys().toList();
      widget.log.info('Keys: ${keys.isEmpty ? "(empty)" : keys.join(", ")}', category: 'custom');
    } catch (e) {
      widget.log.error('LIST failed: $e', category: 'custom');
    }
  }

  Future<void> _clear() async {
    try {
      await _currentHive.clear();
      widget.log.success('CLEAR - all data deleted', category: 'custom');
    } catch (e) {
      widget.log.error('CLEAR failed: $e', category: 'custom');
    }
  }

  Future<void> _stressTest(int count) async {
    widget.log.info('--- Stress test: $count operations ---', category: 'custom');
    final sw = Stopwatch()..start();

    for (var i = 0; i < count; i++) {
      await _currentHive.put('stress_$i', 'value_$i');
    }
    final writeTime = sw.elapsedMilliseconds;

    sw.reset();
    for (var i = 0; i < count; i++) {
      await _currentHive.get('stress_$i');
    }
    final readTime = sw.elapsedMilliseconds;

    sw.reset();
    for (var i = 0; i < count; i++) {
      await _currentHive.delete('stress_$i');
    }
    final deleteTime = sw.elapsedMilliseconds;

    widget.log.success(
      'Completed $count ops: write=${writeTime}ms, read=${readTime}ms, delete=${deleteTime}ms',
      category: 'custom',
    );
    widget.log.info(
      'Avg: write=${(writeTime / count).toStringAsFixed(2)}ms, read=${(readTime / count).toStringAsFixed(2)}ms',
      category: 'custom',
    );
  }
}
