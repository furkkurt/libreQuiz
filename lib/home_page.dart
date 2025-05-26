import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'quiz_creator_page.dart';
import 'question_editor_page.dart';
import 'game_rooms_page.dart';
import 'web_layout_helper.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'profile_page.dart';
import 'friends_list_page.dart';
import 'game_room_detail_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? _userId;
  bool _isLoading = false;
  bool _showMyQuizzes = false; // Track visibility of quiz list

  final _buttonStyle = ElevatedButton.styleFrom(
    padding: const EdgeInsets.symmetric(vertical: 16),
    minimumSize: const Size(double.infinity, 56), // Full width
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
  );

  @override
  void initState() {
    super.initState();
    _initializeUserId();
    _listenForGameInvites();
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

  void _listenForGameInvites() {
    if (_userId == null) return;

    // Listen for new notifications in real-time
    FirebaseFirestore.instance
        .collection('notifications')
        .where('receiverId', isEqualTo: _userId)
        .where('type', isEqualTo: 'game_invite')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        // Only show for new notifications
        if (change.type == DocumentChangeType.added) {
          _showGameInvite(change.doc);
        }
      }
    });
  }

  void _showGameInvite(DocumentSnapshot invite) async {
    try {
      // Get sender's info
      final senderDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(invite.get('senderId'))
          .get();

      if (!mounted) return;

      // Check if notification is still pending
      final currentNotification = await invite.reference.get();
      if (currentNotification.get('status') != 'pending') return;

      // Check if room still exists
      final roomDoc = await FirebaseFirestore.instance
          .collection('gameRooms')
          .doc(invite.get('roomId'))
          .get();

      if (!roomDoc.exists) {
        if (!mounted) return;
        await invite.reference.update({'status': 'room_closed'});
        return;
      }

      if (!mounted) return;
      final BuildContext dialogContext = context;
      
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) => AlertDialog(
          backgroundColor: Colors.grey[900],
          title: Row(
            children: [
              const Icon(Icons.videogame_asset, color: Colors.deepOrange),
              const SizedBox(width: 10),
              const Text(
                'Game Invite',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${senderDoc.get('username')} invited you to join:',
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 8),
              Text(
                invite.get('roomName'),
                style: const TextStyle(
                  color: Colors.deepOrange,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                invite.reference.update({'status': 'declined'});
              },
              child: const Text('Decline'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  print('DEBUG: Accepting game invite');
                  // First update the status
                  await invite.reference.update({'status': 'accepted'});
                  print('DEBUG: Updated invite status to accepted');

                  // Get room data first to verify it exists
                  final roomDoc = await FirebaseFirestore.instance
                      .collection('gameRooms')
                      .doc(invite.get('roomId'))
                      .get();

                  if (!roomDoc.exists) {
                    print('DEBUG: Room does not exist when accepting invite');
                    if (context.mounted) {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Room no longer exists')),
                      );
                    }
                    return;
                  }

                  // Close dialog first
                  Navigator.of(context).pop();

                  if (!mounted) return;

                  print('DEBUG: Navigating to game room ${invite.get('roomId')}');
                  // Then navigate to game room using pushAndRemoveUntil to clear the stack
                  await Navigator.of(dialogContext).pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (context) => GameRoomDetailPage(
                        roomId: invite.get('roomId'),
                        roomName: invite.get('roomName'),
                        isCreator: false,
                      ),
                    ),
                    (route) => route.isFirst, // Keep only the first route (home)
                  );
                } catch (e) {
                  print('DEBUG: Error accepting invite: $e');
                  if (context.mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error joining room: $e')),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange,
              ),
              child: const Text('Join Game'),
            ),
          ],
        ),
      );
    } catch (e) {
      print('Error showing game invite: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = WebLayoutHelper.isWeb;
    final fontSizeMultiplier = WebLayoutHelper.getFontSizeMultiplier(context);
    final buttonSizeMultiplier = WebLayoutHelper.getButtonSizeMultiplier(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Libre Quiz',
          style: TextStyle(
            fontSize: isWeb ? 24 * fontSizeMultiplier : 20,
          ),
        ),
        backgroundColor: Colors.deepOrange,
        actions: [
          // Profile Button
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfilePage()),
              );
            },
          ),
          // Friends Button
          IconButton(
            icon: const Icon(Icons.people),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const FriendsListPage()),
              );
            },
          ),
          // Logout Button
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              FirebaseAuth.instance.signOut();
              Navigator.of(context).pushReplacementNamed('/login');
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black,
                image: DecorationImage(
                  image: const AssetImage('assets/bg.jpeg'),
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                  colorFilter: ColorFilter.mode(
                    Colors.black.withOpacity(0.7),
                    BlendMode.srcOver,
                  ),
                ),
              ),
            ),
          ),
          WebLayoutHelper.wrapResponsive(
            context,
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo
                Center(
                  child: Image.asset(
                    'assets/logo.png',
                    width: isWeb ? 180 * buttonSizeMultiplier : 120,
                    height: isWeb ? 180 * buttonSizeMultiplier : 120,
                  ),
                ),
                
                SizedBox(height: isWeb ? 40 : 20),
                
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32.0), // Consistent padding
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch, // Make children full width
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const GameRoomsPage()),
                          );
                        },
                        icon: const Icon(Icons.videogame_asset, color: Colors.white),
                        label: const Text(
                          'Game Rooms',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: _buttonStyle.copyWith(
                          backgroundColor: MaterialStateProperty.all(Colors.deepPurple),
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const QuizCreatorPage()),
                          );
                        },
                        icon: const Icon(Icons.add, color: Colors.white),
                        label: const Text(
                          'Create Quiz',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: _buttonStyle.copyWith(
                          backgroundColor: MaterialStateProperty.all(Colors.deepOrange),
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            _showMyQuizzes = !_showMyQuizzes;
                          });
                        },
                        icon: const Icon(Icons.list, color: Colors.white),
                        label: const Text(
                          'My Quizzes',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: _buttonStyle.copyWith(
                          backgroundColor: MaterialStateProperty.all(Colors.teal),
                        ),
                      ),
                    ],
                  ),
                ),
                
                SizedBox(height: isWeb ? 30 : 20),
                
                if (_showMyQuizzes) ...[
                  SizedBox(height: isWeb ? 30 : 20),
                  _buildQuizList(),
                ]
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuizList() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(15),
      ),
      child: _isLoading
        ? const Center(child: CircularProgressIndicator())
        : StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('quizzes')
                .where('creatorId', isEqualTo: _userId)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Text('Error: ${snapshot.error}',
                    style: const TextStyle(color: Colors.white));
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final quizzes = snapshot.data?.docs ?? [];
              
              if (quizzes.isEmpty) {
                return const Text(
                  'You haven\'t created any quizzes yet.',
                  style: TextStyle(color: Colors.white),
                );
              }

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: quizzes.length,
                itemBuilder: (context, index) {
                  final quiz = quizzes[index].data() as Map<String, dynamic>;
                  final quizId = quizzes[index].id;
                  
                  return ListTile(
                    title: Text(
                      quiz['title'] ?? 'Untitled Quiz',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      'Questions: ${quiz['questionCount'] ?? 0}',
                      style: TextStyle(color: Colors.grey[300]),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit, color: Colors.white),
                      onPressed: () => _editQuiz(quizId, quiz['title']),
                    ),
                  );
                },
              );
            },
          ),
    );
  }

  void _editQuiz(String quizId, String quizTitle) {
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
} 