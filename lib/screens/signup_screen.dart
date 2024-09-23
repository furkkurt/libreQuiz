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
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _RePasswordController = TextEditingController();
  String emailAddress = "";
  String password = "";
  String username = "";

  void signUp() async {
    username = _usernameController.text;
    emailAddress = _emailController.text;
    password = _passwordController.text;

    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailAddress,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'weak-password') {
        print('The password provided is too weak.');
      } else if (e.code == 'email-already-in-use') {
        print('The account already exists for that email.');
      }
    } catch (e) {
      print(e);
    }

    CollectionReference userDB = FirebaseFirestore.instance.collection('users');
    QuerySnapshot querySnapshot = await userDB.get();

    userDB.doc(FirebaseAuth.instance.currentUser!.uid).set({
      'username': username,
      'w': 0,
      'l': 0,
      'd': 0
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
            ),style: TextStyle(color: Colors.white),
          ),
          TextField(
            controller: _emailController,
            decoration: InputDecoration(
              labelText: "email",
            ),style: TextStyle(color: Colors.white),
          ),
          TextField(
            controller: _passwordController,
            obscureText: true,
            decoration: InputDecoration(
              labelText: "Password",
            ),style: TextStyle(color: Colors.white),
          ),
          TextField(
            controller: _RePasswordController,
            obscureText: true,
            decoration: InputDecoration(
              labelText: "Re-enter password",
            ),style: TextStyle(color: Colors.white),
          ),
          SizedBox(height: 40),
          TextButton(
            onPressed: () => signUp(),
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