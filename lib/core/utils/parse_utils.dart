import 'package:flutter/foundation.dart';

/// Safely coerce a dynamic value into a double.
/// Accepts num and numeric strings; returns null for unsupported types (bool, Map, List, etc.).
double? coerceDouble(dynamic raw, {String? context}) {
  if (raw == null) return null;
  if (raw is num) return raw.toDouble();
  if (raw is String) {
    final parsed = double.tryParse(raw);
    if (parsed != null) return parsed;
  }
  if (context != null) {
    debugPrint('Invalid numeric value for $context: $raw (${raw.runtimeType})');
  }
  return null;
}
