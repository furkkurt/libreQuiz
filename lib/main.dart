import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:libre_quiz/screens/add_question_screen.dart';
import 'package:libre_quiz/screens/home_screen.dart';
import 'package:libre_quiz/screens/lobby.dart';
import 'package:libre_quiz/screens/quiz_10.dart';
import 'package:libre_quiz/screens/rooms_screen.dart';
import 'package:libre_quiz/screens/signup_screen.dart';
import 'screens/login_screen.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  var auth = FirebaseAuth.instance;
  MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Libre Quiz',
        home: auth.currentUser != null ? RoomsScreen() : LoginScreen(),
    );
  }
}