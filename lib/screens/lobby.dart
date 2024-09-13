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


  Future<void> createRoom(String roomId, String roomCategory) async {
    CollectionReference categoryDB = FirebaseFirestore.instance.collection('quizes').doc(roomCategory).collection("questions");
    QuerySnapshot querySnapshot = await categoryDB.get();
    int questionCount = querySnapshot.size;

    List<int> nums = [];

    for(int i=1; i<questionCount; i++) {
      nums.add(i);
    }

    nums.shuffle();
    var order = nums.join("/");

    await FirebaseFirestore.instance.collection('gameRooms').doc(roomId).set({
      'player1': FirebaseAuth.instance.currentUser?.uid,
      'player2': '',
      'player1score': 0,
      'player2score': 0,
      'player1start': false,
      'player2start': false,
      'player1answered': false,
      'player2answered': false,
      'questionNums': order,
      'category': roomCategory,
      'roomId': _idController.text
    });
  }



  Future<void> joinRoom(String roomId, String playerUID) async {
    await FirebaseFirestore.instance.collection('gameRooms').doc(roomId).update({
      'player2': playerUID,
    });
  }

  Stream<DocumentSnapshot> gameStream(String roomId) {
    return FirebaseFirestore.instance.collection('gameRooms').doc(roomId).snapshots();
  }

  void start(BuildContext ctx) async {
    DocumentReference room = FirebaseFirestore.instance.collection('gameRooms').doc("a");
    DocumentSnapshot roomSnapshot = await room.get();

    if(roomSnapshot["player1"] == FirebaseAuth.instance.currentUser?.uid)
      room.update({"player1start": true});
    else if(roomSnapshot["player2"] == FirebaseAuth.instance.currentUser?.uid)
      room.update({"player2start": true});

    while (roomSnapshot['player1start'] == false || roomSnapshot["player2start"] == false){
      room = FirebaseFirestore.instance.collection('gameRooms').doc("a");
      roomSnapshot = await room.get();
    };

    print("ROOM ID: " + _idController.text);
    Navigator.of(ctx).push(MaterialPageRoute(builder: (_) { return QuizScreen(roomId: _idController.text);}));
  }

  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text("Lobby"),
      ),
      body: Column(
        children: [
          TextButton(
            onPressed: () => createRoom("a", "Movies and TV"),
            child: Text('Create Room'),
          ),
          TextField(
            controller: _idController,
            decoration: InputDecoration(
              labelText: "Room ID",
            ),
          ),
          TextButton(
            onPressed: () => joinRoom("a", FirebaseAuth.instance.currentUser!.uid),
            child: Text('Join Room'),
          ),
          TextButton(
            onPressed: () => start(context),
            child: Text('Start'),
          ),
        ],
      ),
    );
  }
}