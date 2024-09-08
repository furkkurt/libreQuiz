import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:libre_quiz/screens/home_screen.dart';

import 'login_screen.dart';

class AddQuestionScreen extends StatefulWidget {
  const AddQuestionScreen({super.key});

  @override
  State<AddQuestionScreen> createState() => _AddQuestionScreenState();
}

class _AddQuestionScreenState extends State<AddQuestionScreen> {
  final TextEditingController _questionController = TextEditingController();
  final TextEditingController _option1Controller = TextEditingController();
  final TextEditingController _option2Controller = TextEditingController();
  final TextEditingController _option3Controller = TextEditingController();
  final TextEditingController _option4Controller = TextEditingController();
  List<String> categories = ["option1", "option2"];
  String selectedCategory = "option1";
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
    CollectionReference quizes = FirebaseFirestore.instance.collection('quizes');

    await quizes.add({
      'category': selectedCategory,
      'question': _questionController.text,
      'option1': _option1Controller.text,
      'option2': _option2Controller.text,
      'option3': _option3Controller.text,
      'option4': _option4Controller.text,
      'answer': correctOption
    });
  }

  void getCategories() async{
    CollectionReference categoriesDB = FirebaseFirestore.instance.collection('categories');
    QuerySnapshot querySnapshot = await categoriesDB.get();

    querySnapshot.docs.forEach((doc) {
      categories.add(doc["name"]);
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
          DropdownButton<String>(
            value: selectedCategory,
            onChanged: (String? newValue) {
              setState(() {
                selectedCategory = newValue!;
              });
            },
            items: categories.map<DropdownMenuItem<String>>((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value),
              );
            }).toList(),
          ),
          TextField(
            controller: _questionController,
            decoration: InputDecoration(
              labelText: "Question",
            ),
          ),
          TextField(
            controller: _option1Controller,
            decoration: InputDecoration(
              labelText: "Option 1",
            ),
          ),
          TextField(
            controller: _option2Controller,
            decoration: InputDecoration(
              labelText: "Option 2",
            ),
          ),
          TextField(
            controller: _option3Controller,
            decoration: InputDecoration(
              labelText: "Option 3",
            ),
          ),
          TextField(
            controller: _option4Controller,
            decoration: InputDecoration(
              labelText: "Option 4",
            ),
          ),
          DropdownButton(
            items: optionNums.map((int item){
              return DropdownMenuItem(
                value: item,
                child: Text(item.toString())
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
            onPressed: () => addQuestion(),
            child: Text("Add Question"),
          ),
        ],
      )
    );
  }
}