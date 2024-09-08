import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SoloQuizScreen extends StatefulWidget {
  const SoloQuizScreen({super.key});

  @override
  State<SoloQuizScreen> createState() => _SoloQuizScreenState();
}

class _SoloQuizScreenState extends State<SoloQuizScreen> {
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text("Quiz"),
      ),
      body: Column(
        children: [
          TextButton(
            onPressed: () => SoloQuizScreen(),
            child: Text('Sign Up'),
          ),
        ],
      ),
    );
  }
}