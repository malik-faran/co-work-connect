/// Error Handler
/// Utility functions for handling and formatting errors
/// Provides consistent error messages across the application
library;

/// Cleans up error message by removing common prefixes
/// Removes "Exception: " prefix if present
String cleanErrorMessage(String? errorMessage) {
  if (errorMessage == null || errorMessage.isEmpty) {
    return 'An unexpected error occurred. Please try again.';
  }
  
  // Remove common error prefixes
  if (errorMessage.startsWith('Exception: ')) {
    return errorMessage.substring(11);
  }
  
  return errorMessage;
}

/// Formats authentication errors into user-friendly messages
String formatAuthError(String error) {
  final lowerError = error.toLowerCase();
  
  if (lowerError.contains('email not confirmed') || lowerError.contains('not confirmed')) {
    return 'Please confirm your email address before logging in.';
  } else if (lowerError.contains('invalid') || lowerError.contains('wrong') || lowerError.contains('invalid_credentials')) {
    return 'Invalid email or password. Please check and try again.';
  } else if (lowerError.contains('user not found')) {
    return 'No account found with this email. Please sign up first.';
  } else if (lowerError.contains('user_already_registered') ||
      lowerError.contains('already registered') ||
      lowerError.contains('already been registered') ||
      lowerError.contains('email address is already') ||
      lowerError.contains('user already exists')) {
    // Keep this narrow — matching bare "exists" / "already" incorrectly maps
    // DB messages like "Key (phone)=() already exists" to fake signup failures.
    return 'An account with this email already exists. Please login instead.';
  } else if (lowerError.contains('password') || lowerError.contains('weak')) {
    return 'Password is too weak. Please use at least 6 characters.';
  } else if (lowerError.contains('network') || lowerError.contains('connection')) {
    return 'Network error. Please check your internet connection.';
  } else if (lowerError.contains('database error saving new user') ||
      lowerError.contains('unexpected_failure')) {
    return 'Could not create your account on the server. Please try again in a minute, or contact support if this continues.';
  } else if (lowerError.contains('socketexception') ||
      lowerError.contains('failed host lookup') ||
      lowerError.contains('no address associated with hostname')) {
    return 'Cannot reach the server. Check mobile data/Wi‑Fi and try again.';
  }
  
  return cleanErrorMessage(error);
}

/// Formats database errors into user-friendly messages
String formatDatabaseError(String error) {
  final lowerError = error.toLowerCase();
  
  if (lowerError.contains('duplicate') || lowerError.contains('unique')) {
    return 'This record already exists.';
  } else if (lowerError.contains('null') || lowerError.contains('not null')) {
    return 'Missing required information.';
  } else if (lowerError.contains('permission') || lowerError.contains('policy') || lowerError.contains('rls')) {
    return 'Database permission error. Please contact support.';
  } else if (lowerError.contains('column') || lowerError.contains('does not exist')) {
    return 'Database configuration error. Please contact support.';
  }
  
  return cleanErrorMessage(error);
}


