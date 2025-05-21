import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

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
  late StreamSubscription _roomSubscription;
  Map<String, dynamic>? _roomData;
  bool _isLoading = true;
  String? _errorMessage;
  String? _userId;
  
  @override
  void initState() {
    super.initState();
    _userId = FirebaseAuth.instance.currentUser?.uid ?? 'dev_user_1234';
    _subscribeToRoom();
  }
  
  @override
  void dispose() {
    _roomSubscription.cancel();
    super.dispose();
  }
  
  void _subscribeToRoom() {
    _roomSubscription = FirebaseFirestore.instance
        .collection('gameRooms')
        .doc(widget.roomId)
        .snapshots()
        .listen((snapshot) {
          setState(() {
            if (snapshot.exists) {
              _roomData = snapshot.data();
              _isLoading = false;
            } else {
              _errorMessage = 'Room no longer exists';
              _isLoading = false;
            }
          });
        }, onError: (error) {
          setState(() {
            _errorMessage = 'Error loading room: $error';
            _isLoading = false;
          });
        });
  }
  
  Future<void> _startGame() async {
    if (!widget.isCreator) return;
    
    try {
      await FirebaseFirestore.instance
          .collection('gameRooms')
          .doc(widget.roomId)
          .update({
            'hasStarted': true,
          });
      
      // Navigate to the game play screen
      // This would be implemented in future steps
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Game started!')),
      );
      
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to start game: $e')),
      );
    }
  }
  
  Future<void> _leaveRoom() async {
    if (widget.isCreator) {
      // Creator is closing the room
      try {
        await FirebaseFirestore.instance
            .collection('gameRooms')
            .doc(widget.roomId)
            .update({
              'isActive': false,
            });
        
        if (!mounted) return;
        Navigator.pop(context);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to close room: $e')),
        );
      }
    } else {
      // Player is leaving the room
      try {
        // Get current list of players
        List<dynamic> players = List.from(_roomData?['players'] ?? []);
        
        // Find and remove the current player
        players.removeWhere((player) => player['playerId'] == _userId);
        
        // Update the room
        await FirebaseFirestore.instance
            .collection('gameRooms')
            .doc(widget.roomId)
            .update({
              'players': players,
            });
        
        if (!mounted) return;
        Navigator.pop(context);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to leave room: $e')),
        );
      }
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
                        return ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Colors.grey,
                            child: Icon(Icons.person, color: Colors.white),
                          ),
                          title: Text(
                            playerName,
                            style: const TextStyle(color: Colors.white),
                          ),
                          subtitle: const Text(
                            'Player',
                            style: TextStyle(color: Colors.grey),
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
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Leave/Close button
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _leaveRoom,
                      icon: Icon(widget.isCreator ? Icons.cancel : Icons.exit_to_app, color: Colors.white),
                      label: Text(widget.isCreator ? 'Close Room' : 'Leave Room', style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[800],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  
                  const SizedBox(width: 16),
                  
                  // Start button (only for creator)
                  if (widget.isCreator)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: hasStarted ? null : _startGame,
                        icon: const Icon(Icons.play_arrow, color: Colors.white),
                        label: const Text('Start Game', style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepOrange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
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