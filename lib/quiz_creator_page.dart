import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'question_editor_page.dart';
import 'dart:math';

class QuizCreatorPage extends StatefulWidget {
  const QuizCreatorPage({Key? key}) : super(key: key);

  @override
  State<QuizCreatorPage> createState() => _QuizCreatorPageState();
}

class _QuizCreatorPageState extends State<QuizCreatorPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  bool _isLoading = false;
  String _errorMessage = '';
  
  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }
  
  // Generate a unique quiz ID
  String _generateQuizId() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random();
    final result = StringBuffer('quiz_');
    
    for (var i = 0; i < 16; i++) {
      result.write(chars[random.nextInt(chars.length)]);
    }
    
    return result.toString();
  }
  
  Future<void> _createQuiz() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });
      
      try {
        // Get current user ID
        User? currentUser = FirebaseAuth.instance.currentUser;
        String creatorId;
        
        if (currentUser != null) {
          // Use the Firebase Auth UID
          creatorId = currentUser.uid;
          print("Using Firebase Auth UID: $creatorId");
        } else {
          // We're in dev mode - try to retrieve a consistent dev user ID from shared preferences
          // For now, create one with a consistent prefix
          creatorId = 'dev_user_1234';
          print("Using dev mode user ID: $creatorId");
        }
        
        // Generate a unique quiz ID
        String quizId = _generateQuizId();
        
        // Create quiz document in Firestore
        await FirebaseFirestore.instance.collection('quizzes').doc(quizId).set({
          'title': _titleController.text.trim(),
          'quizId': quizId,
          'creatorId': creatorId,
          'creatorEmail': currentUser?.email ?? 'dev@example.com',
          'questionCount': 0,
          'createdAt': FieldValue.serverTimestamp(),
        });
        
        // Also add this quiz to the user's list of quizzes
        await FirebaseFirestore.instance.collection('users').doc(creatorId).update({
          'quizzes': FieldValue.arrayUnion([quizId]),
        }).catchError((error) {
          // If the user document doesn't exist yet, create it
          print("User document not found, creating one: $error");
          return FirebaseFirestore.instance.collection('users').doc(creatorId).set({
            'username': currentUser?.displayName ?? 'Dev User',
            'email': currentUser?.email ?? 'dev@example.com',
            'profilePicture': '',
            'friends': [],
            'badges': {},
            'quizzes': [quizId],
            'createdAt': FieldValue.serverTimestamp(),
          });
        });
        
        // Navigate to question editor
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => QuestionEditorPage(quizId: quizId, quizTitle: _titleController.text),
          ),
        );
      } catch (e) {
        setState(() {
          _errorMessage = "Failed to create quiz: $e";
        });
        print("Error creating quiz: $e");
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Quiz'),
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: BoxDecoration(
          color: Colors.black,
          image: DecorationImage(
            image: const AssetImage('assets/bg.jpeg'),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              Colors.black.withOpacity(0.7), // 30% opacity of original image
              BlendMode.srcOver,
            ),
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Container(
                width: 400,
                padding: const EdgeInsets.all(24.0),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      const Text(
                        'Create a New Quiz',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),
                      
                      // Error message
                      if (_errorMessage.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.all(10),
                          margin: const EdgeInsets.only(bottom: 15),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.red.shade300),
                          ),
                          child: Text(
                            _errorMessage,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      
                      // Quiz title field
                      const Text(
                        'Quiz Title',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: TextFormField(
                          controller: _titleController,
                          decoration: const InputDecoration(
                            hintText: 'Enter a title for your quiz',
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 15,
                            ),
                            border: InputBorder.none,
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter a quiz title';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(height: 20),
                      
                     
                      // Create button
                      _isLoading 
                          ? const Center(child: CircularProgressIndicator(color: Colors.white))
                          : SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _createQuiz,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.deepOrange,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 15,
                                  ),
                                ),
                                child: const Text(
                                  'Create Quiz and Add Questions',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
} 