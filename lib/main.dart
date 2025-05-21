import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'registration_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'login_page.dart';
import 'home_page.dart';
import 'quiz_creator_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Debug network connectivity
  try {
    final result = await InternetAddress.lookup('google.com');
    if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
      print("Network connectivity check: OK");
    }
  } on SocketException catch (e) {
    print("Network connectivity error: ${e.toString()}");
  }
  
  // Initialize Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print("Firebase initialized successfully");
  } catch (e) {
    print("Firebase initialization failed: ${e.toString()}");
  }
  
  // Remove the emulator connection - we'll use real Firebase services
  // If you need to debug Firebase issues, uncomment this:
  // FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Libre Quiz',
      theme: ThemeData(
        primarySwatch: Colors.deepOrange,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginPage(),
        '/register': (context) => const RegistrationPage(),
        '/home': (context) => const HomePage(),
        '/quiz_creator': (context) => const QuizCreatorPage(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}
