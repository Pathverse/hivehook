import 'package:flutter/material.dart';
import 'package:hivehook/hivehook.dart';

import 'scenarios/scenario.dart';
import 'scenarios/ecommerce_order.dart';
import 'scenarios/social_media_feed.dart';
import 'scenarios/config_management.dart';
import 'scenarios/hook_pipeline.dart';
import 'scenarios/ttl_expiration.dart';
import 'scenarios/batch_operations.dart';
import 'scenarios/multi_collection.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize HiveHook
  HHiveCore.register(HiveConfig(
    env: 'demo',
    boxCollectionName: 'hivehook_demo',
    withMeta: true,
  ));

  await HHiveCore.initialize();

  runApp(const HivehookDemoApp());
}

class HivehookDemoApp extends StatelessWidget {
  const HivehookDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hivehook Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.dark,
        ),
      ),
      home: const DemoHomePage(),
    );
  }
}

class DemoHomePage extends StatefulWidget {
  const DemoHomePage({super.key});

  @override
  State<DemoHomePage> createState() => _DemoHomePageState();
}

class _DemoHomePageState extends State<DemoHomePage> {
  final List<Scenario> scenarios = [
    EcommerceOrderScenario(),
    SocialMediaFeedScenario(),
    ConfigManagementScenario(),
    HookPipelineScenario(),
    TtlExpirationScenario(),
    BatchOperationsScenario(),
    MultiCollectionScenario(),
  ];

  Scenario? selectedScenario;
  final List<LogEntry> logs = [];
  bool isRunning = false;

  void _log(String message, {LogLevel level = LogLevel.info}) {
    setState(() {
      logs.add(LogEntry(
        timestamp: DateTime.now(),
        message: message,
        level: level,
      ));
    });
  }

  void _clearLogs() {
    setState(() {
      logs.clear();
    });
  }

  Future<void> _runScenario() async {
    if (selectedScenario == null || isRunning) return;

    setState(() {
      isRunning = true;
    });

    _log('▶ Starting: ${selectedScenario!.name}', level: LogLevel.header);
    _log('━' * 50);

    try {
      await selectedScenario!.run(_log);
      _log('━' * 50);
      _log('✓ Completed successfully', level: LogLevel.success);
    } catch (e, stack) {
      _log('━' * 50);
      _log('✗ Error: $e', level: LogLevel.error);
      _log('Stack: $stack', level: LogLevel.error);
    } finally {
      setState(() {
        isRunning = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Left sidebar - Scenario library
          Container(
            width: 300,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              border: Border(
                right: BorderSide(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.storage_rounded,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Hivehook Demo',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                ),

                // Scenario list
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: scenarios.length,
                    itemBuilder: (context, index) {
                      final scenario = scenarios[index];
                      final isSelected = scenario == selectedScenario;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        color: isSelected
                            ? Theme.of(context).colorScheme.primaryContainer
                            : null,
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              selectedScenario = scenario;
                            });
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      scenario.icon,
                                      size: 20,
                                      color: isSelected
                                          ? Theme.of(context)
                                              .colorScheme
                                              .onPrimaryContainer
                                          : Theme.of(context)
                                              .colorScheme
                                              .primary,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        scenario.name,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: isSelected
                                              ? Theme.of(context)
                                                  .colorScheme
                                                  .onPrimaryContainer
                                              : null,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  scenario.description,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: isSelected
                                            ? Theme.of(context)
                                                .colorScheme
                                                .onPrimaryContainer
                                                .withValues(alpha: 0.8)
                                            : Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant,
                                      ),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 4,
                                  runSpacing: 4,
                                  children: scenario.tags
                                      .map((tag) => Chip(
                                            label: Text(
                                              tag,
                                              style:
                                                  const TextStyle(fontSize: 10),
                                            ),
                                            padding: EdgeInsets.zero,
                                            labelPadding:
                                                const EdgeInsets.symmetric(
                                                    horizontal: 6),
                                            visualDensity:
                                                VisualDensity.compact,
                                          ))
                                      .toList(),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // Right side - Log output
          Expanded(
            child: Column(
              children: [
                // Toolbar
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    border: Border(
                      bottom: BorderSide(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      if (selectedScenario != null) ...[
                        Icon(selectedScenario!.icon,
                            color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          selectedScenario!.name,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                      ] else
                        Text(
                          'Select a scenario',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                color:
                                    Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: _clearLogs,
                        icon: const Icon(Icons.clear_all),
                        label: const Text('Clear'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed:
                            selectedScenario != null && !isRunning ? _runScenario : null,
                        icon: isRunning
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.play_arrow),
                        label: Text(isRunning ? 'Running...' : 'Run'),
                      ),
                    ],
                  ),
                ),

                // Log output
                Expanded(
                  child: Container(
                    color: const Color(0xFF1E1E1E),
                    child: logs.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.terminal,
                                  size: 64,
                                  color: Colors.grey[700],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Select a scenario and click Run',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: logs.length,
                            itemBuilder: (context, index) {
                              final log = logs[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 2),
                                child: SelectableText.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(
                                        text:
                                            '[${_formatTime(log.timestamp)}] ',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontFamily: 'monospace',
                                          fontSize: 13,
                                        ),
                                      ),
                                      TextSpan(
                                        text: log.message,
                                        style: TextStyle(
                                          color: log.level.color,
                                          fontFamily: 'monospace',
                                          fontSize: 13,
                                          fontWeight: log.level == LogLevel.header
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}:'
        '${time.second.toString().padLeft(2, '0')}.'
        '${time.millisecond.toString().padLeft(3, '0')}';
  }
}

class LogEntry {
  final DateTime timestamp;
  final String message;
  final LogLevel level;

  LogEntry({
    required this.timestamp,
    required this.message,
    required this.level,
  });
}

enum LogLevel {
  info(Color(0xFFCCCCCC)),
  success(Color(0xFF4EC9B0)),
  warning(Color(0xFFDCDCAA)),
  error(Color(0xFFF14C4C)),
  header(Color(0xFF569CD6)),
  data(Color(0xFFCE9178));

  final Color color;
  const LogLevel(this.color);
}
