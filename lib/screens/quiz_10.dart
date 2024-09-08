import 'dart:async';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:libre_quiz/screens/home_screen.dart';

import 'login_screen.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});

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

  @override
  void initState() {
    setState(() {
      super.initState();
      showQuestion();
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

  void showQuestion() async {
    CollectionReference quizes = FirebaseFirestore.instance.collection('quizes');
    QuerySnapshot querySnapshot = await quizes.get();
    var questionId = Random().nextInt(querySnapshot.docs.length);

    _categorySC.add(querySnapshot.docs[questionId]['category']);
    _questionSC.add(querySnapshot.docs[questionId]['question']);
    _option1SC.add(querySnapshot.docs[questionId]['option1']);
    _option2SC.add(querySnapshot.docs[questionId]['option2']);
    _option3SC.add(querySnapshot.docs[questionId]['option3']);
    _option4SC.add(querySnapshot.docs[questionId]['option4']);
    realCorrectOption = querySnapshot.docs[questionId]['answer'];
  }

  void answer() {
    if (correctOption == realCorrectOption) {
      print("correct");
      score++;
    }
    else {
      print("false");
    }
    showQuestion();
  }

  Widget build(BuildContext context) {
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
            onPressed: () => showQuestion(),
            child: Text("Answer"),
          ),
        ],
      )
    );
  }
}