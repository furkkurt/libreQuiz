import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:libre_quiz/screens/home_screen.dart';
import 'package:libre_quiz/screens/signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController= TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  void login() async {
    try {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text,
          password: _passwordController.text
      );
      Navigator.push(context, MaterialPageRoute(builder: (context) => HomeScreen()));
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        print('No user found for that email.');
      } else if (e.code == 'wrong-password') {
        print('Wrong password provided for that user.');
      }
    }
  }

  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text("Login"),
      ),
      body: Column(
        children: [
          SizedBox(height: 40),
          TextField(
            controller: _emailController,
            decoration: InputDecoration(
              labelText: "Email",
            ),style: TextStyle(color: Colors.white),
          ),
          TextField(
            controller: _passwordController,
            obscureText: true,
            decoration: InputDecoration(
              labelText: "Password",
            ),style: TextStyle(color: Colors.white),
          ),
          SizedBox(height: 40),
          TextButton(
            onPressed: () => login(),
            child: Text('Login'),
          ),
          SizedBox(height: 80),
          TextButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => SignUpScreen())),
            child: Text("Don't have an account? Sign Up"),
          ),
        ],
      )
    );
  }
}