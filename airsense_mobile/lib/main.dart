import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'screens/app_shell.dart';
import 'screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  AuthService.init();
  runApp(const AirSenseApp());
}

class AirSenseApp extends StatelessWidget {
  const AirSenseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AirSense',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Roboto',
        scaffoldBackgroundColor: const Color(0xFFF5F3EE),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E6E5E),
          primary: const Color(0xFF1C2530),
        ),
      ),
      home: const AuthGate(),
    );
  }
}

/// Watches AuthService's state and displays LoginScreen or AppShell.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AuthService.authNotifier,
      builder: (context, isSignedIn, _) {
        if (isSignedIn) {
          return const AppShell();
        }
        return const LoginScreen();
      },
    );
  }
}