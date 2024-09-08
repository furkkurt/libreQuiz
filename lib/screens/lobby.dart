import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:libre_quiz/screens/add_question_screen.dart';
import 'package:libre_quiz/screens/quiz_10.dart';
import 'package:libre_quiz/screens/solo_quiz_screen.dart';

class LobbyScreen extends StatefulWidget {
  const LobbyScreen({super.key});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  final TextEditingController _idController= TextEditingController();


  Future<void> createRoom(String roomId) async {
    List<int> nums = [1, 2, 3, 4, 5, 6, 7, 8, 9, 0];
    nums.shuffle();
    var order = nums.join("");

    await FirebaseFirestore.instance.collection('gameRooms').doc(roomId).set({
      'player1': 'furkan',
      'player2': '',
      'player1score': 0,
      'player2score': 0,
      'quetionNums': order
    });
  }



  Future<void> joinRoom(String roomId, String playerName) async {
    await FirebaseFirestore.instance.collection('gameRooms').doc(roomId).update({
      'player2': "kurt",
    });
  }

  Stream<DocumentSnapshot> gameStream(String roomId) {
    return FirebaseFirestore.instance.collection('gameRooms').doc(roomId).snapshots();
  }

  void start() async {
    CollectionReference rooms = FirebaseFirestore.instance.collection('gameRooms');
    QuerySnapshot querySnapshot = await rooms.get();

    querySnapshot.docs.forEach((doc) {
      if (doc['player1'] != "" && doc["player2"] != "") {
        Navigator.push(context, MaterialPageRoute(builder: (context) => QuizScreen()));
      }
    });
  }


  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text("Lobby"),
      ),
      body: Column(
        children: [
          TextButton(
            onPressed: () => createRoom("a"),
            child: Text('Create Room'),
          ),
          TextField(
            controller: _idController,
            decoration: InputDecoration(
              labelText: "Room ID",
            ),
          ),
          TextButton(
            onPressed: () => joinRoom("a", "kurt"),
            child: Text('Join Room'),
          ),
          TextButton(
            onPressed: () => start(),
            child: Text('Start'),
          ),
        ],
      ),
    );
  }
}