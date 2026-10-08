import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../firebase_options.dart';

class AuthException implements Exception {
  final String message;
  AuthException(this.message);
  @override
  String toString() => message;
}

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static String? _restUid;
  static String? _restEmail;

  static final ValueNotifier<bool> authNotifier = ValueNotifier<bool>(_auth.currentUser != null);

  static void init() {
    _auth.authStateChanges().listen((user) {
      if (user != null) {
        authNotifier.value = true;
      } else if (_restUid == null) {
        authNotifier.value = false;
      }
    });
  }

  static String? get currentUid => _auth.currentUser?.uid ?? _restUid;
  static String? get currentEmail => _auth.currentUser?.email ?? _restEmail;
  static bool get isSignedIn => currentUid != null;

  static User? get currentUser => _auth.currentUser;
  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  static String get _apiKey => DefaultFirebaseOptions.android.apiKey;

  static Future<void> signUp(String email, String password) async {
    email = email.trim();
    try {
      await _auth.setSettings(appVerificationDisabledForTesting: true);
    } catch (_) {}

    // Direct Firebase REST API call (bypasses Android emulator reCAPTCHA/BoringSSL)
    final url = Uri.parse("https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=$_apiKey");
    try {
      final res = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": email,
          "password": password,
          "returnSecureToken": true,
        }),
      );

      final data = jsonDecode(res.body);
      if (res.statusCode == 200) {
        _restUid = data["localId"];
        _restEmail = data["email"];
        authNotifier.value = true;
        return;
      }

      final errorMsg = data["error"]?["message"] as String?;
      if (errorMsg == "EMAIL_EXISTS") {
        throw AuthException("That email is already registered — try signing in instead.");
      } else if (errorMsg == "INVALID_EMAIL") {
        throw AuthException("That doesn't look like a valid email address.");
      } else if (errorMsg != null && errorMsg.startsWith("WEAK_PASSWORD")) {
        throw AuthException("Password should be at least 6 characters.");
      }
      throw AuthException(errorMsg ?? "Sign up failed. Please try again.");
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException("Could not connect to authentication server. Please check your network.");
    }
  }

  static Future<void> signIn(String email, String password) async {
    email = email.trim();

    try {
      await _auth.setSettings(appVerificationDisabledForTesting: true);
    } catch (_) {}

    // 1. Try Firebase REST API directly - zero reCAPTCHA dependency, works reliably on all emulators & devices
    final url = Uri.parse("https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=$_apiKey");
    try {
      final res = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": email,
          "password": password,
          "returnSecureToken": true,
        }),
      );

      final data = jsonDecode(res.body);
      if (res.statusCode == 200) {
        _restUid = data["localId"];
        _restEmail = data["email"];
        authNotifier.value = true;
        return;
      }

      final errorMsg = data["error"]?["message"] as String?;
      if (errorMsg == "INVALID_LOGIN_CREDENTIALS" ||
          errorMsg == "EMAIL_NOT_FOUND" ||
          errorMsg == "INVALID_PASSWORD") {
        throw AuthException("Incorrect email or password.");
      } else if (errorMsg == "USER_DISABLED") {
        throw AuthException("This user account has been disabled.");
      }
      throw AuthException(errorMsg ?? "Sign in failed. Please try again.");
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException("Could not connect to authentication server. Please check your network.");
    }
  }

  static Future<void> signOut() async {
    await _auth.signOut();
    _restUid = null;
    _restEmail = null;
    authNotifier.value = false;
  }
}
