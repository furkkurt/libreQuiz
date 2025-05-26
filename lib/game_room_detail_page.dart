import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'game_play_screen.dart';

class GameRoomDetailPage extends StatefulWidget {
  final String roomId;
  final String roomName;
  final bool isCreator;
  
  const GameRoomDetailPage({
    Key? key,
    required this.roomId,
    required this.roomName,
    required this.isCreator,
  }) : super(key: key);

  @override
  State<GameRoomDetailPage> createState() => _GameRoomDetailPageState();
}

class _GameRoomDetailPageState extends State<GameRoomDetailPage> {
  String? _userId;
  Map<String, dynamic>? _roomData;
  bool _isLoading = true;
  String? _errorMessage;
  StreamSubscription<DocumentSnapshot>? _roomSubscription;
  Map<String, Map<String, dynamic>> _playerStats = {};
  
  final _buttonStyle = ElevatedButton.styleFrom(
    backgroundColor: Colors.deepOrange,
    foregroundColor: Colors.white,
    padding: const EdgeInsets.symmetric(vertical: 16),
    minimumSize: const Size(0, 48), // Height only
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
    ),
  );
  
  @override
  void initState() {
    super.initState();
    _userId = FirebaseAuth.instance.currentUser?.uid;
    _initializeRoom();
    
    // Add periodic room existence check
    Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      try {
        final doc = await FirebaseFirestore.instance
            .collection('gameRooms')
            .doc(widget.roomId)
            .get();
            
        if (!doc.exists) {
          print('DEBUG: Room existence check failed - room ${widget.roomId} does not exist');
          // Instead of deleting, try to recreate the room
          await _recreateRoomIfNeeded(doc.id);
        }
      } catch (e) {
        print('DEBUG: Error in room existence check: $e');
      }
    });
  }
  
  @override
  void dispose() {
    print('DEBUG: Disposing GameRoomDetailPage');
    _roomSubscription?.cancel();
    super.dispose();
  }
  
  void _logRoomDeletion(String roomId) {
    print('''
DEBUG: ROOM DELETION DETECTED
Room ID: $roomId
Stack trace:
${StackTrace.current}
''');
  }
  
  Future<void> _initializeRoom() async {
    try {
      print('DEBUG: Initializing room ${widget.roomId}');
      
      // First get initial room data
      final initialRoomDoc = await FirebaseFirestore.instance
          .collection('gameRooms')
          .doc(widget.roomId)
          .get();

      if (!initialRoomDoc.exists) {
        print('DEBUG: Room not found during initialization');
        setState(() {
          _isLoading = false;
          _errorMessage = 'Room no longer exists';
        });
        return;
      }

      // Set initial room data
      if (mounted) {
        setState(() {
          _roomData = initialRoomDoc.data();
          _isLoading = false;
        });
      }

      // Then set up the listener
      _roomSubscription = FirebaseFirestore.instance
          .collection('gameRooms')
          .doc(widget.roomId)
          .snapshots()
          .listen((snapshot) {
            if (!snapshot.exists) {
              _logRoomDeletion(widget.roomId);
              return;
            }

            final data = snapshot.data()!;
            
            // Check if game has started and navigate to game screen for non-creators
            if (data['hasStarted'] == true) {
              print('DEBUG: Game started, navigating to game screen');
              if (!mounted) return;
              
              // Replace current screen with game screen
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => GamePlayScreen(
                    roomId: widget.roomId,
                    quizId: data['quizId'],
                    timeLimit: data['timeLimit'] ?? 30,
                    questionCount: data['questionCount'] ?? 10,
                  ),
                ),
              );
              return; // Stop processing after navigation
            }

            if (!mounted) return;
            setState(() {
              _roomData = data;
              _isLoading = false;
            });
          }, onError: (error) {
            print('DEBUG: Error in room subscription: $error');
            setState(() {
              _errorMessage = 'Failed to load room data';
              _isLoading = false;
            });
          });

      // If we're not the creator and not already in the room, join it
      if (!widget.isCreator) {
        print('DEBUG: Non-creator joining room');
        final roomDoc = await FirebaseFirestore.instance
            .collection('gameRooms')
            .doc(widget.roomId)
            .get();

        print('DEBUG: Room exists: ${roomDoc.exists}');
        if (!roomDoc.exists) {
          print('DEBUG: Room not found when trying to join');
          setState(() {
            _isLoading = false;
            _errorMessage = 'Room no longer exists';
          });
          return;
        }

        final currentPlayers = List<Map<String, dynamic>>.from(roomDoc.data()?['players'] ?? []);
        final isAlreadyInRoom = currentPlayers.any((p) => p['playerId'] == _userId);
        print('DEBUG: Current players: $currentPlayers');
        print('DEBUG: User $_userId already in room: $isAlreadyInRoom');

        if (!isAlreadyInRoom) {
          print('DEBUG: Adding player to room');
          // Get current user's display name
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(_userId)
              .get();
          
          final displayName = userDoc.data()?['username'] ?? 'Player';
          print('DEBUG: Using display name: $displayName');

          // Add player to room
          await FirebaseFirestore.instance
              .collection('gameRooms')
              .doc(widget.roomId)
              .update({
                'players': FieldValue.arrayUnion([
                  {
                    'playerId': _userId,
                    'playerName': displayName,
                    'score': 0,
                  }
                ])
              });
          print('DEBUG: Successfully added player to room');
        }
      }
    } catch (e) {
      print('DEBUG: Error initializing room: $e');
      setState(() {
        _errorMessage = 'Failed to initialize room';
        _isLoading = false;
      });
    }
  }
  
  Future<void> _startGame() async {
    try {
      print('DEBUG: Starting game for room ${widget.roomId}');
      
      // Create a batch to ensure atomic updates
      final batch = FirebaseFirestore.instance.batch();
      final roomRef = FirebaseFirestore.instance
          .collection('gameRooms')
          .doc(widget.roomId);

      // Update room status
      batch.set(roomRef, {
        'hasStarted': true,
        'isActive': true,
        'currentQuestion': 0,
        'scores': {},
        'answeredPlayers': [],
        'createdAt': FieldValue.serverTimestamp(),
        'quizId': _roomData!['quizId'],
        'timeLimit': _roomData!['timeLimit'] ?? 30,
        'questionCount': _roomData!['questionCount'] ?? 10,
        'players': _roomData!['players'] ?? [],
        'creatorId': _userId,
        'creatorName': _roomData!['creatorName'],
        'roomName': widget.roomName,
        'quizTitle': _roomData!['quizTitle'],
      }, SetOptions(merge: true));

      // Commit the batch
      await batch.commit();

      // Add a small delay to ensure Firestore is updated
      await Future.delayed(const Duration(milliseconds: 500));

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => GamePlayScreen(
            roomId: widget.roomId,
            quizId: _roomData!['quizId'],
            timeLimit: _roomData!['timeLimit'] ?? 30,
            questionCount: _roomData!['questionCount'] ?? 10,
          ),
        ),
      );
    } catch (e, stackTrace) {
      print('DEBUG: Error starting game: $e');
      print('DEBUG: Stack trace: $stackTrace');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to start game: $e')),
      );
    }
  }
  
  Future<void> _leaveRoom() async {
    try {
      print('DEBUG: Leaving room ${widget.roomId}');
      print('DEBUG: Current user: $_userId');
      print('DEBUG: Is creator: ${widget.isCreator}');

      if (!widget.isCreator) {
        // Only remove the current player from the players list
        await FirebaseFirestore.instance
            .collection('gameRooms')
            .doc(widget.roomId)
            .update({
              'players': FieldValue.arrayRemove([
                {
                  'playerId': _userId,
                  'playerName': FirebaseAuth.instance.currentUser?.displayName ?? 'Player',
                  'score': 0,
                }
              ])
            });
      }
      
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      print('DEBUG: Error leaving room: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to leave room: $e')),
      );
    }
  }
  
  Future<void> _inviteFriends() async {
    if (_userId == null) return;

    // Get user's friends
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(_userId)
        .get();

    if (!userDoc.exists) return;

    final friends = List<String>.from(userDoc.data()?['friends'] ?? []);
    
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Invite Friends',
          style: TextStyle(color: Colors.white),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .where(FieldPath.documentId, whereIn: friends.isEmpty ? [''] : friends)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final friends = snapshot.data!.docs;
              if (friends.isEmpty) {
                return const Text(
                  'No friends to invite',
                  style: TextStyle(color: Colors.white),
                );
              }

              return ListView.builder(
                shrinkWrap: true,
                itemCount: friends.length,
                itemBuilder: (context, index) {
                  final friend = friends[index].data() as Map<String, dynamic>;
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: friend['profilePicture'] != null
                          ? NetworkImage(friend['profilePicture'])
                          : null,
                      child: friend['profilePicture'] == null
                          ? const Icon(Icons.person)
                          : null,
                    ),
                    title: Text(
                      friend['username'] ?? 'Unknown',
                      style: const TextStyle(color: Colors.white),
                    ),
                    onTap: () => _sendGameInvite(friends[index].id),
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _sendGameInvite(String friendId) async {
    try {
      // Check if an invite already exists
      final existingInvites = await FirebaseFirestore.instance
          .collection('notifications')
          .where('type', isEqualTo: 'game_invite')
          .where('senderId', isEqualTo: _userId)
          .where('receiverId', isEqualTo: friendId)
          .where('roomId', isEqualTo: widget.roomId)
          .where('status', isEqualTo: 'pending')
          .get();

      // If invite already exists, don't send another one
      if (existingInvites.docs.isNotEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invite already sent to this friend')),
        );
        return;
      }

      // Create game invite notification
      await FirebaseFirestore.instance
          .collection('notifications')
          .add({
            'type': 'game_invite',
            'senderId': _userId,
            'receiverId': friendId,
            'roomId': widget.roomId,
            'roomName': widget.roomName,
            'timestamp': FieldValue.serverTimestamp(),
            'status': 'pending',
          });

      if (!mounted) return;
      Navigator.pop(context); // Close invite dialog
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Game invite sent!')),
      );
    } catch (e) {
      print('Error sending game invite: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to send invite')),
      );
    }
  }
  
  Future<void> _recreateRoomIfNeeded(String roomId) async {
    try {
      // Only recreate if we're the creator
      if (!widget.isCreator) return;
      
      print('DEBUG: Attempting to recreate room $roomId');
      
      if (_roomData == null) {
        print('DEBUG: No room data available for recreation');
        return;
      }
      
      // Create a new room with the same data
      await FirebaseFirestore.instance
          .collection('gameRooms')
          .doc(roomId)
          .set({
            ..._roomData!,
            'isActive': true,
            'createdAt': FieldValue.serverTimestamp(),
          });
          
      print('DEBUG: Successfully recreated room $roomId');
    } catch (e) {
      print('DEBUG: Error recreating room: $e');
    }
  }
  
  Future<void> _loadPlayerStats() async {
    try {
      final roomDoc = await FirebaseFirestore.instance
          .collection('gameRooms')
          .doc(widget.roomId)
          .get();
          
      if (!roomDoc.exists) return;
      
      final data = roomDoc.data()!;
      final players = List<Map<String, dynamic>>.from(data['players'] ?? []);
      final categoryId = data['quizTitle'] ?? 'unknown';
      
      for (final player in players) {
        final statsDoc = await FirebaseFirestore.instance
            .collection('userStats')
            .doc(player['playerId'])
            .collection('categoryStats')
            .doc(categoryId)
            .get();
            
        if (statsDoc.exists) {
          setState(() {
            _playerStats[player['playerId']] = statsDoc.data()!;
          });
        }
      }
    } catch (e) {
      print('Error loading player stats: $e');
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.roomName),
          backgroundColor: Colors.deepOrange,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    
    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.roomName),
          backgroundColor: Colors.deepOrange,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
        ),
      );
    }
    
    final quizTitle = _roomData!['quizTitle'] ?? 'Unknown Quiz';
    final creatorName = _roomData!['creatorName'] ?? 'Unknown Host';
    final players = List<Map<String, dynamic>>.from(_roomData!['players'] ?? []);
    final hasStarted = _roomData!['hasStarted'] ?? false;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.roomName),
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
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Room info card
              Card(
                color: Colors.black.withOpacity(0.8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.roomName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Quiz: $quizTitle',
                        style: TextStyle(
                          color: Colors.deepOrange[100],
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Host: $creatorName',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            hasStarted ? Icons.play_circle : Icons.pause_circle,
                            color: hasStarted ? Colors.green : Colors.orange,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            hasStarted ? 'Game in progress' : 'Waiting for players',
                            style: TextStyle(
                              color: hasStarted ? Colors.green : Colors.orange,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Players section
              const Text(
                'Players',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              
              Expanded(
                child: Card(
                  color: Colors.black.withOpacity(0.7),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ListView(
                    padding: const EdgeInsets.all(8.0),
                    children: [
                      // Host (creator)
                      ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Colors.deepOrange,
                          child: Icon(Icons.person, color: Colors.white),
                        ),
                        title: Text(
                          creatorName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: const Text(
                          'Host',
                          style: TextStyle(color: Colors.deepOrange),
                        ),
                      ),
                      
                      // Other players
                      ...players.map((player) {
                        final playerName = player['playerName'] ?? 'Unknown Player';
                        final stats = _playerStats[player['playerId']] ?? {
                          'firstPlaceCount': 0,
                          'gamesPlayed': 0
                        };
                        return ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Colors.grey,
                            child: Icon(Icons.person, color: Colors.white),
                          ),
                          title: Text(
                            playerName,
                            style: const TextStyle(color: Colors.white),
                          ),
                          subtitle: Text(
                            'First Place: ${stats['firstPlaceCount']} | Games: ${stats['gamesPlayed']}',
                            style: const TextStyle(color: Colors.grey),
                          ),
                        );
                      }).toList(),
                      
                      if (players.isEmpty && _roomData!['creatorId'] != _userId)
                        const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text(
                            'No other players have joined yet',
                            style: TextStyle(color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Action buttons
              Row(
                children: [
                  if (widget.isCreator) ...[
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: hasStarted ? null : _startGame,
                        icon: const Icon(Icons.play_arrow, color: Colors.white),
                        label: const Text(
                          'Start Game',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: _buttonStyle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _inviteFriends,
                        icon: const Icon(Icons.person_add, color: Colors.white),
                        label: const Text(
                          'Invite',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: _buttonStyle.copyWith(
                          backgroundColor: MaterialStateProperty.all(Colors.blue),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _leaveRoom,
                      icon: Icon(
                        widget.isCreator ? Icons.cancel : Icons.exit_to_app,
                        color: Colors.white,
                      ),
                      label: Text(
                        widget.isCreator ? 'Close' : 'Leave',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: _buttonStyle.copyWith(
                        backgroundColor: MaterialStateProperty.all(Colors.grey[800]),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
} 