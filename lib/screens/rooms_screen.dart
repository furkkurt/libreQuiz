import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:libre_quiz/screens/home_screen.dart';
import 'package:libre_quiz/screens/quiz_10.dart';

import 'login_screen.dart';

class RoomsScreen extends StatefulWidget {
  final int roomCount;
  const RoomsScreen({Key? key, required this.roomCount}) : super(key: key);

  @override
  State<RoomsScreen> createState() => _RoomsScreenState();
}

class _RoomsScreenState extends State<RoomsScreen> {
  CollectionReference gameRooms = FirebaseFirestore.instance.collection('gameRooms');

  Future<QuerySnapshot> initializeQuerySnapshot() async {
    return await gameRooms.get();
  }

  void start(BuildContext ctx, String roomId) async {
    DocumentReference room = FirebaseFirestore.instance.collection('gameRooms').doc(roomId);
    DocumentSnapshot roomSnapshot = await room.get();

    await FirebaseFirestore.instance.collection('gameRooms').doc(roomId).update({
      'player2': FirebaseAuth.instance.currentUser!.uid,
      'player2start': true
    });

    if (roomSnapshot["player1"] == FirebaseAuth.instance.currentUser?.uid)
      room.update({"player1start": true});
    else if (roomSnapshot["player2"] == FirebaseAuth.instance.currentUser?.uid)
      room.update({"player2start": true});

    while (roomSnapshot['player1start'] == false || roomSnapshot["player2start"] == false) {
      room = FirebaseFirestore.instance.collection('gameRooms').doc("a");
      roomSnapshot = await room.get();
    }

    print("ROOM ID: " + roomId);
    Navigator.of(ctx).push(MaterialPageRoute(builder: (_) {
      return QuizScreen(roomId: roomId);
    }));
  }

  @override
  Widget build(BuildContext context) {
    int roomCount = widget.roomCount;
    print(roomCount);

    return Scaffold(
      appBar: AppBar(
        title: Text("Rooms"),
      ),
      body: FutureBuilder<QuerySnapshot>(
        future: initializeQuerySnapshot(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          } else if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text("No rooms available"));
          } else {
            QuerySnapshot querySnapshot = snapshot.data!;
            return Column(
              children: List.generate(roomCount, (index) {
                int i = index;
                return TextButton(
                  onPressed: () => start(context, querySnapshot.docs[i]["roomId"]),
                  child: Text(
                    "ID: " + querySnapshot.docs[i]["roomId"] + "\nCategory: " +
                        querySnapshot.docs[i]["category"],
                  ),
                );
              }),
            );
          }
        },
      ),
    );
  }
}