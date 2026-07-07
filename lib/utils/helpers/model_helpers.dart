/// Model Helpers
/// Common utility functions for model serialization and type conversion
/// Used across all model classes to avoid code duplication

/// Safely converts any numeric value to double
/// Handles int, double, num, and string types
/// Returns defaultValue if conversion fails or value is null
double convertToDouble(dynamic value, double defaultValue) {
  if (value == null) return defaultValue;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is num) return value.toDouble();
  try {
    return double.parse(value.toString());
  } catch (e) {
    return defaultValue;
  }
}

/// Safely converts any numeric value to nullable double
/// Returns null if value is null or conversion fails
double? convertToDoubleNullable(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is num) return value.toDouble();
  try {
    return double.parse(value.toString());
  } catch (e) {
    return null;
  }
}

/// Safely converts any numeric value to int
/// Handles int, double, num, and string types
/// Returns defaultValue if conversion fails or value is null
int convertToInt(dynamic value, int defaultValue) {
  if (value == null) return defaultValue;
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is num) return value.toInt();
  try {
    return int.parse(value.toString());
  } catch (e) {
    return defaultValue;
  }
}

/// Safely converts any numeric value to nullable int
/// Returns null if value is null or conversion fails
int? convertToIntNullable(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is num) return value.toInt();
  try {
    return int.parse(value.toString());
  } catch (e) {
    return null;
  }
}

/// Gets a string value from map using snake_case or camelCase keys
/// Tries snake_case first, then camelCase, returns null if both fail
String? getStringFromMap(Map<String, dynamic> map, String snakeCaseKey, String camelCaseKey) {
  return map[snakeCaseKey] as String? ?? map[camelCaseKey] as String?;
}

/// Gets a typed value from map using snake_case or camelCase keys
/// Tries snake_case first, then camelCase, returns defaultValue if both fail
T getValueFromMap<T>(Map<String, dynamic> map, String snakeCaseKey, String camelCaseKey, T defaultValue) {
  final raw = map[snakeCaseKey] ?? map[camelCaseKey];
  if (raw == null) return defaultValue;
  if (raw is T) return raw;
  if (T == bool) {
    if (raw is bool) return raw as T;
    if (raw is num) return (raw != 0) as T;
    if (raw is String) {
      final lower = raw.toLowerCase();
      if (lower == 'true' || lower == '1') return true as T;
      if (lower == 'false' || lower == '0') return false as T;
    }
  }
  return defaultValue;
}

/// Gets a nullable typed value from map using snake_case or camelCase keys
T? getNullableValueFromMap<T>(Map<String, dynamic> map, String snakeCaseKey, String camelCaseKey) {
  return map[snakeCaseKey] as T? ?? map[camelCaseKey] as T?;
}

/// Gets a list value from map using snake_case or camelCase keys
dynamic getListFromMap(Map<String, dynamic> map, String snakeCaseKey, String camelCaseKey) {
  return map[snakeCaseKey] ?? map[camelCaseKey];
}

/// Safely gets the first character of a name for avatar initials
String safeInitial(String? name) {
  if (name == null || name.isEmpty) return '?';
  return name[0].toUpperCase();
}
