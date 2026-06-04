// Firebase client configuration, written by hand from the Firebase console
// values (project: hang-out-129b5). These are public client config values, not
// secrets — Firestore access is governed by security rules, not by hiding these.
//
// Web + Android + iOS are filled in. macOS/Windows entries throw until
// registered.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  DefaultFirebaseOptions._();

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'Firebase is not configured for $defaultTargetPlatform yet. '
          'Register the app in the Firebase console and add it here.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCr2xg_JRIyEA5d6ARgfZet-oUvplIdqoc',
    authDomain: 'hang-out-129b5.firebaseapp.com',
    projectId: 'hang-out-129b5',
    storageBucket: 'hang-out-129b5.firebasestorage.app',
    messagingSenderId: '998116442751',
    appId: '1:998116442751:web:60ff5254816a57d6cf354a',
    measurementId: 'G-WC99JH89ZS',
  );

  // Android values from android/app/google-services.json (project hang-out-129b5).
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyADEz2KaGu6c_mbuh7ThzIzWZJu2Le9lkY',
    appId: '1:998116442751:android:4c93524869ef4205cf354a',
    messagingSenderId: '998116442751',
    projectId: 'hang-out-129b5',
    storageBucket: 'hang-out-129b5.firebasestorage.app',
  );

  // iOS values from ios/Runner/GoogleService-Info.plist (project hang-out-129b5,
  // bundle com.raresrosu.hangout).
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyD5K6Hdl4syGIKo-yyjm3xrZQDDlhu6Pzc',
    appId: '1:998116442751:ios:f88810861617ac52cf354a',
    messagingSenderId: '998116442751',
    projectId: 'hang-out-129b5',
    storageBucket: 'hang-out-129b5.firebasestorage.app',
    iosBundleId: 'com.raresrosu.hangout',
    iosClientId:
        '998116442751-7db6tci4ma2a52qj5tdl5p0a18rahs5a.apps.googleusercontent.com',
  );
}
