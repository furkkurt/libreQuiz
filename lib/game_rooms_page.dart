import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'create_game_room_page.dart';
import 'game_room_detail_page.dart';

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
    _userId = FirebaseAuth.instance.currentUser?.uid ?? 'dev_user_1234';
    _loadGameRooms();
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
    
    // Listen to active game rooms
    _roomsSubscription = FirebaseFirestore.instance
        .collection('gameRooms')
        .where('isActive', isEqualTo: true)
        .where('hasStarted', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snapshot) {
          setState(() {
            _gameRooms = snapshot.docs;
            _isLoading = false;
          });
        }, onError: (error) {
          print('Error loading game rooms: $error');
          setState(() {
            _isLoading = false;
          });
        });
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
              'joinedAt': FieldValue.serverTimestamp(),
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
        child: Column(
          children: [
            // Search bar
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search rooms...',
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              ),
            ),
            
            // Room list
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredRooms.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.meeting_room_outlined,
                                  size: 64,
                                  color: Colors.white70,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _searchQuery.isEmpty
                                      ? 'No game rooms available.\nCreate one to get started!'
                                      : 'No rooms found matching "$_searchQuery"',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 8.0,
                          ),
                          itemCount: _filteredRooms.length,
                          itemBuilder: (context, index) {
                            final roomSnapshot = _filteredRooms[index];
                            final roomData = roomSnapshot.data() as Map<String, dynamic>;
                            final roomName = roomData['roomName'] as String? ?? 'Unnamed Room';
                            final creatorName = roomData['creatorName'] as String? ?? 'Unknown';
                            final quizTitle = roomData['quizTitle'] as String? ?? 'Unknown Quiz';
                            final players = List<Map<String, dynamic>>.from(roomData['players'] ?? []);
                            final playerCount = players.length + 1; // +1 for creator
                            
                            return Card(
                              color: Colors.black87,
                              elevation: 2,
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16.0, 
                                  vertical: 8.0,
                                ),
                                title: Text(
                                  roomName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Text(
                                      'Quiz: $quizTitle',
                                      style: TextStyle(
                                        color: Colors.deepOrange[100],
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Host: $creatorName',
                                      style: const TextStyle(
                                        color: Colors.grey,
                                      ),
                                    ),
                                    Text(
                                      'Players: $playerCount',
                                      style: const TextStyle(
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: ElevatedButton(
                                  onPressed: () => _joinRoom(roomSnapshot),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.deepOrange,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                  ),
                                  child: Text(
                                    roomData['creatorId'] == _userId ? 'Manage' : 'Join',
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const CreateGameRoomPage(),
            ),
          );
        },
        backgroundColor: Colors.deepOrange,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Create Room', style: TextStyle(color: Colors.white)),
      ),
    );
  }
} 