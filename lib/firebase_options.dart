import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Configure Firebase options based on your Firebase project
class DefaultFirebaseOptions {
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBUJhnyLA6eiQr0HkMf1phC9BQDW8bHV64',
    appId: '1:304175455062:web:3497bc897e7c1d11aa54f7',
    messagingSenderId: '304175455062',
    projectId: 'auto-invoicing-4176f',
    authDomain: 'auto-invoicing-4176f.firebaseapp.com',
    storageBucket: 'auto-invoicing-4176f.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'YOUR_ANDROID_API_KEY',
    appId: '1:YOUR_PROJECT_NUMBER:android:YOUR_ANDROID_APP_ID',
    messagingSenderId: '304175455062',
    projectId: 'auto-invoicing-4176f',
    storageBucket: 'auto-invoicing-4176f.firebasestorage.app',
  );

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }
}
