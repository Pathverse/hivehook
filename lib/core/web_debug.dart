/// Web debug storage for HiveHook.
/// 
/// On web: Stores objects directly in `window.hiveDebug` for easy DevTools inspection.
/// On other platforms: No-op (debug storage only available on web).
/// 
/// Usage in browser console:
/// ```js
/// // View all stored objects
/// console.log(window.hiveDebug);
/// 
/// // View specific key
/// console.log(window.hiveDebug['myEnv::myKey']);
/// 
/// // List all keys
/// Object.keys(window.hiveDebug);
/// ```
library;

export 'web_debug_stub.dart' if (dart.library.js_interop) 'web_debug_web.dart';
