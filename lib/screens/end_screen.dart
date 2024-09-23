import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:libre_quiz/screens/home_screen.dart';
import 'package:libre_quiz/screens/quiz_10.dart';

import 'login_screen.dart';

class EndScreen extends StatefulWidget {
  final String roomId;
  const EndScreen({Key? key, required this.roomId}) : super(key: key);

  @override
  State<EndScreen> createState() => _EndScreenState();
}

class _EndScreenState extends State<EndScreen> {
  CollectionReference gameRooms = FirebaseFirestore.instance.collection('gameRooms');
  StreamController<String> _p1ScoreSC= StreamController<String>();
  StreamController<String> _p2ScoreSC= StreamController<String>();
  StreamController<String> _outcomeSC= StreamController<String>();
  String p1username = "";
  String p2username = "";

  Future<QuerySnapshot> initializeQuerySnapshot() async {
    return await gameRooms.get();
  }

  void getResults(roomId) async {
    print("GETTING RESUTS");
    print(roomId);
    DocumentReference room = FirebaseFirestore.instance.collection('gameRooms').doc(roomId);
    DocumentSnapshot roomSnapshot = await room.get();
    CollectionReference users = FirebaseFirestore.instance.collection('users');
    QuerySnapshot usersSnapshot = await users.get();

    DocumentReference p1 = users.doc(roomSnapshot["player1"]);
    DocumentSnapshot p1ss = await p1.get();
    p1username = p1ss["username"];
    DocumentReference p2 = users.doc(roomSnapshot["player2"]);
    DocumentSnapshot p2ss = await p2.get();
    p2username = p2ss["username"];
    _p1ScoreSC.add(roomSnapshot.get('player1score').toString());
    _p2ScoreSC.add(roomSnapshot.get('player2score').toString());
    int p1score = roomSnapshot.get('player1score');
    int p2score = roomSnapshot.get('player2score');
    int outcome = 0;
    if (p1score > p2score)
      outcome = 1;
    else if (p2score > p1score)
      outcome = 2;

    if (outcome == 0)
      _outcomeSC.add("DRAW");
    else if (outcome == 1)
      _outcomeSC.add(p1username + "WINS");
    else if (outcome == 2)
      _outcomeSC.add(p2username + "WINS");

    print(roomId);
    print(p1username);
    print(p1score);
    print(p2username);
    print(p2score);
  }

  @override
  Widget build(BuildContext context) {
    String roomId = widget.roomId;
    getResults(roomId);

    return Scaffold(
      appBar: AppBar(
        title: Text("Endgame"),
      ),
      body: Column(
        children: [
          Center(),
          SizedBox(height: 40,),
          StreamBuilder(
              stream: _p1ScoreSC.stream,
              builder: (context, snapshot) {
                return Text(p1username + ": " + snapshot.data.toString(), style: TextStyle(color: Colors.white),);
              }
          ),
          StreamBuilder(
              stream: _p2ScoreSC.stream,
              builder: (context, snapshot) {
                return Text(p2username + ": " + snapshot.data.toString(), style: TextStyle(color: Colors.white),);
              }
          ),
          StreamBuilder(
              stream: _outcomeSC.stream,
              builder: (context, snapshot) {
                return Text(snapshot.data.toString(), style: TextStyle(color: Colors.white),);
              }
          ),
          TextButton(onPressed: () => Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => HomeScreen()), ModalRoute.withName("/Home")), child: Text("Home", style: TextStyle(color: Colors.white),))
        ],
      )
    );
  }
}