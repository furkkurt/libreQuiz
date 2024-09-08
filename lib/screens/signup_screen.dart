import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:libre_quiz/screens/home_screen.dart';

import 'login_screen.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _RePasswordController = TextEditingController();

  void addData() async {
    CollectionReference users = FirebaseFirestore.instance.collection('users');

    await users.add({
      'username': _usernameController.text,
      'password': _passwordController.text,
    });

  }
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text("Sign Up"),
      ),
      body: Column(
        children: [
          SizedBox(height: 40),
          TextField(
            controller: _usernameController,
            decoration: InputDecoration(
              labelText: "Username",
            ),
          ),
          TextField(
            controller: _passwordController,
            decoration: InputDecoration(
              labelText: "Password",
            ),
          ),
          TextField(
            controller: _RePasswordController,
            decoration: InputDecoration(
              labelText: "Re-enter password",
            ),
          ),
          SizedBox(height: 40),
          TextButton(
            onPressed: () => addData(),
            child: Text('Sign Up'),
          ),
          SizedBox(height: 80),
          TextButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => LoginScreen())),
            child: Text("Already have an account? Login"),
          ),
        ],
      )
    );
  }
}