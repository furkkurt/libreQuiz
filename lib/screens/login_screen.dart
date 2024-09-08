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
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  void readData() async {
    CollectionReference users = FirebaseFirestore.instance.collection('users');

    QuerySnapshot querySnapshot = await users.get();
    querySnapshot.docs.forEach((doc) {
      doc['username'] == _usernameController.text ?
          doc['password'] == _passwordController.text ?
              Navigator.push(context, MaterialPageRoute(builder: (context) => HomeScreen())) :
              print("ŞİFRE HATALI") :
          print("KULLANICI YOK");
    });
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
          SizedBox(height: 40),
          TextButton(
            onPressed: () => readData(),
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