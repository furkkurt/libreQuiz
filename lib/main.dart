import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:libre_quiz/screens/add_question_screen.dart';
import 'package:libre_quiz/screens/home_screen.dart';
import 'package:libre_quiz/screens/lobby.dart';
import 'package:libre_quiz/screens/quiz_10.dart';
import 'package:libre_quiz/screens/rooms_screen.dart';
import 'package:libre_quiz/screens/signup_screen.dart';
import 'screens/login_screen.dart';
import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';


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
      theme: ThemeData(
        textTheme: GoogleFonts.pixelifySansTextTheme(
          Theme.of(context).textTheme
        ),
        scaffoldBackgroundColor: Colors.black,
        appBarTheme: AppBarTheme(color: Colors.deepPurple),
      ),
      debugShowCheckedModeBanner: false,
      title: 'Libre Quiz',
      home: auth.currentUser != null ? HomeScreen() : LoginScreen(),
    );
  }
}