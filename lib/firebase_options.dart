// Archivo generado por `flutterfire configure` para el proyecto:
//   Practica Macsa (practica-macsa)
//
// Regenerar si cambias de proyecto o de plataformas:
//   dart pub global activate flutterfire_cli
//   flutterfire configure

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        return linux;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions no están definidos para esta plataforma.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDAZ319nPKpK2MBe5do0U-WmAPBRtFE1AQ',
    appId: '1:620336202061:web:caae9b47af6b0cf2387704',
    messagingSenderId: '620336202061',
    projectId: 'practica-macsa',
    authDomain: 'practica-macsa.firebaseapp.com',
    storageBucket: 'practica-macsa.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAtodUT8YJlcPUCebMGi9qWChntWljssLU',
    appId: '1:620336202061:android:9bea19554f202c6b387704',
    messagingSenderId: '620336202061',
    projectId: 'practica-macsa',
    storageBucket: 'practica-macsa.firebasestorage.app',
  );
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'PENDING_FLUTTERFIRE_CONFIGURE',
    appId: 'PENDING_FLUTTERFIRE_CONFIGURE',
    messagingSenderId: 'PENDING_FLUTTERFIRE_CONFIGURE',
    projectId: 'PENDING_FLUTTERFIRE_CONFIGURE',
    iosBundleId: 'com.example.macsapractica',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'PENDING_FLUTTERFIRE_CONFIGURE',
    appId: 'PENDING_FLUTTERFIRE_CONFIGURE',
    messagingSenderId: 'PENDING_FLUTTERFIRE_CONFIGURE',
    projectId: 'PENDING_FLUTTERFIRE_CONFIGURE',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'PENDING_FLUTTERFIRE_CONFIGURE',
    appId: 'PENDING_FLUTTERFIRE_CONFIGURE',
    messagingSenderId: 'PENDING_FLUTTERFIRE_CONFIGURE',
    projectId: 'PENDING_FLUTTERFIRE_CONFIGURE',
  );

  static const FirebaseOptions linux = FirebaseOptions(
    apiKey: 'PENDING_FLUTTERFIRE_CONFIGURE',
    appId: 'PENDING_FLUTTERFIRE_CONFIGURE',
    messagingSenderId: 'PENDING_FLUTTERFIRE_CONFIGURE',
    projectId: 'PENDING_FLUTTERFIRE_CONFIGURE',
  );
}
