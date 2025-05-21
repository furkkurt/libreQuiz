import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class QuestionEditorPage extends StatefulWidget {
  final String quizId;
  final String quizTitle;
  
  const QuestionEditorPage({
    Key? key, 
    required this.quizId,
    required this.quizTitle,
  }) : super(key: key);

  @override
  State<QuestionEditorPage> createState() => _QuestionEditorPageState();
}

class _QuestionEditorPageState extends State<QuestionEditorPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _questionTextController = TextEditingController();
  final TextEditingController _imageUrlController = TextEditingController();
  final TextEditingController _correctAnswerController = TextEditingController();
  final TextEditingController _wrongAnswer1Controller = TextEditingController();
  final TextEditingController _wrongAnswer2Controller = TextEditingController();
  final TextEditingController _wrongAnswer3Controller = TextEditingController();
  
  bool _isLoading = false;
  String _errorMessage = '';
  int _currentQuestionIndex = 0;
  List<Map<String, dynamic>> _questions = [];
  int _totalQuestions = 0;
  List<String> _questionIds = [];
  String? _currentQuestionId;
  
  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }
  
  @override
  void dispose() {
    _questionTextController.dispose();
    _imageUrlController.dispose();
    _correctAnswerController.dispose();
    _wrongAnswer1Controller.dispose();
    _wrongAnswer2Controller.dispose();
    _wrongAnswer3Controller.dispose();
    super.dispose();
  }
  
  Future<void> _loadQuestions() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('quizzes')
          .doc(widget.quizId)
          .collection('questions')
          .orderBy('createdAt')
          .get();
          
      _questions = [];
      _questionIds = [];
      
      for (var doc in querySnapshot.docs) {
        _questions.add(doc.data());
        _questionIds.add(doc.id);
      }
      
      _totalQuestions = _questions.length;
      
      if (_totalQuestions > 0 && _currentQuestionIndex < _totalQuestions) {
        _loadQuestionData(_questions[_currentQuestionIndex]);
        _currentQuestionId = _questionIds[_currentQuestionIndex];
      } else {
        _clearForm();
        _currentQuestionId = null;
      }
    } catch (e) {
      print('Error loading questions: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  void _loadQuestionData(Map<String, dynamic> question) {
    _questionTextController.text = question['questionText'] ?? '';
    _imageUrlController.text = question['imageUrl'] ?? '';
    
    List<String> choices = List<String>.from(question['choices'] ?? []);
    String correctAnswer = question['correctAnswer'] ?? '';
    
    _correctAnswerController.text = correctAnswer;
    
    // Remove the correct answer from choices to get wrong answers
    choices.remove(correctAnswer);
    
    _wrongAnswer1Controller.text = choices.isNotEmpty ? choices[0] : '';
    _wrongAnswer2Controller.text = choices.length > 1 ? choices[1] : '';
    _wrongAnswer3Controller.text = choices.length > 2 ? choices[2] : '';
  }
  
  void _clearForm() {
    _questionTextController.clear();
    _imageUrlController.clear();
    _correctAnswerController.clear();
    _wrongAnswer1Controller.clear();
    _wrongAnswer2Controller.clear();
    _wrongAnswer3Controller.clear();
  }
  
  Future<void> _saveQuestion() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });
      
      try {
        // Create list of all choices (correct + wrong answers)
        List<String> choices = [
          _correctAnswerController.text.trim(),
          _wrongAnswer1Controller.text.trim(),
          _wrongAnswer2Controller.text.trim(),
          _wrongAnswer3Controller.text.trim(),
        ];
        
        // Create question data
        Map<String, dynamic> questionData = {
          'questionText': _questionTextController.text.trim(),
          'imageUrl': _imageUrlController.text.trim(),
          'choices': choices,
          'correctAnswer': _correctAnswerController.text.trim(),
          'timeLimit': 30, // Default time limit in seconds
          'updatedAt': FieldValue.serverTimestamp(),
        };
        
        // If creating a new question, add createdAt timestamp
        if (_currentQuestionId == null) {
          questionData['createdAt'] = FieldValue.serverTimestamp();
        }
        
        // Reference to the questions collection
        final questionsCollection = FirebaseFirestore.instance
            .collection('quizzes')
            .doc(widget.quizId)
            .collection('questions');
        
        if (_currentQuestionId == null) {
          // Create new question
          final docRef = await questionsCollection.add(questionData);
          
          // Update question count in quiz document
          await FirebaseFirestore.instance
              .collection('quizzes')
              .doc(widget.quizId)
              .update({
                'questionCount': FieldValue.increment(1),
              });
              
          // Add to local list and move to the new question
          setState(() {
            _questions.add(questionData);
            _questionIds.add(docRef.id);
            _totalQuestions++;
            _currentQuestionIndex = _totalQuestions - 1;
            _currentQuestionId = docRef.id;
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Question added successfully!')),
          );
        } else {
          // Update existing question
          await questionsCollection.doc(_currentQuestionId).update(questionData);
          
          // Update local data
          setState(() {
            _questions[_currentQuestionIndex] = questionData;
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Question updated successfully!')),
          );
        }
        
        // After saving, prepare for a new question
        _clearForm();
        setState(() {
          _currentQuestionIndex = _totalQuestions;
          _currentQuestionId = null;
        });
      } catch (e) {
        setState(() {
          _errorMessage = 'Failed to save question: $e';
        });
        print('Error saving question: $e');
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  void _navigateToQuestion(int index) {
    if (index >= 0 && index < _totalQuestions) {
      setState(() {
        _currentQuestionIndex = index;
        _loadQuestionData(_questions[index]);
        _currentQuestionId = _questionIds[index];
      });
    } else if (index == _totalQuestions) {
      // This is a new question
      _clearForm();
      setState(() {
        _currentQuestionIndex = index;
        _currentQuestionId = null;
      });
    }
  }
  
  Future<void> _deleteCurrentQuestion() async {
    if (_currentQuestionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot delete - this question hasn\'t been saved yet')),
      );
      return;
    }
    
    // Show confirmation dialog
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Question'),
        content: const Text('Are you sure you want to delete this question? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    ) ?? false;
    
    if (!shouldDelete) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Delete from Firestore
      await FirebaseFirestore.instance
          .collection('quizzes')
          .doc(widget.quizId)
          .collection('questions')
          .doc(_currentQuestionId)
          .delete();
      
      // Update question count
      await FirebaseFirestore.instance
          .collection('quizzes')
          .doc(widget.quizId)
          .update({
            'questionCount': FieldValue.increment(-1),
          });
      
      // Remove from local lists
      setState(() {
        _questions.removeAt(_currentQuestionIndex);
        _questionIds.removeAt(_currentQuestionIndex);
        _totalQuestions--;
        
        // Adjust current index if needed
        if (_currentQuestionIndex >= _totalQuestions) {
          _currentQuestionIndex = _totalQuestions > 0 ? _totalQuestions - 1 : 0;
        }
        
        // Load the next question or clear form
        if (_totalQuestions > 0) {
          _loadQuestionData(_questions[_currentQuestionIndex]);
          _currentQuestionId = _questionIds[_currentQuestionIndex];
        } else {
          _clearForm();
          _currentQuestionId = null;
        }
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Question deleted successfully')),
      );
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to delete question: $e';
      });
      print('Error deleting question: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Quiz: ${widget.quizTitle}'),
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: const AssetImage('assets/bg.jpeg'),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              Colors.black.withOpacity(0.6),
              BlendMode.darken,
            ),
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Container(
                width: 450,
                padding: const EdgeInsets.all(24.0),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
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
                      
                      // Question text field
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: TextFormField(
                          controller: _questionTextController,
                          decoration: const InputDecoration(
                            hintText: 'Enter question text:',
                            hintStyle: TextStyle(color: Colors.black),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 15,
                            ),
                            border: InputBorder.none,
                          ),
                          style: const TextStyle(color: Colors.black),
                          maxLines: 5,
                          minLines: 3,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter a question';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(height: 20),
                      
                      // Image URL field
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: TextFormField(
                          controller: _imageUrlController,
                          decoration: const InputDecoration(
                            hintText: 'Enter image link (optional)',
                            hintStyle: TextStyle(color: Colors.black),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 15,
                            ),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      
                      // Correct answer field
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: TextFormField(
                          controller: _correctAnswerController,
                          decoration: const InputDecoration(
                            hintText: 'Enter correct answer',
                            hintStyle: TextStyle(color: Colors.black),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 15,
                            ),
                            border: InputBorder.none,
                          ),
                          style: const TextStyle(color: Colors.white),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter the correct answer';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(height: 15),
                      
                      // Wrong answer 1 field
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.red.shade700,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: TextFormField(
                          controller: _wrongAnswer1Controller,
                          decoration: const InputDecoration(
                            hintText: 'Enter first wrong answer',
                            hintStyle: TextStyle(color: Colors.black),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 15,
                            ),
                            border: InputBorder.none,
                          ),
                          style: const TextStyle(color: Colors.white),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter a wrong answer';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(height: 15),
                      
                      // Wrong answer 2 field
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.red.shade700,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: TextFormField(
                          controller: _wrongAnswer2Controller,
                          decoration: const InputDecoration(
                            hintText: 'Enter second wrong answer',
                            hintStyle: TextStyle(color: Colors.black),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 15,
                            ),
                            border: InputBorder.none,
                          ),
                          style: const TextStyle(color: Colors.white),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter a wrong answer';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(height: 15),
                      
                      // Wrong answer 3 field
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.red.shade700,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: TextFormField(
                          controller: _wrongAnswer3Controller,
                          decoration: const InputDecoration(
                            hintText: 'Enter third wrong answer',
                            hintStyle: TextStyle(color: Colors.black),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 15,
                            ),
                            border: InputBorder.none,
                          ),
                          style: const TextStyle(color: Colors.white),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter a wrong answer';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(height: 30),
                      
                      // Navigation and Save buttons
                      _isLoading 
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Column(
                              children: [
                                // Navigation buttons
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    // First question
                                    IconButton(
                                      onPressed: _totalQuestions > 0 ? () => _navigateToQuestion(0) : null,
                                      icon: const Icon(Icons.keyboard_double_arrow_left, color: Colors.white),
                                      style: IconButton.styleFrom(
                                        backgroundColor: Colors.grey[800],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    
                                    // Previous question
                                    IconButton(
                                      onPressed: _currentQuestionIndex > 0 ? () => _navigateToQuestion(_currentQuestionIndex - 1) : null,
                                      icon: const Icon(Icons.keyboard_arrow_left, color: Colors.white),
                                      style: IconButton.styleFrom(
                                        backgroundColor: Colors.grey[800],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    
                                    // Question number
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: Colors.grey[800],
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        '${_currentQuestionIndex + 1}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    
                                    // Next question
                                    IconButton(
                                      onPressed: () => _navigateToQuestion(_currentQuestionIndex + 1),
                                      icon: const Icon(Icons.keyboard_arrow_right, color: Colors.white),
                                      style: IconButton.styleFrom(
                                        backgroundColor: Colors.grey[800],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    
                                    // Last question
                                    IconButton(
                                      onPressed: _totalQuestions > 0 ? () => _navigateToQuestion(_totalQuestions - 1) : null,
                                      icon: const Icon(Icons.keyboard_double_arrow_right, color: Colors.white),
                                      style: IconButton.styleFrom(
                                        backgroundColor: Colors.grey[800],
                                      ),
                                    ),
                                  ],
                                ),
                                
                                const SizedBox(height: 16),
                                
                                // Delete and Save buttons row
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    // Delete button (shown only for existing questions)
                                    if (_currentQuestionId != null)
                                      IconButton(
                                        onPressed: _deleteCurrentQuestion,
                                        icon: const Icon(Icons.delete, color: Colors.red),
                                        tooltip: 'Delete this question',
                                        style: IconButton.styleFrom(
                                          backgroundColor: Colors.grey[800],
                                        ),
                                      ),
                                    
                                    const SizedBox(width: 16),
                                    
                                    // Save button
                                    ElevatedButton(
                                      onPressed: _saveQuestion,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.deepOrange,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(30),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 20,
                                          vertical: 12,
                                        ),
                                      ),
                                      child: Text(
                                        _currentQuestionId == null ? 'Add Question' : 'Update Question',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                      
                      const SizedBox(height: 20),
                      Text(
                        'Total Questions: $_totalQuestions',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
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