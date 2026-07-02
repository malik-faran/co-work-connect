/// App Constants
/// Contains all constant values used throughout the application

class AppConstants {
  AppConstants._();

  // App Information
  static const String appName = 'CWL';
  static const String appTagline = 'Find teammates. Build projects. Book spaces.';

  /// Deep link Supabase redirects to after password-reset email (add in Dashboard → Redirect URLs).
  static const String passwordResetRedirectUrl = 'cwc://reset-password/';

  // User Roles
  static const String roleUser = 'user';
  static const String roleOwner = 'owner';
  static const String roleModerator = 'moderator';

  // Payment payee
  static const String payeePlatform = 'platform';
  static const String payeeOwner = 'owner';

  static const String paymentMethodWallet = 'wallet';

  // Booking Status
  static const String bookingStatusPending = 'pending';
  static const String bookingStatusConfirmed = 'confirmed';
  static const String bookingStatusCancelled = 'cancelled';
  static const String bookingStatusCompleted = 'completed';

  // Payment methods
  static const String paymentMethodStripe = 'stripe';
  static const String paymentMethodManual = 'manual';
  static const String paymentMethodSplit = 'split';

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
    'Rawalpindi',
    'Abbottabad',
    'Lahore',
    'Karachi',
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

  /// Pick multiple highlights when listing a workspace.
  static const List<String> workspaceDescriptionHighlights = [
    'Quiet and focused environment',
    'High-speed WiFi',
    'Natural lighting',
    '24/7 access',
    'Professional reception',
    'Meeting rooms on-site',
    'Ergonomic furniture',
    'Printing & scanning',
    'Dedicated desks',
    'Hot-desking available',
    'Community networking events',
    'Near public transport',
    'Parking on premises',
    'Kitchen & refreshment area',
    'Power backup / UPS',
  ];

  /// Common office rules — owner can select several and add custom ones.
  static const List<String> commonOfficePolicies = [
    'No smoking',
    'No loud calls in open areas',
    'Quiet hours after 6 PM',
    'Bring your own laptop',
    'Clean desk policy',
    'Visitors must sign in at reception',
    'No outside food in meeting rooms',
    'Government ID required at entry',
    'Cancel bookings 24 hours in advance',
    'Pets not allowed',
    'Professional attire recommended',
    'No personal items left overnight',
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

  /// Collaboration project categories (create + discover filter).
  static const List<String> projectCategories = [
    'Web Development',
    'Mobile App',
    'UI/UX Design',
    'Graphic Design',
    'Artificial Intelligence (AI)',
    'Machine Learning',
    'Cybersecurity',
    'Data Science',
    'Cloud & DevOps',
    'Blockchain',
    'Internet of Things (IoT)',
    'Game Development',
    'FYP / University',
    'Hackathon',
    'Startup / Business',
    'Digital Marketing',
    'Content Writing',
    'Video Editing',
    'Other',
  ];
}
