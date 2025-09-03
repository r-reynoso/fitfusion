import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme.dart';
import 'router.dart';
import 'services/environment_service.dart';
import 'firestore/firebase_service_simplified.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase with comprehensive service configuration
  await firebaseService.initialize();
  
  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  runApp(const FitFusionApp());
}

class FitFusionApp extends StatelessWidget {
  const FitFusionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: EnvironmentService.appName,
      debugShowCheckedModeBanner: !EnvironmentService.isProduction,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: ThemeMode.dark, // Default to dark theme as specified
      routerConfig: FitFusionRouter.router,
    );
  }
}
