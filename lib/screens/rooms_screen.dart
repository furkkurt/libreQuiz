import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:libre_quiz/screens/home_screen.dart';

import 'login_screen.dart';

class RoomsScreen extends StatefulWidget {
  const RoomsScreen({super.key});

  @override
  State<RoomsScreen> createState() => _RoomsScreenState();
}

class _RoomsScreenState extends State<RoomsScreen> {
  int roomsCount = 0;
  late CollectionReference gameRooms;
  late QuerySnapshot querySnapshot;

  @override
  void initState() {
    setState(() {
      super.initState();
      countRooms();
    });
  }

  void countRooms() async {
    CollectionReference gameRooms = FirebaseFirestore.instance.collection('gameRooms');
    QuerySnapshot querySnapshot = await gameRooms.get();

    roomsCount = querySnapshot.size;
    print(roomsCount);
  }

  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text("Rooms"),
      ),
      body: Column(
        children: List.generate(roomsCount, (index) {
          return Text("text");
        })
      )
    );
  }
}