import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'game_room_detail_page.dart';

class CreateGameRoomPage extends StatefulWidget {
  const CreateGameRoomPage({Key? key}) : super(key: key);

  @override
  State<CreateGameRoomPage> createState() => _CreateGameRoomPageState();
}

class _CreateGameRoomPageState extends State<CreateGameRoomPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _roomNameController = TextEditingController();
  
  String? _selectedQuizId;
  String? _selectedQuizTitle;
  List<Map<String, dynamic>> _userQuizzes = [];
  bool _isLoading = false;
  String _errorMessage = '';
  String? _userId;
  String _userName = 'User';
  int _selectedTimeLimit = 30; // Default 30 seconds
  int _selectedQuestionCount = 10; // Default 10 questions
  final List<int> _timeOptions = [15, 30, 60, 120, 180];
  int _selectedTime = 30;
  
  @override
  void initState() {
    super.initState();
    _userId = FirebaseAuth.instance.currentUser?.uid ?? 'dev_user_1234';
    _loadUserInfo();
    _loadUserQuizzes();
  }
  
  @override
  void dispose() {
    _roomNameController.dispose();
    super.dispose();
  }
  
  Future<void> _loadUserInfo() async {
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_userId)
          .get();
          
      if (userDoc.exists) {
        setState(() {
          _userName = userDoc.get('username') ?? 'User';
        });
      }
    } catch (e) {
      print('Error loading user info: $e');
    }
  }
  
  Future<void> _loadUserQuizzes() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Load all quizzes from the database instead of filtering by creatorId
      final querySnapshot = await FirebaseFirestore.instance
          .collection('quizzes')
          .orderBy('createdAt', descending: true)
          .get();
          
      setState(() {
        _userQuizzes = querySnapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'quizId': doc.id,
            'title': data['title'] ?? 'Untitled Quiz',
            'questionCount': data['questionCount'] ?? 0,
            'creatorEmail': data['creatorEmail'] ?? 'Unknown',  // Add creator info
          };
        }).toList();
        
        // Sort by quiz title
        _userQuizzes.sort((a, b) => a['title'].compareTo(b['title']));
        
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load quizzes: $e';
        _isLoading = false;
      });
    }
  }
  
  Future<void> _createRoom() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_selectedQuizId == null) {
      setState(() {
        _errorMessage = 'Please select a quiz for this room';
      });
      return;
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    
    try {
      // Create a new game room document
      DocumentReference roomRef = await FirebaseFirestore.instance.collection('gameRooms').add({
        'roomName': _roomNameController.text.trim(),
        'creatorId': _userId,
        'creatorName': _userName,
        'quizId': _selectedQuizId,
        'quizTitle': _selectedQuizTitle,
        'isActive': true,
        'hasStarted': false,
        'players': [],
        'timeLimit': _selectedTimeLimit,
        'questionCount': _selectedQuestionCount,
        'currentQuestion': 0,
        'scores': {},
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      // Navigate to the game room page
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => GameRoomDetailPage(
            roomId: roomRef.id,
            roomName: _roomNameController.text.trim(),
            isCreator: true,
          ),
        ),
      );
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to create room: $e';
        _isLoading = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Game Room'),
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
            padding: const EdgeInsets.all(20.0),
            child: Container(
              width: 400,
              padding: const EdgeInsets.all(24.0),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.8),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Create a Game Room',
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
                    
                    // Room name field
                    const Text(
                      'Room Name',
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
                        controller: _roomNameController,
                        decoration: const InputDecoration(
                          hintText: 'Enter a name for your game room',
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 15,
                          ),
                          border: InputBorder.none,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a room name';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // Quiz selection
                    const Text(
                      'Select Quiz',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _userQuizzes.isEmpty
                            ? Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.grey[800],
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Column(
                                  children: [
                                    const Text(
                                      'You haven\'t created any quizzes yet.',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 10),
                                    ElevatedButton(
                                      onPressed: () {
                                        Navigator.pop(context);
                                        Navigator.pushNamed(context, '/create_quiz');
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.deepOrange,
                                      ),
                                      child: const Text('Create a Quiz'),
                                    ),
                                  ],
                                ),
                              )
                            : Container(
                                height: 200,
                                decoration: BoxDecoration(
                                  color: Colors.grey[900],
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: ListView.builder(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  itemCount: _userQuizzes.length,
                                  itemBuilder: (context, index) {
                                    final quiz = _userQuizzes[index];
                                    final isSelected = _selectedQuizId == quiz['quizId'];
                                    
                                    return ListTile(
                                      title: Text(
                                        quiz['title'],
                                        style: const TextStyle(
                                          color: Colors.white,
                                        ),
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${quiz['questionCount']} question${quiz['questionCount'] != 1 ? 's' : ''}',
                                            style: const TextStyle(
                                              color: Colors.grey,
                                            ),
                                          ),
                                          Text(
                                            'Created by: ${quiz['creatorEmail']}',
                                            style: const TextStyle(
                                              color: Colors.grey,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                      trailing: isSelected
                                          ? const Icon(Icons.check_circle, color: Colors.deepOrange)
                                          : null,
                                      onTap: () {
                                        setState(() {
                                          _selectedQuizId = quiz['quizId'];
                                          _selectedQuizTitle = quiz['title'];
                                        });
                                      },
                                      tileColor: isSelected ? Colors.deepOrange.withOpacity(0.2) : null,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    );
                                  },
                                ),
                              ),
                    
                    const SizedBox(height: 20),
                    
                    // Time limit selection
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Time Limit per Question',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[800],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              value: _selectedTime,
                              dropdownColor: Colors.grey[800],
                              icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                              isExpanded: true,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              items: _timeOptions.map((int value) {
                                return DropdownMenuItem<int>(
                                  value: value,
                                  child: Text(
                                    '$value seconds',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                    ),
                                  ),
                                );
                              }).toList(),
                              onChanged: (int? newValue) {
                                if (newValue != null) {
                                  setState(() {
                                    _selectedTime = newValue;
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Question count selection
                    const Text(
                      'Number of Questions',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ...['10', '20', 'All'].map((count) {
                          return ChoiceChip(
                            label: Text(count),
                            selected: _selectedQuestionCount == (count == 'All' ? -1 : int.parse(count)),
                            onSelected: (selected) {
                              if (selected) {
                                setState(() {
                                  _selectedQuestionCount = count == 'All' ? -1 : int.parse(count);
                                });
                              }
                            },
                            backgroundColor: Colors.grey[800],
                            selectedColor: Colors.deepOrange,
                            labelStyle: TextStyle(
                              color: _selectedQuestionCount == (count == 'All' ? -1 : int.parse(count)) 
                                  ? Colors.white 
                                  : Colors.grey[300],
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                    
                    const SizedBox(height: 30),
                    
                    // Create button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _createRoom,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepOrange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Create Room'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
} 