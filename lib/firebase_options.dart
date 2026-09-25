import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        return web;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCmiw-74BoxULHPVjnsNxKMJgAi89_LpiA',
    appId: '1:911247380877:web:d72720b6a928169752adc4',
    messagingSenderId: '911247380877',
    projectId: 'car-rental-app-90606',
    authDomain: 'car-rental-app-90606.firebaseapp.com',
    storageBucket: 'car-rental-app-90606.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCmiw-74BoxULHPVjnsNxKMJgAi89_LpiA',
    appId: '1:911247380877:android:d72720b6a928169752adc4',
    messagingSenderId: '911247380877',
    projectId: 'car-rental-app-90606',
    storageBucket: 'car-rental-app-90606.firebasestorage.app',
  );
}
