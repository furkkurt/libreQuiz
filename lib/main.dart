import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'registration_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io';
import 'login_page.dart';
import 'home_page.dart';
import 'quiz_creator_page.dart';
import 'web_layout_helper.dart';
import 'profile_page.dart';
import 'friends_list_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Suppress specific errors in development mode
  FlutterError.onError = (FlutterErrorDetails details) {
    // Ignore pointer binding errors in debug mode
    final exception = details.exception.toString();
    if (exception.contains('targetElement == domElement') ||
        exception.contains('The targeted input element must be the active input element')) {
      // Just log to console but don't crash the app
      print('Suppressed error: ${details.exception}');
      return;
    }
    // For other errors, use the default error handling
    FlutterError.presentError(details);
  };
  
  // Different initialization for web vs mobile
  if (!kIsWeb) {
    // Only run this check on non-web platforms
    try {
      final result = await InternetAddress.lookup('google.com');
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        print("Network connectivity check: OK");
      }
    } on SocketException catch (e) {
      print("Network connectivity check: Failed - ${e.toString()}");
    }
  }
  
  // Initialize Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print("Firebase initialized successfully");
    
    // Add this debugging information
    print("DEBUG: Firebase Web API Key: ${DefaultFirebaseOptions.web.apiKey}");
    print("DEBUG: Firebase Auth Domain: ${DefaultFirebaseOptions.web.authDomain}");
    print("DEBUG: Firebase Auth Methods Available: ${FirebaseAuth.instance.isSignInWithEmailLink}");
    
    // Check if authentication is working 
    try {
      final methods = await FirebaseAuth.instance.fetchSignInMethodsForEmail('test@example.com');
      print("DEBUG: Sign in methods for test@example.com: $methods");
    } catch (e) {
      print("DEBUG: Error fetching sign-in methods: $e");
    }
  } catch (e) {
    print("Firebase initialization failed: ${e.toString()}");
  }
  
  // Uncomment these lines to use Firebase emulators for local testing
  // FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
  // FirebaseFirestore.instance.useFirestore('localhost', 8080);
  
  if (kIsWeb) {
    // Force web auth to use popup instead of redirect (more reliable)
    try {
      print("DEBUG: Running in web mode");
    } catch (e) {
      print("DEBUG: Web configuration error: $e");
    }
  }
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Create a special theme for web with larger text sizes
    final baseTheme = ThemeData(
      primarySwatch: Colors.deepOrange,
      visualDensity: VisualDensity.adaptivePlatformDensity,
    );
    
    // If on web, scale up the theme
    final theme = kIsWeb 
      ? baseTheme.copyWith(
          textTheme: baseTheme.textTheme.copyWith(
            // Explicitly define text styles with larger sizes instead of using apply()
            displayLarge: baseTheme.textTheme.displayLarge?.copyWith(fontSize: 40),
            displayMedium: baseTheme.textTheme.displayMedium?.copyWith(fontSize: 36),
            displaySmall: baseTheme.textTheme.displaySmall?.copyWith(fontSize: 32),
            headlineLarge: baseTheme.textTheme.headlineLarge?.copyWith(fontSize: 30),
            headlineMedium: baseTheme.textTheme.headlineMedium?.copyWith(fontSize: 28),
            headlineSmall: baseTheme.textTheme.headlineSmall?.copyWith(fontSize: 26),
            titleLarge: baseTheme.textTheme.titleLarge?.copyWith(fontSize: 24),
            titleMedium: baseTheme.textTheme.titleMedium?.copyWith(fontSize: 22),
            titleSmall: baseTheme.textTheme.titleSmall?.copyWith(fontSize: 20),
            bodyLarge: baseTheme.textTheme.bodyLarge?.copyWith(fontSize: 18),
            bodyMedium: baseTheme.textTheme.bodyMedium?.copyWith(fontSize: 16),
            bodySmall: baseTheme.textTheme.bodySmall?.copyWith(fontSize: 14),
            labelLarge: baseTheme.textTheme.labelLarge?.copyWith(fontSize: 16),
            labelMedium: baseTheme.textTheme.labelMedium?.copyWith(fontSize: 14),
            labelSmall: baseTheme.textTheme.labelSmall?.copyWith(fontSize: 12),
          ),
          buttonTheme: ButtonThemeData(
            height: 60.0,
            minWidth: 120.0,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
              textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          inputDecorationTheme: const InputDecorationTheme(
            contentPadding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
          ),
        )
      : baseTheme;

    return MaterialApp(
      title: 'Libre Quiz',
      theme: theme,
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginPage(),
        '/register': (context) => const RegistrationPage(),
        '/home': (context) => const HomePage(),
        '/quiz_creator': (context) => const QuizCreatorPage(),
        '/profile': (context) => const ProfilePage(),
        '/friends': (context) => const FriendsListPage(),
      },
      builder: (context, child) {
        // Apply a text scale factor for web (reduced from 1.3)
        if (kIsWeb) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaleFactor: 1.1, // Reduced from 1.3
            ),
            child: child!,
          );
        }
        return child!;
      },
      debugShowCheckedModeBanner: false,
    );
  }
}
