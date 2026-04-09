/// App Constants
/// Contains all constant values used throughout the application

class AppConstants {
  AppConstants._();

  // App Information
  static const String appName = 'CWL';
  static const String appTagline = 'Coworking Spaces Made Easy';

  // User Roles
  static const String roleUser = 'user';
  static const String roleOwner = 'owner';

  // Booking Status
  static const String bookingStatusPending = 'pending';
  static const String bookingStatusConfirmed = 'confirmed';
  static const String bookingStatusCancelled = 'cancelled';
  static const String bookingStatusCompleted = 'completed';

  // Workspace Types
  static const String workspaceTypePrivate = 'private';
  static const String workspaceTypeShared = 'shared';
  static const String workspaceTypeMeetingRoom = 'meeting-room';

  // Cities List (Pakistan)
  static const List<String> cities = [
    'Islamabad',
    'Lahore',
    'Karachi',
    'Rawalpindi',
    'Faisalabad',
    'Peshawar',
  ];

  // Common Amenities
  static const List<String> commonAmenities = [
    'WiFi',
    'Parking',
    'Coffee',
    'Tea',
    'Air Conditioning',
    'Security',
    'Kitchen',
    'Restroom',
  ];

  // Supabase Table Names
  static const String collectionUsers = 'users';
  static const String collectionWorkspaces = 'workspaces';
  static const String collectionBookings = 'bookings';
  static const String collectionNotifications = 'notifications';

  // SharedPreferences Keys
  static const String keyUserId = 'user_id';
  static const String keyUserRole = 'user_role';
  static const String keyIsLoggedIn = 'is_logged_in';
  static const String keyOnboardingCompleted = 'onboarding_completed';

  // Duration
  static const int splashScreenDuration = 3; // seconds
}
