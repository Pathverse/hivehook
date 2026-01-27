/// Web implementation for debug object storage.
/// Stores objects directly in JavaScript's window.hiveDebug for easy inspection.
/// Limited to [maxDebugKeys] entries with FIFO eviction.
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// Whether web debug is available on this platform.
bool get isWebDebugAvailable => true;

/// Maximum number of debug keys to store. Oldest keys are evicted when exceeded.
int maxDebugKeys = 1000;

/// The hiveDebug object on window.
JSObject? _hiveDebug;

/// Track insertion order for FIFO eviction.
final List<String> _keyOrder = [];

/// Get the global window object.
@JS('globalThis')
external JSObject get _globalThis;

/// Create a new empty JS object.
@JS('Object')
external JSObject _newObject();

/// Delete a property from a JS object.
@JS('Reflect.deleteProperty')
external bool _jsDeleteProperty(JSObject obj, JSString key);

/// Get object keys.
@JS('Object.keys')
external JSArray<JSString> _jsObjectKeys(JSObject obj);

/// Initialize web debug storage.
void initWebDebug() {
  // Create window.hiveDebug = {} if it doesn't exist
  if (!_globalThis.hasProperty('hiveDebug'.toJS).toDart) {
    _globalThis.setProperty('hiveDebug'.toJS, _newObject());
  }
  _hiveDebug = _globalThis.getProperty('hiveDebug'.toJS) as JSObject;
}

/// Store a debug object directly in window.hiveDebug[key].
/// Enforces [maxDebugKeys] limit with FIFO eviction.
void webDebugPut(String key, dynamic value) {
  if (_hiveDebug == null) initWebDebug();

  // If key already exists, remove from order tracking (will re-add at end)
  _keyOrder.remove(key);

  // Evict oldest keys if at capacity
  while (_keyOrder.length >= maxDebugKeys) {
    final oldestKey = _keyOrder.removeAt(0);
    _jsDeleteProperty(_hiveDebug!, oldestKey.toJS);
  }

  // Convert Dart object to JS-compatible format
  final jsValue = _dartToJs(value);
  _hiveDebug!.setProperty(key.toJS, jsValue);
  _keyOrder.add(key);
}

/// Delete a debug object from window.hiveDebug.
/// Safe to call even if key doesn't exist (already deleted or evicted).
void webDebugDelete(String key) {
  if (_hiveDebug == null) return;
  try {
    _jsDeleteProperty(_hiveDebug!, key.toJS);
  } catch (_) {
    // Ignore errors - key may not exist
  }
  _keyOrder.remove(key);
}

/// Clear all debug objects from window.hiveDebug.
/// Safe to call even if already empty.
void webDebugClear() {
  if (_hiveDebug == null) return;
  try {
    // Reset to empty object
    _globalThis.setProperty('hiveDebug'.toJS, _newObject());
    _hiveDebug = _globalThis.getProperty('hiveDebug'.toJS) as JSObject;
  } catch (_) {
    // Ignore errors
  }
  _keyOrder.clear();
}

/// Get all debug keys.
List<String> webDebugKeys() {
  if (_hiveDebug == null) return [];
  final jsKeys = _jsObjectKeys(_hiveDebug!);
  final result = <String>[];
  for (var i = 0; i < jsKeys.length; i++) {
    result.add(jsKeys[i].toDart);
  }
  return result;
}

/// Convert Dart value to JS value recursively.
JSAny? _dartToJs(dynamic value) {
  if (value == null) return null;
  if (value is String) return value.toJS;
  if (value is int) return value.toJS;
  if (value is double) return value.toJS;
  if (value is bool) return value.toJS;
  if (value is List) {
    final List<JSAny?> items = [];
    for (var i = 0; i < value.length; i++) {
      items.add(_dartToJs(value[i]));
    }
    return items.toJS;
  }
  if (value is Map) {
    final jsObj = _newObject();
    for (final entry in value.entries) {
      final key = entry.key.toString();
      jsObj.setProperty(key.toJS, _dartToJs(entry.value));
    }
    return jsObj;
  }
  // For other objects, try to convert via toString
  return value.toString().toJS;
}
