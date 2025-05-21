import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'quiz_creator_page.dart';
import 'question_editor_page.dart';
import 'game_rooms_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? _userId;
  bool _isLoading = false;
  bool _showMyQuizzes = false; // Track visibility of quiz list

  @override
  void initState() {
    super.initState();
    _initializeUserId();
  }

  Future<void> _initializeUserId() async {
    // Get current user ID from Firebase Auth
    User? currentUser = FirebaseAuth.instance.currentUser;
    
    if (currentUser != null) {
      // Use Firebase Auth user
      setState(() {
        _userId = currentUser.uid;
        print("Using Firebase Auth user ID: $_userId");
      });
    } else {
      // We're in dev mode - use a consistent dev user ID
      const devUserId = 'dev_user_1234';
      setState(() {
        _userId = devUserId;
        print("Using dev mode user ID: $_userId");
      });
      
      // Ensure the dev user exists in Firestore
      await _ensureDevUserExists(devUserId);
    }
  }

  Future<void> _ensureDevUserExists(String devUserId) async {
    try {
      // Check if the dev user document exists
      final docSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(devUserId)
          .get();
      
      if (!docSnapshot.exists) {
        // Create the dev user document
        await FirebaseFirestore.instance
            .collection('users')
            .doc(devUserId)
            .set({
              'username': 'Dev User',
              'email': 'dev@example.com',
              'profilePicture': '',
              'friends': [],
              'badges': {},
              'quizzes': [],
              'createdAt': FieldValue.serverTimestamp(),
            });
        print("Created dev user document");
      } else {
        print("Dev user document already exists");
      }
    } catch (e) {
      print("Error ensuring dev user exists: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Libre Quiz'),
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              // Simple logout functionality
              FirebaseAuth.instance.signOut();
              Navigator.of(context).pushReplacementNamed('/login');
            },
          ),
        ],
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
        child: Column(
          children: [
            // Main content section - Always takes available space when quiz list is hidden
            _showMyQuizzes 
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          'assets/logo.png',
                          height: 80, // Smaller when quiz list is shown
                        ),
                        const SizedBox(height: 16),
                        _buildActionButtons(),
                      ],
                    ),
                  )
                : Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.asset(
                              'assets/logo.png',
                              height: 120, // Larger when quiz list is hidden
                            ),
                            const SizedBox(height: 40),
                            _buildActionButtons(),
                          ],
                        ),
                      ),
                    ),
                  ),
            
            // My Quizzes section - only visible when toggled
            if (_showMyQuizzes)
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.8),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 10.0),
                          child: Text(
                            'My Quizzes',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        
                        // List of quizzes
                        Expanded(
                          child: _isLoading
                              ? const Center(child: CircularProgressIndicator())
                              : FutureBuilder<QuerySnapshot>(
                                  future: FirebaseFirestore.instance
                                      .collection('quizzes')
                                      .where('creatorId', isEqualTo: _userId)
                                      // Comment out the orderBy until the index is created
                                      // .orderBy('createdAt', descending: true)
                                      .get(),
                                  builder: (context, snapshot) {
                                    if (snapshot.connectionState == ConnectionState.waiting) {
                                      return const Center(child: CircularProgressIndicator());
                                    }
                                    
                                    if (snapshot.hasError) {
                                      String errorMessage = snapshot.error.toString();
                                      bool isIndexError = errorMessage.contains('FAILED_PRECONDITION') && 
                                                         errorMessage.contains('requires an index');
                                      
                                      if (isIndexError) {
                                        return Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.warning, color: Colors.amber, size: 36),
                                            const SizedBox(height: 10),
                                            const Text(
                                              'Index required for this query',
                                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                              textAlign: TextAlign.center,
                                            ),
                                            const SizedBox(height: 10),
                                            const Text(
                                              'Please create the required Firestore index using the Firebase console',
                                              style: TextStyle(color: Colors.white70),
                                              textAlign: TextAlign.center,
                                            ),
                                            const SizedBox(height: 10),
                                            Text(
                                              'Your quizzes are being shown without sorting order',
                                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                                              textAlign: TextAlign.center,
                                            ),
                                          ],
                                        );
                                      }
                                      
                                      return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
                                    }
                                    
                                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                                      return const Center(
                                        child: Text(
                                          'You haven\'t created any quizzes yet.',
                                          style: TextStyle(color: Colors.white70),
                                        ),
                                      );
                                    }
                                    
                                    // Display list of quizzes
                                    return ListView.builder(
                                      itemCount: snapshot.data!.docs.length,
                                      itemBuilder: (context, index) {
                                        final doc = snapshot.data!.docs[index];
                                        
                                        // Handle potential data issues
                                        try {
                                          final data = doc.data() as Map<String, dynamic>;
                                          final quizId = data['quizId'] as String? ?? doc.id;
                                          final title = data['title'] as String? ?? 'Untitled Quiz';
                                          final questionCount = data['questionCount'] as int? ?? 0;
                                          
                                          return Card(
                                            color: Colors.grey[850],
                                            margin: const EdgeInsets.symmetric(vertical: 8),
                                            child: ListTile(
                                              title: Text(
                                                title,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              subtitle: Text(
                                                '$questionCount question${questionCount != 1 ? 's' : ''}',
                                                style: const TextStyle(color: Colors.white70),
                                              ),
                                              trailing: IconButton(
                                                icon: const Icon(Icons.edit, color: Colors.deepOrange),
                                                onPressed: () => _editQuiz(quizId, title),
                                              ),
                                            ),
                                          );
                                        } catch (e) {
                                          // Handle corrupt data
                                          return Card(
                                            color: Colors.red[900],
                                            margin: const EdgeInsets.symmetric(vertical: 8),
                                            child: ListTile(
                                              title: const Text(
                                                'Error loading quiz',
                                                style: TextStyle(color: Colors.white),
                                              ),
                                              subtitle: Text(
                                                'Error: $e',
                                                style: const TextStyle(color: Colors.white70),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          );
                                        }
                                      },
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _editQuiz(String quizId, String quizTitle) {
    // Navigate to edit quiz page
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QuestionEditorPage(
          quizId: quizId,
          quizTitle: quizTitle,
        ),
      ),
    );
  }

  // Extract action buttons to a separate method
  Widget _buildActionButtons() {
    return Column(
      children: [

        // Game Rooms Button
        ElevatedButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const GameRoomsPage()),
            );
          },
          icon: const Icon(Icons.videogame_asset, color: Colors.white),
          label: const Text('Game Rooms'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.purple.withOpacity(0.7),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 12,
            ),
          ),
        ),
        
        const SizedBox(height: 20),

        // Create Quiz Button
        ElevatedButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const QuizCreatorPage()),
            );
          },
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text('Create Quiz'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepOrange.withOpacity(0.7),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 12,
            ),
          ),
        ),
        
        const SizedBox(height: 20),
        
        // My Quizzes toggle button
        ElevatedButton.icon(
          onPressed: () {
            setState(() {
              _showMyQuizzes = !_showMyQuizzes;
            });
          },
          icon: Icon(_showMyQuizzes ? Icons.close : Icons.list, color: Colors.white),
          label: Text(_showMyQuizzes ? 'Hide My Quizzes' : 'My Quizzes'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.cyan.withOpacity(0.7),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }
} 