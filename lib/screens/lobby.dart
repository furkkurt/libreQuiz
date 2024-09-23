import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:libre_quiz/screens/add_question_screen.dart';
import 'package:libre_quiz/screens/quiz_10.dart';
import 'package:libre_quiz/screens/rooms_screen.dart';
import 'package:libre_quiz/screens/solo_quiz_screen.dart';

class LobbyScreen extends StatefulWidget {
  const LobbyScreen({super.key});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  StreamController<String> _categorySC= StreamController<String>();
  List<String> categories = [];
  String selectedCategory = "";
  final TextEditingController _idController= TextEditingController();
  int roomCount = 0;


  @override
  void initState() {
    setState(() {
      super.initState();
      getCategories();
      countRooms();
    });
  }
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

  void countRooms() async {
    CollectionReference gameRooms = FirebaseFirestore.instance.collection('gameRooms');
    QuerySnapshot querySnapshot = await gameRooms.get();

    roomCount = querySnapshot.size;
    print("LOBBY COUNT IS");
    print(roomCount);
  }

  void getCategories() async{
    CollectionReference categoriesDB = FirebaseFirestore.instance.collection('quizes');
    QuerySnapshot querySnapshot = await categoriesDB.get();

    String categories = "";
    querySnapshot.docs.forEach((doc) {
      categories += doc["name"] + "/";
    });
    categories = categories.substring(0, categories.length-1);
    selectedCategory = categories.split("/")[0];
    _categorySC.add(categories);
  }

  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text("Lobby"),
      ),
      body: Column(
        children: [
          TextButton(
            onPressed: () => createRoom(_idController.text, selectedCategory),
            child: Text('Create Room'),
          ),
          StreamBuilder(
              stream: _categorySC.stream,
              builder: (context, snapshot) {
                return DropdownButton<String>(
                  value: selectedCategory,
                  onChanged: (String? newValue) {
                    setState(() {
                      selectedCategory = newValue!;
                    });
                  },
                  items: snapshot.data.toString().split("/").map<DropdownMenuItem<String>>((
                      String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value, style: TextStyle(color: Colors.white),),
                    );
                  }).toList(),
                );
              }
          ),
          TextField(
            controller: _idController,
            decoration: InputDecoration(
              labelText: "Room ID",
            ), style: TextStyle(color: Colors.white),
          ),
          TextButton(
            onPressed: () => joinRoom("a", FirebaseAuth.instance.currentUser!.uid),
            child: Text('Join Room'),
          ),
          TextButton(
            onPressed: () => start(context),
            child: Text('Start'),
          ),
          SizedBox(height: 40,),
          TextButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => RoomsScreen(roomCount: roomCount,))),
            child: Text('List Rooms'),
          ),
        ],
      ),
    );
  }
}