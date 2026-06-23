import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Firebase config for project: cwcc-64d25
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('FCM is not configured for web.');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'FCM is not supported on $defaultTargetPlatform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAmif0c9gbxdE6xi2gYoNs0FTrOrV-k01M',
    appId: '1:174374530965:android:abe89bce8cf5a3c916909c',
    messagingSenderId: '174374530965',
    projectId: 'cwcc-64d25',
    storageBucket: 'cwcc-64d25.firebasestorage.app',
  );

  // Add iOS app in Firebase Console, then run: flutterfire configure
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAmif0c9gbxdE6xi2gYoNs0FTrOrV-k01M',
    appId: '1:174374530965:android:abe89bce8cf5a3c916909c',
    messagingSenderId: '174374530965',
    projectId: 'cwcc-64d25',
    storageBucket: 'cwcc-64d25.firebasestorage.app',
    iosBundleId: 'com.example.cwc',
  );
}
