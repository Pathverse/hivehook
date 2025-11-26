import 'package:hivehook/core/enums.dart';
import 'package:hivehook/core/latch.dart';
import 'package:hivehook/hooks/action_hook.dart';
import 'package:hivehook/helper/plugin.dart';

/// LRU (Least Recently Used) Cache Plugin
///
/// Maintains a cache with a maximum size, evicting the least recently used items
/// when the cache is full. Uses metadata to track access timestamps and manages
/// eviction automatically.
///
/// Usage:
/// ```dart
/// final lruPlugin = createLRUPlugin(
///   maxSize: 100, // Maximum 100 items in cache
/// );
///
/// final config = HHConfig(env: 'app', usesMeta: true);
/// config.installPlugin(lruPlugin);
///
/// // Use normally - plugin handles eviction automatically
/// await hive.put('key1', 'value1');
/// await hive.get('key1'); // Updates access time
/// ```
HHPlugin createLRUPlugin({required int maxSize}) {
  if (maxSize <= 0) {
    throw ArgumentError('maxSize must be greater than 0');
  }

  return HHPlugin(
    actionHooks: [
      // Update access time on read (pre-hook so it happens before eviction checks)
      HActionHook(
        latches: [
          HHLatch.pre(
            triggerType: TriggerType.valueRead,
            priority: 95, // Higher priority than write check
          ),
        ],
        action: (ctx) async {
          // Update last accessed timestamp for this key
          final existingMeta = await ctx.access.metaGet(ctx.payload.key!) ?? {};
          final meta = Map<String, dynamic>.from(existingMeta);
          meta['last_accessed'] = DateTime.now().millisecondsSinceEpoch
              .toString();

          await ctx.access.metaPut(ctx.payload.key!, meta);
        },
      ),

      // Check cache size and evict LRU on write
      HActionHook(
        latches: [
          HHLatch.pre(triggerType: TriggerType.valueWrite, priority: 90),
        ],
        action: (ctx) async {
          // Set access time for new entry
          final existingMeta = ctx.payload.metadata ?? {};
          final meta = Map<String, dynamic>.from(existingMeta);
          meta['last_accessed'] = DateTime.now().millisecondsSinceEpoch
              .toString();
          ctx.payload = ctx.payload.copyWith(metadata: meta);

          // Get cache index from metadata key '_lru_cache_keys'
          final cacheIndexMeta = await ctx.access.metaGet('_lru_cache_keys');
          final keysString = cacheIndexMeta?['keys'] as String?;
          var cacheKeys =
              keysString?.split(',').where((k) => k.isNotEmpty).toList() ??
              <String>[];

          // Check if current key already exists
          final keyExists = cacheKeys.contains(ctx.payload.key);

          // Remove current key if it exists (will be re-added)
          if (keyExists) {
            cacheKeys.remove(ctx.payload.key);
          }

          // Check if we need to evict (only if adding a NEW key)
          if (!keyExists && cacheKeys.length >= maxSize) {
            // Find LRU item (oldest access time)
            String? lruKey;
            int? oldestAccess;

            for (final key in cacheKeys) {
              final itemMeta = await ctx.access.metaGet(key);
              if (itemMeta == null) continue;

              final lastAccessedStr = itemMeta['last_accessed'];
              if (lastAccessedStr == null) continue;

              final lastAccessed = int.tryParse(lastAccessedStr);
              if (lastAccessed == null) continue;

              if (oldestAccess == null || lastAccessed < oldestAccess) {
                oldestAccess = lastAccessed;
                lruKey = key;
              }
            }

            // Evict LRU item
            if (lruKey != null) {
              await ctx.access.storeDelete(lruKey);
              await ctx.access.metaDelete(lruKey);
              cacheKeys.remove(lruKey);
            }
          }

          // Add current key to cache index
          cacheKeys.add(ctx.payload.key!);
          await ctx.access.metaPut('_lru_cache_keys', {
            'keys': cacheKeys.join(','),
          });
        },
      ),
    ],
  );
}
