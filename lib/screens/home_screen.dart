import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:libre_quiz/screens/add_question_screen.dart';
import 'package:libre_quiz/screens/lobby.dart';
import 'package:libre_quiz/screens/quiz_10.dart';
import 'package:libre_quiz/screens/solo_quiz_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text("Home Screen"),
      ),
      body: Column(
        children: [
          Center(
           child: TextButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => LobbyScreen())),
              child: Text('Play'),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => AddQuestionScreen())),
            child: Text('Create Quiz'),
          ),
        ],
      ),
    );
  }
}