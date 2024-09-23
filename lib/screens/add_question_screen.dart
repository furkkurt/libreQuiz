import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:libre_quiz/screens/home_screen.dart';

import 'login_screen.dart';

class AddQuestionScreen extends StatefulWidget {
  const AddQuestionScreen({super.key});

  @override
  State<AddQuestionScreen> createState() => _AddQuestionScreenState();
}

class _AddQuestionScreenState extends State<AddQuestionScreen> {
  StreamController<String> _categorySC= StreamController<String>();
  final TextEditingController _imageController = TextEditingController();
  final TextEditingController _questionController = TextEditingController();
  final TextEditingController _option1Controller = TextEditingController();
  final TextEditingController _option2Controller = TextEditingController();
  final TextEditingController _option3Controller = TextEditingController();
  final TextEditingController _option4Controller = TextEditingController();
  final TextEditingController _newCategoryController = TextEditingController();
  List<String> categories = ["Select"];
  String selectedCategory = "Select";
  var optionNums = [1, 2, 3, 4];
  int correctOption = 1;

  @override
  void initState() {
    setState(() {
      super.initState();
      getCategories();
    });
  }

  void addQuestion() async {
    CollectionReference quizes = FirebaseFirestore.instance.collection('quizes').doc(selectedCategory).collection('questions');

    if (_questionController.text != "" && _option1Controller.text != "" && _option2Controller.text != "" && _option3Controller.text != "" && _option4Controller.text != ""){
      await quizes.add({
        'question': _questionController.text,
        'image': _imageController.text,
        'option1': _option1Controller.text,
        'option2': _option2Controller.text,
        'option3': _option3Controller.text,
        'option4': _option4Controller.text,
      });

      _questionController.text = _option1Controller.text = _option2Controller.text = _option3Controller.text = _option4Controller.text = "";
    }
  }

  void getCategories() async{
    CollectionReference categoriesDB = FirebaseFirestore.instance.collection('quizes');
    QuerySnapshot querySnapshot = await categoriesDB.get();

    String categories = "Select/";
    querySnapshot.docs.forEach((doc) {
      if(FirebaseAuth.instance.currentUser?.uid == doc["owner"])
        categories += doc["name"] + "/";
    });
    categories = categories.substring(0, categories.length-1);
    selectedCategory = categories.split("/")[0];
    _categorySC.add(categories);
  }

  void addCategory() async {
    CollectionReference quizes = FirebaseFirestore.instance.collection('quizes');

    await quizes.doc(_newCategoryController.text).set({
      "name": _newCategoryController.text,
      "owner": FirebaseAuth.instance.currentUser!.uid
    });
  }

  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text("Add Question"),
      ),
      body: Column(
        children: [
          SizedBox(height: 40),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(child:
                TextField(
                  controller: _newCategoryController,
                  decoration: InputDecoration(
                    labelText: "New Category",
                  ),style: TextStyle(color: Colors.white),
                ),
              ),
              TextButton(onPressed: () => addCategory(), child: Text("Add new catgory")),
            ],
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
            controller: _imageController,
            decoration: InputDecoration(
              labelText: "Image Link (Optional)",
            ),style: TextStyle(color: Colors.white),
          ),
          TextField(
            controller: _questionController,
            decoration: InputDecoration(
              labelText: "Question",
            ),style: TextStyle(color: Colors.white),
          ),
          TextField(
            controller: _option1Controller,
            decoration: InputDecoration(
              labelText: "Option 1 (CORRECT ANSWER)",
            ),style: TextStyle(color: Colors.white),
          ),
          TextField(
            controller: _option2Controller,
            decoration: InputDecoration(
              labelText: "Option 2",
            ),style: TextStyle(color: Colors.white),
          ),
          TextField(
            controller: _option3Controller,
            decoration: InputDecoration(
              labelText: "Option 3",
            ),style: TextStyle(color: Colors.white),
          ),
          TextField(
            controller: _option4Controller,
            decoration: InputDecoration(
              labelText: "Option 4",
            ),style: TextStyle(color: Colors.white),
          ),
          TextButton(
            onPressed: () => addQuestion(),
            child: Text("Add Question"),
          ),
        ],
      )
    );
  }
}