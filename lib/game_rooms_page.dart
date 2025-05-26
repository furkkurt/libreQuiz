import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'create_game_room_page.dart';
import 'game_room_detail_page.dart';
import 'web_layout_helper.dart';

class GameRoomsPage extends StatefulWidget {
  const GameRoomsPage({Key? key}) : super(key: key);

  @override
  State<GameRoomsPage> createState() => _GameRoomsPageState();
}

class _GameRoomsPageState extends State<GameRoomsPage> {
  String? _userId;
  bool _isLoading = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  StreamSubscription? _roomsSubscription;
  List<DocumentSnapshot> _gameRooms = [];
  
  @override
  void initState() {
    super.initState();
    _userId = FirebaseAuth.instance.currentUser?.uid;
  }
  
  @override
  void dispose() {
    _roomsSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }
  
  void _loadGameRooms() {
    setState(() {
      _isLoading = true;
    });
    
    // Temporarily remove the where clause to see all rooms
    _roomsSubscription = FirebaseFirestore.instance
        .collection('gameRooms')
        // .where('isActive', isEqualTo: true)  // Comment this out temporarily
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snapshot) {
          print("DEBUG: Found ${snapshot.docs.length} game rooms");
          setState(() {
            _gameRooms = snapshot.docs;
            _isLoading = false;
          });
          _printRoomDetails();
        }, onError: (error) {
          print('Error loading game rooms: $error');
          setState(() {
            _isLoading = false;
          });
        });
  }
  
  void _printRoomDetails() {
    print("DEBUG: Current game rooms:");
    for (var room in _gameRooms) {
      final data = room.data() as Map<String, dynamic>;
      print("Room ID: ${room.id}");
      print("Room Name: ${data['roomName']}");
      print("Is Active: ${data['isActive']} (Type: ${data['isActive'].runtimeType})");
      print("Has Started: ${data['hasStarted']} (Type: ${data['hasStarted'].runtimeType})");
      print("Created At: ${data['createdAt']} (Type: ${data['createdAt'].runtimeType})");
      print("All fields: ${data.keys.toList()}");
      print("---");
    }
  }
  
  List<DocumentSnapshot> get _filteredRooms {
    if (_searchQuery.isEmpty) {
      return _gameRooms;
    }
    
    return _gameRooms.where((room) {
      final data = room.data() as Map<String, dynamic>;
      final roomName = (data['roomName'] as String? ?? '').toLowerCase();
      final creatorName = (data['creatorName'] as String? ?? '').toLowerCase();
      final quizTitle = (data['quizTitle'] as String? ?? '').toLowerCase();
      
      final query = _searchQuery.toLowerCase();
      return roomName.contains(query) || 
             creatorName.contains(query) ||
             quizTitle.contains(query);
    }).toList();
  }
  
  void _joinRoom(DocumentSnapshot roomSnapshot) async {
    final data = roomSnapshot.data() as Map<String, dynamic>;
    final roomId = roomSnapshot.id;
    final roomName = data['roomName'] as String? ?? 'Unnamed Room';
    
    // Check if the user is already in the room or is the creator
    final creatorId = data['creatorId'] as String? ?? '';
    final players = List<Map<String, dynamic>>.from(data['players'] ?? []);
    
    if (creatorId == _userId) {
      // User is the creator, navigate to room
      _navigateToRoom(roomId, roomName, true);
      return;
    }
    
    final isAlreadyInRoom = players.any((player) => player['playerId'] == _userId);
    if (isAlreadyInRoom) {
      // User is already in the room, navigate to room
      _navigateToRoom(roomId, roomName, false);
      return;
    }
    
    // Get current user info
    String playerName = 'Guest';
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_userId)
          .get();
      if (userDoc.exists) {
        playerName = userDoc.data()?['username'] ?? 'Guest';
      }
    } catch (e) {
      print('Error getting user info: $e');
    }
    
    // Add user to the room
    try {
      await FirebaseFirestore.instance
          .collection('gameRooms')
          .doc(roomId)
          .update({
            'players': FieldValue.arrayUnion([{
              'playerId': _userId,
              'playerName': playerName,
              'joinedAt': DateTime.now().toIso8601String(),
            }])
          });
      
      // Navigate to room
      _navigateToRoom(roomId, roomName, false);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error joining room: $e')),
      );
    }
  }
  
  void _navigateToRoom(String roomId, String roomName, bool isCreator) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GameRoomDetailPage(
          roomId: roomId,
          roomName: roomName,
          isCreator: isCreator,
        ),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Game Rooms'),
        backgroundColor: Colors.deepOrange,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: TextButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CreateGameRoomPage(),
                ),
              ),
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text(
                'Create',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
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
              Colors.black.withOpacity(0.7),
              BlendMode.srcOver,
            ),
          ),
        ),
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('gameRooms')
              .where('isActive', isEqualTo: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }

            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final rooms = snapshot.data!.docs;

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: rooms.length,
              itemBuilder: (context, index) {
                final room = rooms[index].data() as Map<String, dynamic>;
                return Card(
                  color: Colors.black87,
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    title: Text(
                      room['roomName'] ?? 'Unnamed Room',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Quiz: ${room['quizTitle'] ?? 'Unknown Quiz'}',
                          style: const TextStyle(color: Colors.orange),
                        ),
                        Text(
                          'Host: ${room['creatorName'] ?? 'Unknown'}',
                          style: const TextStyle(color: Colors.grey),
                        ),
                        Text(
                          'Players: ${(room['players'] as List?)?.length ?? 0}',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                    trailing: ElevatedButton(
                      onPressed: () => _joinRoom(rooms[index]),
                      child: const Text(
                        'Join',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepOrange,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
} 