import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  StreamController<String> _answerSC= StreamController<String>();
  StreamController<String> _plScoreSC= StreamController<String>();
  StreamController<String> _opScoreSC= StreamController<String>();
  StreamController<String> _timerSC= StreamController<String>();

  var optionDefs = [1, 2, 3, 4];
  var optionNums = [1, 2, 3, 4];
  int correctOption = 1;
  late int realCorrectOption;
  int score = 0;
  int questionCount = 0;
  var questionNums = [];
  int questionId = 0;
  String playerScore = "";
  String opScore = "";
  late DocumentReference gameRoom;
  late DocumentSnapshot querySnapshotRoom;
  late CollectionReference questions;
  late QuerySnapshot querySnapshotQuiz;

  @override
  void initState() {
    setState(() {
      super.initState();
      //showQuestion();
    });
  }

  void getDB(roomId) async{
    DocumentReference gameRoom = FirebaseFirestore.instance.collection('gameRooms').doc(roomId.toString());
    DocumentSnapshot querySnapshotRoom = await gameRoom.get();
    CollectionReference questions = FirebaseFirestore.instance.collection('quizes').doc(querySnapshotRoom["category"]).collection("questions");
    QuerySnapshot querySnapshotQuiz = await questions.get();

    if (querySnapshotRoom["player1"] == FirebaseAuth.instance.currentUser!.uid) {
      playerScore = "player1score";
      opScore = "player2score";
    } else {
      playerScore = "player2score";
      opScore = "player1score";
    }
  }

  void timeout(roomId) {
    int questionCountNow = questionCount;
    int remainingSeconds = 20;
    Timer.periodic(Duration(seconds: 1), (timer) {
      if(questionCountNow == questionCount) {
        //print("HEYY " + questionCountNow.toString() + " TO " + questionCount.toString());
        _timerSC.add((remainingSeconds--).toString());
      }
      else
        timer.cancel();
    });
    Future.delayed(const Duration(seconds: 21), () async {
      if(questionCountNow == questionCount) {
        questionCount++;
        print("times up " + questionCount.toString());
        gameRoom.update({playerScore: score});

        _answerSC.add(querySnapshotQuiz.docs[questionId]["option1"]);
        _plScoreSC.add(querySnapshotRoom[playerScore].toString());
        _opScoreSC.add(querySnapshotRoom[opScore].toString());
        gameRoom.update({"player1answered": true, "player2answered": true});

        Future.delayed(const Duration(seconds: 5), () async {
          _timerSC.add("");
          _answerSC.add("");
          _plScoreSC.add("");
          _opScoreSC.add("");
          gameRoom.update({"player1answered": false, "player2answered": false});
          showQuestion(roomId);
        });
      }
    });
  }

  void showQuestion(roomId) async {
    timeout(roomId);
    gameRoom = FirebaseFirestore.instance.collection('gameRooms').doc(roomId.toString());
    querySnapshotRoom = await gameRoom.get();
    questions = FirebaseFirestore.instance.collection('quizes').doc(querySnapshotRoom["category"]).collection("questions");
    querySnapshotQuiz = await questions.get();
    var questionNumsStr = [""];
    print("QUESTION NUMBER: " + questionCount.toString());
    questionNumsStr = querySnapshotRoom["questionNums"].split("/");
    for (int i = 0; i<questionNumsStr.length; i++) {
      questionNums.add(int.parse(questionNumsStr[i]));
    }
    questionId = questionNums[questionCount];

    optionNums.shuffle();
    _questionSC.add(querySnapshotQuiz.docs[questionId]['question']);
    _option1SC.add(querySnapshotQuiz.docs[questionId]['option'+optionNums[0].toString()]);
    _option2SC.add(querySnapshotQuiz.docs[questionId]['option'+optionNums[1].toString()]);
    _option3SC.add(querySnapshotQuiz.docs[questionId]['option'+optionNums[2].toString()]);
    _option4SC.add(querySnapshotQuiz.docs[questionId]['option'+optionNums[3].toString()]);
  }

  void answer(roomId, choice) async {
    _option1SC.add("");
    _option2SC.add("");
    _option3SC.add("");
    _option4SC.add("");
    gameRoom = FirebaseFirestore.instance.collection('gameRooms').doc(roomId.toString());
    querySnapshotRoom = await gameRoom.get();
    questions = FirebaseFirestore.instance.collection('quizes').doc(querySnapshotRoom["category"]).collection("questions");
    querySnapshotQuiz = await questions.get();

    if(querySnapshotRoom["player1"] == FirebaseAuth.instance.currentUser!.uid)
      gameRoom.update({"player1answered": true});
    else
      gameRoom.update({"player2answered": true});

    Timer.periodic(Duration(seconds: 1), (timer) async {
      querySnapshotRoom = await gameRoom.get();
      if (querySnapshotRoom['player1answered'] == true && querySnapshotRoom["player2answered"] == true) {
        print("SCORE UPDATED" + choice.toString());
        timer.cancel();
        questionCount++;
        if(choice == querySnapshotQuiz.docs[questionId]["option1"])
          score++;
        gameRoom.update({playerScore: score});
        querySnapshotRoom = await gameRoom.get();
        _answerSC.add(querySnapshotQuiz.docs[questionId]["option1"]);
        _plScoreSC.add(querySnapshotRoom[playerScore].toString());
        _opScoreSC.add(querySnapshotRoom[opScore].toString());

        Future.delayed(const Duration(seconds: 5), () async {
          _answerSC.add("");
          _plScoreSC.add("");
          _opScoreSC.add("");
          gameRoom.update({"player1answered": false, "player2answered": false});
          showQuestion(roomId);
        });
      }
      else {
        //print("WAITING FOR OPPONENT TO ANSWER");
      }
    });
  }

  Widget build(BuildContext context) {
    String roomId = widget.roomId;
    if(questionId == 0){
      getDB(roomId);
      showQuestion(roomId);
    }

    return Scaffold(
      body: Column(
        children: [
          Center(child: SizedBox(height: 40)),
          StreamBuilder(
              stream: _questionSC.stream,
              builder: (context, snapshot) {
                if(snapshot.hasData) {
                  return FractionallySizedBox(widthFactor: 0.7, child: Flexible(child: Text(snapshot.data??'', style: TextStyle(color: Colors.white),)));
                } else {
                  return Text("");
                }
              }
          ),
          SizedBox(height: 40),
          StreamBuilder(
              stream: _option1SC.stream,
              builder: (context, snapshot) {
                if(snapshot.hasData){
                  if(snapshot.data.toString() != "")
                    return TextButton(onPressed: () => answer(roomId, snapshot.data.toString()), child: Text("A: " + snapshot.data.toString()));
                  else
                    return Text("");
                }
                else
                  return Text("");
              }
          ),
          StreamBuilder(
              stream: _option2SC.stream,
              builder: (context, snapshot) {
                if(snapshot.hasData){
                  if(snapshot.data.toString() != "")
                    return TextButton(onPressed: () => answer(roomId, snapshot.data.toString()), child: Text("B: " + snapshot.data.toString()));
                  else
                    return Text("");
                }
                else
                  return Text("");
              }
          ),
          StreamBuilder(
              stream: _option3SC.stream,
              builder: (context, snapshot) {
                if(snapshot.hasData){
                  if(snapshot.data.toString() != "")
                    return TextButton(onPressed: () => answer(roomId, snapshot.data.toString()), child: Text("C: " + snapshot.data.toString()));
                  else
                    return Text("YOU PICKED YOUR ANSWER");
                  }
                  else
                    return Text("");
              }
          ),
          StreamBuilder(
              stream: _option4SC.stream,
              builder: (context, snapshot) {
                if(snapshot.hasData){
                  if(snapshot.data.toString() != "")
                    return TextButton(onPressed: () => answer(roomId, snapshot.data.toString()), child: Text("D: " + snapshot.data.toString()));
                  else
                    return Text("WAITING FOR OPPONENT TO ANSWER");
                }
                else
                  return Center(child: CircularProgressIndicator());
              }
          ),
          SizedBox(height: 40),
          StreamBuilder(
              stream: _timerSC.stream,
              builder: (context, snapshot) {
                if(snapshot.hasData) {
                  return Flexible(child: Text(snapshot.data.toString(), style: TextStyle(color: Colors.white)));
                } else {
                  return Flexible(child: Text(""));
                }
              }
          ),
          StreamBuilder(
              stream: _answerSC.stream,
              builder: (context, snapshot) {
                if(snapshot.hasData && snapshot.data.toString().isNotEmpty) {
                  return Flexible(child: Text("Answer: " + snapshot.data.toString(), style: TextStyle(color: Colors.white)));
                } else {
                  return Flexible(child: Text(""));
                }
              }
          ),
          StreamBuilder(
              stream: _plScoreSC.stream,
              builder: (context, snapshot) {
                if(snapshot.hasData && snapshot.data.toString().isNotEmpty) {
                  return Flexible(child: Text("Your Score: " + snapshot.data.toString(), style: TextStyle(color: Colors.white)));
                } else {
                  return Flexible(child: Text(""));
                }
              }
          ),
          StreamBuilder(
              stream: _opScoreSC.stream,
              builder: (context, snapshot) {
                if(snapshot.hasData && snapshot.data.toString().isNotEmpty) {
                  return Flexible(child: Text("Opponent Score: " + snapshot.data.toString(), style: TextStyle(color: Colors.white)));
                } else {
                  return Flexible(child: Text(""));
                }
              }
          ),
        ],
      )
    );
  }
}