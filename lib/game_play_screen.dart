import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';

class GamePlayScreen extends StatefulWidget {
  final String roomId;
  final String quizId;
  final int timeLimit;
  final int questionCount;
  
  const GamePlayScreen({
    Key? key,
    required this.roomId,
    required this.quizId,
    required this.timeLimit,
    required this.questionCount,
  }) : super(key: key);

  @override
  State<GamePlayScreen> createState() => _GamePlayScreenState();
}

class _GamePlayScreenState extends State<GamePlayScreen> {
  List<Map<String, dynamic>> _questions = [];
  int _currentQuestionIndex = 0;
  Timer? _timer;
  int _timeRemaining = 0;
  Map<String, int> _scores = {};
  bool _hasAnswered = false;
  late StreamSubscription _roomSubscription;
  List<String> _shuffledChoices = [];
  String? _userId;
  String? _selectedAnswer;
  bool _isLoading = true;
  bool _gameEnded = false;
  bool _resultsShown = false;
  Map<String, String> _players = {};
  bool _showingCorrectAnswer = false;
  Timer? _correctAnswerTimer;
  
  final _buttonStyle = ElevatedButton.styleFrom(
    backgroundColor: Colors.deepOrange.withOpacity(0.8),
    foregroundColor: Colors.white,
    padding: const EdgeInsets.symmetric(vertical: 16),
    minimumSize: const Size(double.infinity, 56),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
    ),
  );

  @override
  void initState() {
    super.initState();
    _userId = FirebaseAuth.instance.currentUser?.uid;
    _initializeGame();
  }

  Future<void> _initializeGame() async {
    try {
      // Load questions
      final questionsSnapshot = await FirebaseFirestore.instance
          .collection('quizzes')
          .doc(widget.quizId)
          .collection('questions')
          .orderBy('createdAt')
          .get();

      if (!mounted) return;

      setState(() {
        _questions = questionsSnapshot.docs
            .map((doc) => doc.data())
            .toList();
        _isLoading = false;
        _timeRemaining = widget.timeLimit;
      });
      _shuffleCurrentQuestionChoices();

      // Start listening to room updates
      _roomSubscription = FirebaseFirestore.instance
          .collection('gameRooms')
          .doc(widget.roomId)
          .snapshots()
          .listen(_handleRoomUpdate);

      // Start timer for first question
      _startTimer();
    } catch (e) {
      print('Error initializing game: $e');
    }
  }

  void _handleRoomUpdate(DocumentSnapshot snapshot) {
    if (!snapshot.exists || !mounted) return;

    final data = snapshot.data() as Map<String, dynamic>;
    final newQuestionIndex = data['currentQuestion'] ?? 0;
    final hasStarted = data['hasStarted'] ?? false;
    final scores = Map<String, int>.from(data['scores'] ?? {});
    final players = List<Map<String, dynamic>>.from(data['players'] ?? []);
    final answeredPlayers = List<Map<String, dynamic>>.from(data['answeredPlayers'] ?? []);
    final showingCorrectAnswer = data['showingCorrectAnswer'] ?? false;
    final gameEnded = data['gameEnded'] ?? false;

    // If game has ended, show results
    if (gameEnded && !_resultsShown) {
      _showResults(players, scores);
      return;
    }

    // If moving to new question, reset all answer-related state first
    if (newQuestionIndex != _currentQuestionIndex) {
      setState(() {
        _currentQuestionIndex = newQuestionIndex;
        _hasAnswered = false;
        _selectedAnswer = null;
        _showingCorrectAnswer = false;
        _timeRemaining = widget.timeLimit;
        _shuffledChoices = []; // Clear choices before reshuffling
      });
      
      // After state is cleared, load new question's choices
      _shuffleCurrentQuestionChoices();
      _startTimer();
    }

    // Update other state that doesn't affect answer selection
    setState(() {
      _scores = scores;
      _showingCorrectAnswer = showingCorrectAnswer;
      _players = Map.fromEntries(players.map((p) => 
        MapEntry(p['playerId'] as String, p['playerName'] as String)
      ));
    });

    // Check if all players have answered
    if (answeredPlayers.length >= players.length + 1 && !_hasAnswered) {
      _showCorrectAnswerAndProgress();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timeRemaining = widget.timeLimit;
    
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_timeRemaining > 0) {
        setState(() {
          _timeRemaining--;
        });
      } else {
        timer.cancel();
        if (!_hasAnswered) {
          await _handleAnswer('');
        }
      }
    });
  }

  Future<void> _handleAnswer(String choice) async {
    if (_hasAnswered) return;

    setState(() {
      _selectedAnswer = choice;
      _hasAnswered = true;
    });

    try {
      final isCorrect = choice == _questions[_currentQuestionIndex]['correctAnswer'];
      
      await FirebaseFirestore.instance
          .collection('gameRooms')
          .doc(widget.roomId)
          .update({
        'answeredPlayers': FieldValue.arrayUnion([{
          'playerId': _userId,
          'answer': choice,
          'isCorrect': isCorrect,
          'timestamp': Timestamp.now(),
        }])
      });

      // Check if all players have answered
      final roomDoc = await FirebaseFirestore.instance
          .collection('gameRooms')
          .doc(widget.roomId)
          .get();

      if (!roomDoc.exists) return;

      final data = roomDoc.data()!;
      final players = List<Map<String, dynamic>>.from(data['players'] ?? []);
      final answeredPlayers = List<Map<String, dynamic>>.from(data['answeredPlayers'] ?? []);

      // If all players have answered, show correct answer
      if (answeredPlayers.length >= players.length + 1) {
        await _showCorrectAnswerAndProgress();
      }
    } catch (e) {
      print('Error handling answer: $e');
    }
  }

  Future<void> _showCorrectAnswerAndProgress() async {
    try {
      // Update room to show correct answer to all players
      await FirebaseFirestore.instance
          .collection('gameRooms')
          .doc(widget.roomId)
          .update({
        'showingCorrectAnswer': true,
      });

      // Wait 5 seconds
      await Future.delayed(const Duration(seconds: 5));

      if (!mounted) return;

      // Move to next question
      await _moveToNextQuestion();
    } catch (e) {
      print('Error showing correct answer: $e');
    }
  }

  Future<void> _moveToNextQuestion() async {
    try {
      final roomDoc = await FirebaseFirestore.instance
          .collection('gameRooms')
          .doc(widget.roomId)
          .get();

      if (!roomDoc.exists) return;

      final data = roomDoc.data()!;
      final currentQuestion = data['currentQuestion'] ?? 0;
      final answeredPlayers = List<Map<String, dynamic>>.from(data['answeredPlayers'] ?? []);
      
      // Calculate scores
      Map<String, int> newScores = Map<String, int>.from(data['scores'] ?? {});
      int points = 11;

      answeredPlayers.sort((a, b) {
        final aTime = a['timestamp'] as Timestamp;
        final bTime = b['timestamp'] as Timestamp;
        return aTime.compareTo(bTime);
      });

      for (var player in answeredPlayers) {
        if (player['isCorrect'] == true) {
          String playerId = player['playerId'];
          newScores[playerId] = (newScores[playerId] ?? 0) + points;
          points = points > 0 ? points - 1 : 0;
        }
      }

      if (currentQuestion + 1 >= _questions.length) {
        await _endGame(newScores);
        return;
      }

      // Reset room state and move to next question
      await FirebaseFirestore.instance
          .collection('gameRooms')
          .doc(widget.roomId)
          .update({
        'currentQuestion': currentQuestion + 1,
        'scores': newScores,
        'answeredPlayers': [],
        'showingCorrectAnswer': false,
      });
    } catch (e) {
      print('Error moving to next question: $e');
    }
  }

  Future<void> _endGame(Map<String, int> finalScores) async {
    try {
      // Update room with final state
      await FirebaseFirestore.instance
          .collection('gameRooms')
          .doc(widget.roomId)
          .update({
        'isActive': false,
        'hasStarted': false,
        'scores': finalScores,
        'gameEnded': true,
      });

      if (!mounted) return;
      
      // Don't show results here - will be triggered by room update
    } catch (e) {
      print('Error ending game: $e');
    }
  }

  void _showResults(List<Map<String, dynamic>> players, Map<String, int> scores) {
    if (_resultsShown) return;
    _resultsShown = true;

    // Get the room creator info
    FirebaseFirestore.instance
        .collection('gameRooms')
        .doc(widget.roomId)
        .get()
        .then((roomDoc) {
      if (!roomDoc.exists) return;

      final data = roomDoc.data()!;
      final creatorId = data['creatorId'] as String;
      final creatorName = data['creatorName'] as String;

      // Combine creator and players into one list
      final allPlayers = [
        {'playerId': creatorId, 'playerName': creatorName},
        ...players,
      ];

      // Create scores map for all participants
      final allScores = Map<String, int>.fromEntries(
        allPlayers.map((player) => MapEntry(
          player['playerId'] as String,
          scores[player['playerId']] ?? 0
        ))
      );

      // Sort by score
      final sortedScores = allScores.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      // Show results dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text(
            'Game Results',
            style: TextStyle(color: Colors.white),
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: sortedScores.map((entry) {
              // Find player name from allPlayers list
              final player = allPlayers.firstWhere(
                (p) => p['playerId'] == entry.key,
                orElse: () => {'playerName': 'Unknown Player'},
              );
              
              return ListTile(
                title: Text(
                  player['playerName'] as String,
                  style: const TextStyle(color: Colors.white),
                ),
                trailing: Text(
                  'Score: ${entry.value}',
                  style: const TextStyle(
                    color: Colors.deepOrange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            }).toList(),
          ),
          actions: [
            Center(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Close dialog
                  Navigator.of(context).pop(); // Return to room
                },
                style: _buttonStyle,
                child: const Text(
                  'Back to Room',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  void _shuffleCurrentQuestionChoices() {
    if (_questions.isEmpty || _currentQuestionIndex >= _questions.length) {
      setState(() {
        _shuffledChoices = [];
      });
      return;
    }
    
    // Always shuffle on new question, regardless of answer state
    final choices = List<String>.from(_questions[_currentQuestionIndex]['choices'] ?? []);
    choices.shuffle();
    setState(() {
      _shuffledChoices = choices;
    });
  }

  Widget _buildAnswerButton(String choice) {
    final isSelected = _hasAnswered && choice == _selectedAnswer;
    final isCorrect = choice == _questions[_currentQuestionIndex]['correctAnswer'];
    final showCorrect = _showingCorrectAnswer && isCorrect;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: ElevatedButton(
        onPressed: _hasAnswered ? null : () => _handleAnswer(choice),
        style: _buttonStyle.copyWith(
          backgroundColor: MaterialStateProperty.all(
            showCorrect ? Colors.green.withOpacity(0.8) :
            isSelected ? Colors.white.withOpacity(0.9) : 
            Colors.deepOrange.withOpacity(0.8),
          ),
        ),
        child: Text(
          choice,
          style: TextStyle(
            color: isSelected ? Colors.deepOrange : Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _correctAnswerTimer?.cancel();
    _roomSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_questions.isEmpty) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final currentQuestion = _questions[_currentQuestionIndex];
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Question ${_currentQuestionIndex + 1}/${_questions.length}'),
        backgroundColor: Colors.deepOrange,
        automaticallyImplyLeading: false,
      ),
      body: Container(
        decoration: BoxDecoration(
          color: Colors.black,
          image: DecorationImage(
            image: const AssetImage('assets/bg.jpeg'),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              Colors.black.withOpacity(0.7),
              BlendMode.srcOver,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Timer
              LinearProgressIndicator(
                value: _timeRemaining / widget.timeLimit,
                backgroundColor: Colors.grey[800],
                valueColor: AlwaysStoppedAnimation<Color>(
                  _timeRemaining < 5 ? Colors.red : Colors.deepOrange,
                ),
              ),
              const SizedBox(height: 20),
              
              // Question
              Card(
                color: Colors.black87,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    currentQuestion['questionText'],
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Answers
              Expanded(
                child: ListView.builder(
                  itemCount: _shuffledChoices.length,
                  itemBuilder: (context, index) {
                    return _buildAnswerButton(_shuffledChoices[index]);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 