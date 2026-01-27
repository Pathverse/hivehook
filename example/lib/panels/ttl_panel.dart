import 'dart:async';
import 'package:flutter/material.dart';
import '../models/log_entry.dart';
import '../services/hive_service.dart';

/// TTL Plugin test panel
class TTLTestPanel extends StatefulWidget {
  final LogController log;

  const TTLTestPanel({super.key, required this.log});

  @override
  State<TTLTestPanel> createState() => _TTLTestPanelState();
}

class _TTLTestPanelState extends State<TTLTestPanel> {
  final keyController = TextEditingController(text: 'session');
  final valueController = TextEditingController(text: 'user_token_abc123');
  final ttlController = TextEditingController(text: '5');
  Timer? _countdownTimer;
  int _countdown = 0;

  @override
  void dispose() {
    keyController.dispose();
    valueController.dispose();
    ttlController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdown(int seconds) {
    _countdownTimer?.cancel();
    setState(() => _countdown = seconds);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _countdown--;
        if (_countdown <= 0) {
          timer.cancel();
          widget.log.warning('⏰ TTL expired for "${keyController.text}"', category: 'ttl');
        }
      });
    });
  }

  Future<void> _putWithTTL() async {
    try {
      final ttl = int.tryParse(ttlController.text) ?? 5;
      await HiveService.ttlHive.put(
        keyController.text,
        valueController.text,
        meta: {'ttl': ttl},
      );
      widget.log.success(
        'PUT "${keyController.text}" with TTL=${ttl}s',
        category: 'ttl',
      );
      _startCountdown(ttl);
    } catch (e) {
      widget.log.error('PUT failed: $e', category: 'ttl');
    }
  }

  Future<void> _get() async {
    try {
      final value = await HiveService.ttlHive.get(keyController.text);
      if (value != null) {
        widget.log.success('GET "${keyController.text}" → "$value"', category: 'ttl');
      } else {
        widget.log.warning('GET "${keyController.text}" → null (expired or not found)', category: 'ttl');
        _countdownTimer?.cancel();
        setState(() => _countdown = 0);
      }
    } catch (e) {
      widget.log.error('GET failed: $e', category: 'ttl');
    }
  }

  Future<void> _getMeta() async {
    try {
      final meta = await HiveService.ttlHive.getMeta(keyController.text);
      if (meta != null) {
        widget.log.info('META "${keyController.text}" → $meta', category: 'ttl');
      } else {
        widget.log.warning('META "${keyController.text}" → null', category: 'ttl');
      }
    } catch (e) {
      widget.log.error('GET META failed: $e', category: 'ttl');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'TTL Plugin',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              if (_countdown > 0) ...[
                const SizedBox(width: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _countdown <= 2 ? Colors.red : Colors.orange,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'Expires in ${_countdown}s',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Automatically expires entries after specified TTL (default: 10s).',
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
                onPressed: _putWithTTL,
                icon: const Icon(Icons.timer),
                label: const Text('PUT with TTL'),
              ),
              FilledButton.tonalIcon(
                onPressed: _get,
                icon: const Icon(Icons.search),
                label: const Text('GET'),
              ),
              OutlinedButton.icon(
                onPressed: _getMeta,
                icon: const Icon(Icons.info_outline),
                label: const Text('GET META'),
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
            onPressed: () async {
              widget.log.info('--- Starting TTL Demo ---', category: 'ttl');
              await HiveService.ttlHive.put('demo_key', 'This will expire!', meta: {'ttl': 3});
              widget.log.success('Stored "demo_key" with 3s TTL', category: 'ttl');
              
              await Future.delayed(const Duration(seconds: 1));
              var val = await HiveService.ttlHive.get('demo_key');
              widget.log.info('After 1s: $val', category: 'ttl');
              
              await Future.delayed(const Duration(seconds: 3));
              val = await HiveService.ttlHive.get('demo_key');
              widget.log.info('After 4s: ${val ?? "(expired)"}', category: 'ttl');
              widget.log.info('--- TTL Demo Complete ---', category: 'ttl');
            },
            icon: const Icon(Icons.play_arrow),
            label: const Text('Run 3s TTL Demo'),
          ),
        ],
      ),
    );
  }
}
