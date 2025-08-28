class AppConstants {
  // Firebase Collections
  static const String usersCollection = 'users';
  static const String locationsCollection = 'locations';
  static const String circlesCollection = 'circles';
  static const String invitesCollection = 'invites';

  // User Fields
  static const String userUid = 'uid';
  static const String userEmail = 'email';
  static const String userDisplayName = 'displayName';
  static const String userPhotoUrl = 'photoURL';
  static const String userCreatedAt = 'createdAt';
  static const String userSetupComplete = 'setupComplete';

  // Route Names
  static const String welcomeRoute = '/welcome';
  static const String authRoute = '/auth';
  static const String dashboardRoute = '/dashboard';

  // Error Messages
  static const String genericError = 'Something went wrong. Please try again.';
  static const String networkError = 'Please check your internet connection.';
  static const String authError = 'Authentication failed. Please try again.';

  // Success Messages
  static const String signInSuccess = 'Successfully signed in!';
  static const String signUpSuccess = 'Account created successfully!';
  static const String signOutSuccess = 'Successfully signed out!';

  // Deep Link base
  static const String inviteLinkBase = 'https://links.kincircle.app/invite/';
}
