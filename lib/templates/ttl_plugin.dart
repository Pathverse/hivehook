import 'package:hivehook/core/enums.dart';
import 'package:hivehook/core/latch.dart';
import 'package:hivehook/core/i_ctx.dart';
import 'package:hivehook/hooks/action_hook.dart';
import 'package:hivehook/helper/plugin.dart';

/// TTL (Time-To-Live) Plugin
///
/// Automatically manages data expiration based on time-to-live values stored in metadata.
/// When data is read, checks if it has exceeded its TTL and returns null if expired.
///
/// Usage:
/// ```dart
/// final ttlPlugin = createTTLPlugin(
///   defaultTTLSeconds: 3600, // 1 hour default
/// );
///
/// final config = HHConfig(env: 'app', usesMeta: true);
/// config.installPlugin(ttlPlugin);
///
/// // Set data with TTL
/// await hive.put('key', 'value', meta: {'ttl': '60'}); // 60 seconds
///
/// // Or uses default TTL if not specified
/// await hive.put('key2', 'value2');
/// ```
HHPlugin createTTLPlugin({int defaultTTLSeconds = 3600}) {
  return HHPlugin(
    actionHooks: [
      // Set TTL on write
      HActionHook(
        latches: [
          HHLatch.pre(triggerType: TriggerType.valueWrite, priority: 100),
        ],
        action: (ctx) async {
          final existingMeta = ctx.payload.metadata ?? {};
          final meta = Map<String, dynamic>.from(existingMeta);

          // If no TTL specified, use default
          if (!meta.containsKey('ttl')) {
            meta['ttl'] = defaultTTLSeconds.toString();
          }

          // Set creation timestamp
          meta['created_at'] = DateTime.now().millisecondsSinceEpoch.toString();

          ctx.payload = ctx.payload.copyWith(metadata: meta);
        },
      ),

      // Check TTL on read (pre-hook to prevent reading expired data)
      HActionHook(
        latches: [
          HHLatch.pre(triggerType: TriggerType.valueRead, priority: 100),
        ],
        action: (ctx) async {
          // Get metadata to check TTL
          final meta = await ctx.access.metaGet(ctx.payload.key!);
          if (meta == null) return; // No metadata, allow read

          final ttlValue = meta['ttl'];
          final createdAtValue = meta['created_at'];

          if (ttlValue == null || createdAtValue == null) return; // No TTL info

          // Support both int and string TTL values
          final ttl = ttlValue is int
              ? ttlValue
              : int.tryParse(ttlValue.toString());
          final createdAt = createdAtValue is int
              ? createdAtValue
              : int.tryParse(createdAtValue.toString());

          if (ttl == null || createdAt == null) return;

          // Check if expired
          final now = DateTime.now().millisecondsSinceEpoch;
          final expiresAt = createdAt + (ttl * 1000);

          if (now > expiresAt) {
            // Delete expired data
            await ctx.access.storeDelete(ctx.payload.key!);
            await ctx.access.metaDelete(ctx.payload.key!);

            // Skip the read and return null using HHCtrlException
            throw HHCtrlException(
              nextPhase: NextPhase.f_break,
              returnValue: null,
            );
          }
        },
      ),
    ],
  );
}
