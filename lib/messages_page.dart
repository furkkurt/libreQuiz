import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';

class MessagesPage extends StatefulWidget {
  final String? friendId;
  
  const MessagesPage({Key? key, this.friendId}) : super(key: key);

  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  final TextEditingController _messageController = TextEditingController();
  String? _userId;
  String? _selectedFriendId;
  String? _selectedFriendName;
  String? _selectedFriendPhoto;

  @override
  void initState() {
    super.initState();
    _userId = FirebaseAuth.instance.currentUser?.uid;
    if (widget.friendId != null) {
      _selectedFriendId = widget.friendId;
      _loadFriendInfo();
    }
  }

  Future<void> _loadFriendInfo() async {
    if (_selectedFriendId == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(_selectedFriendId)
        .get();

    if (doc.exists) {
      setState(() {
        _selectedFriendName = doc.data()?['username'];
        _selectedFriendPhoto = doc.data()?['profilePicture'];
      });
    }
  }

  Future<void> _sendMessage(String message, {String? gameRoomId}) async {
    if (_userId == null || _selectedFriendId == null || message.isEmpty) return;

    final chatId = [_userId, _selectedFriendId].toList()..sort();
    final chatDocId = chatId.join('_');

    try {
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatDocId)
          .collection('messages')
          .add({
            'senderId': _userId,
            'message': message,
            'timestamp': FieldValue.serverTimestamp(),
            'gameRoomId': gameRoomId, // null for regular messages
          });

      // Update last message in chat document
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatDocId)
          .set({
            'participants': chatId,
            'lastMessage': message,
            'lastMessageTime': FieldValue.serverTimestamp(),
            'lastSenderId': _userId,
          }, SetOptions(merge: true));

      _messageController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send message: $e')),
      );
    }
  }

  Future<void> _sendGameInvite(String gameRoomId, String roomName) async {
    final message = "🎮 Join my game room: $roomName";
    await _sendMessage(message, gameRoomId: gameRoomId);
  }

  @override
  Widget build(BuildContext context) {
    if (_userId == null) {
      return const Scaffold(
        body: Center(child: Text('Not logged in')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: _selectedFriendId != null
            ? Row(
                children: [
                  CircleAvatar(
                    backgroundImage: _selectedFriendPhoto != null
                        ? CachedNetworkImageProvider(_selectedFriendPhoto!)
                        : null,
                    child: _selectedFriendPhoto == null
                        ? const Icon(Icons.person)
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Text(_selectedFriendName ?? 'Chat'),
                ],
              )
            : const Text('Messages'),
        backgroundColor: Colors.deepOrange,
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
        child: _selectedFriendId != null
            ? _buildChat()
            : _buildChatList(),
      ),
    );
  }

  Widget _buildChat() {
    final chatId = [_userId, _selectedFriendId].toList()..sort();
    final chatDocId = chatId.join('_');

    return Column(
      children: [
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('chats')
                .doc(chatDocId)
                .collection('messages')
                .orderBy('timestamp', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final messages = snapshot.data!.docs;
              return ListView.builder(
                reverse: true,
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final message = messages[index].data() as Map<String, dynamic>;
                  final isMyMessage = message['senderId'] == _userId;
                  return _buildMessageBubble(message, isMyMessage);
                },
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    hintStyle: TextStyle(color: Colors.grey[400]),
                    filled: true,
                    fillColor: Colors.black45,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send, color: Colors.deepOrange),
                onPressed: () {
                  if (_messageController.text.isNotEmpty) {
                    _sendMessage(_messageController.text);
                  }
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChatList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chats')
          .where('participants', arrayContains: _userId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final chats = snapshot.data!.docs;

        if (chats.isEmpty) {
          return const Center(
            child: Text(
              'No messages yet',
              style: TextStyle(color: Colors.white),
            ),
          );
        }

        return ListView.builder(
          itemCount: chats.length,
          itemBuilder: (context, index) {
            final chat = chats[index].data() as Map<String, dynamic>;
            final participants = List<String>.from(chat['participants']);
            final friendId = participants.firstWhere((id) => id != _userId);

            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .doc(friendId)
                  .get(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const ListTile(
                    title: Text('Loading...', style: TextStyle(color: Colors.white)),
                  );
                }

                final friendData = snapshot.data!.data() as Map<String, dynamic>;

                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: friendData['profilePicture'] != null
                        ? CachedNetworkImageProvider(friendData['profilePicture'])
                        : null,
                    child: friendData['profilePicture'] == null
                        ? const Icon(Icons.person)
                        : null,
                  ),
                  title: Text(
                    friendData['username'] ?? 'Unknown',
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    chat['lastMessage'] ?? '',
                    style: TextStyle(color: Colors.grey[400]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () {
                    setState(() {
                      _selectedFriendId = friendId;
                      _selectedFriendName = friendData['username'];
                      _selectedFriendPhoto = friendData['profilePicture'];
                    });
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message, bool isMyMessage) {
    return Align(
      alignment: isMyMessage ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          left: isMyMessage ? 50 : 8,
          right: isMyMessage ? 8 : 50,
          top: 8,
          bottom: 8,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isMyMessage ? Colors.deepOrange.withOpacity(0.8) : Colors.black45,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: isMyMessage ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              message['message'] ?? '',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatTimestamp(message['timestamp']),
              style: TextStyle(
                color: Colors.grey[300],
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final date = timestamp.toDate();
    return '${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
} 