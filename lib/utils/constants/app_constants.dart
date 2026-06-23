/// App Constants
/// Contains all constant values used throughout the application

class AppConstants {
  AppConstants._();

  // App Information
  static const String appName = 'CWL';
  static const String appTagline = 'Find teammates. Build projects. Book spaces.';

  // User Roles
  static const String roleUser = 'user';
  static const String roleOwner = 'owner';

  // Booking Status
  static const String bookingStatusPending = 'pending';
  static const String bookingStatusConfirmed = 'confirmed';
  static const String bookingStatusCancelled = 'cancelled';
  static const String bookingStatusCompleted = 'completed';

  // Payment methods
  static const String paymentMethodStripe = 'stripe';
  static const String paymentMethodManual = 'manual';

  // Receipt status (manual bank/easypaisa payments)
  static const String receiptAwaitingUpload = 'awaiting_upload';
  static const String receiptAwaitingVerification = 'awaiting_verification';
  static const String receiptApproved = 'approved';
  static const String receiptRejected = 'rejected';

  // Owner account types
  static const String accountTypeBank = 'bank';
  static const String accountTypeEasypaisa = 'easypaisa';
  static const String accountTypeJazzcash = 'jazzcash';

  static const List<String> ownerAccountTypes = [
    accountTypeBank,
    accountTypeEasypaisa,
    accountTypeJazzcash,
  ];
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
