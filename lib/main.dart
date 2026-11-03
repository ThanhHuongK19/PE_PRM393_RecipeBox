import 'package:flutter/material.dart';

import 'app.dart';
import 'core/firebase/firebase_initializer.dart';
import 'features/home/screens/firebase_startup_error_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _initializeAndRun();
}

Future<void> _initializeAndRun() async {
  try {
    final firebaseApp = await FirebaseInitializer.initialize();
    runApp(RecipeBoxApp(firebaseApp: firebaseApp));
  } catch (error, stackTrace) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'Firebase startup',
        context: ErrorDescription('while initializing Firebase'),
      ),
    );
    runApp(FirebaseStartupErrorApp(onRetry: _initializeAndRun));
  }
}
