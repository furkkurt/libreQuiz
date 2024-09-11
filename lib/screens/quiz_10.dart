import 'dart:async';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:libre_quiz/screens/home_screen.dart';

import 'login_screen.dart';

class QuizScreen extends StatefulWidget {
  final String roomId;
  const QuizScreen({Key? key, required this.roomId}) : super(key: key);


  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  StreamController<String> _categorySC= StreamController<String>();
  StreamController<String> _questionSC= StreamController<String>();
  StreamController<String> _option1SC= StreamController<String>();
  StreamController<String> _option2SC= StreamController<String>();
  StreamController<String> _option3SC= StreamController<String>();
  StreamController<String> _option4SC= StreamController<String>();

  var optionNums = [1, 2, 3, 4];
  int correctOption = 1;
  late int realCorrectOption;
  int score = 0;
  int questionCount = 0;

  @override
  void initState() {
    setState(() {
      super.initState();
      //showQuestion();
    });
  }

  /*
  void deneme(){
    Future.delayed(const Duration(seconds: 2), () {
      showQuestion();
      print("hey");
    });
  }
  */

  void showQuestion(roomId) async {
    print("HEEEEEYYYYYY");
    print(questionCount);
    print(roomId.toString());
    DocumentReference gameRoom = FirebaseFirestore.instance.collection('gameRooms').doc(roomId.toString());
    DocumentSnapshot querySnapshotRoom = await gameRoom.get();
    CollectionReference questions = FirebaseFirestore.instance.collection('quizes').doc(querySnapshotRoom["category"]).collection("questions");
    QuerySnapshot querySnapshotQuiz = await questions.get();
    var questionNumsStr = [""];
    var questionNums = [];
    print(questionNumsStr);
    print(querySnapshotRoom["category"]);
    questionNumsStr = querySnapshotRoom["questionNums"].split("/");
    for (int i = 0; i<questionNumsStr.length; i++) {
      questionNums.add(int.parse(questionNumsStr[i]));
    }
    print(questionNums);

    int questionId = questionNums[questionCount];
    print(questionId);

    _questionSC.add(querySnapshotQuiz.docs[questionId]['question']);
    _option1SC.add(querySnapshotQuiz.docs[questionId]['option1']);
    _option2SC.add(querySnapshotQuiz.docs[questionId]['option2']);
    _option3SC.add(querySnapshotQuiz.docs[questionId]['option3']);
    _option4SC.add(querySnapshotQuiz.docs[questionId]['option4']);

    questionCount++;
  }

  void answer(roomId) {
    if (correctOption == realCorrectOption) {
      print("correct");
      score++;
    }
    else {
      print("false");
    }
    showQuestion(roomId);
  }

  Widget build(BuildContext context) {
    String roomId = widget.roomId;
    showQuestion(roomId);

    return Scaffold(
      appBar: AppBar(
          title: Text("Question"),
      ),
      body: Column(
        children: [
          SizedBox(height: 40),
          StreamBuilder(
              stream: _categorySC.stream,
              builder: (context, snapshot) {
                if(snapshot.hasData) {
                  return Flexible(child: Text(snapshot.data??''));
                } else {
                  return Flexible(child: Text(""));
                }
              }
          ),
          SizedBox(height: 40),
          StreamBuilder(
              stream: _questionSC.stream,
              builder: (context, snapshot) {
                if(snapshot.hasData) {
                  return Flexible(child: Text(snapshot.data??''));
                } else {
                  return Flexible(child: Text(""));
                }
              }
          ),
          SizedBox(height: 40),
          StreamBuilder(
              stream: _option1SC.stream,
              builder: (context, snapshot) {
                if(snapshot.hasData) {
                  return Flexible(child: Text("A: " + snapshot.data.toString()));
                } else {
                  return Flexible(child: Text("A: "));
                }
              }
          ),
          StreamBuilder(
              stream: _option2SC.stream,
              builder: (context, snapshot) {
                if(snapshot.hasData) {
                  return Flexible(child: Text("B: " + snapshot.data.toString()));
                } else {
                  return Flexible(child: Text("B: "));
                }
              }
          ),
          StreamBuilder(
              stream: _option3SC.stream,
              builder: (context, snapshot) {
                if(snapshot.hasData) {
                  return Flexible(child: Text("C: " + snapshot.data.toString()));
                } else {
                  return Flexible(child: Text("C: "));
                }
              }
          ),
          StreamBuilder(
              stream: _option4SC.stream,
              builder: (context, snapshot) {
                if(snapshot.hasData) {
                  return Flexible(child: Text("D: " + snapshot.data.toString()));
                } else {
                  return Flexible(child: Text("D: "));
                }
              }
          ),
          SizedBox(height: 40),
          DropdownButton(
            items: optionNums.map((int item){
              return DropdownMenuItem(
                  value: item,
                  child: Text(["A", "B", "C", "D"][item-1])
              );
            }).toList(),
            onChanged: (int? newValue) {
              setState(() {
                correctOption = newValue!;
              });
            },
            value: correctOption,
          ),
          TextButton(
            onPressed: () => showQuestion(roomId),
            child: Text("Answer"),
          ),
        ],
      )
    );
  }
}