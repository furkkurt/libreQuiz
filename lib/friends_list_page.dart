import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'messages_page.dart';

class FriendsListPage extends StatefulWidget {
  const FriendsListPage({Key? key}) : super(key: key);

  @override
  State<FriendsListPage> createState() => _FriendsListPageState();
}

class _FriendsListPageState extends State<FriendsListPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _userId;
  List<String> _friendRequests = [];
  List<String> _friends = [];

  @override
  void initState() {
    super.initState();
    _userId = FirebaseAuth.instance.currentUser?.uid;
    _loadFriendData();
  }

  Future<void> _loadFriendData() async {
    if (_userId == null) return;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(_userId)
        .get();

    if (userDoc.exists) {
      setState(() {
        _friends = List<String>.from(userDoc.data()?['friends'] ?? []);
        _friendRequests = List<String>.from(userDoc.data()?['friendRequests'] ?? []);
      });
    }
  }

  Future<void> _sendFriendRequest(String targetUserId) async {
    if (_userId == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(targetUserId)
          .update({
        'friendRequests': FieldValue.arrayUnion([_userId])
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Friend request sent!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send friend request: $e')),
      );
    }
  }

  Future<void> _acceptFriendRequest(String senderId) async {
    if (_userId == null) return;

    try {
      // Add to both users' friends lists
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_userId)
          .update({
        'friends': FieldValue.arrayUnion([senderId]),
        'friendRequests': FieldValue.arrayRemove([senderId])
      });

      await FirebaseFirestore.instance
          .collection('users')
          .doc(senderId)
          .update({
        'friends': FieldValue.arrayUnion([_userId])
      });

      setState(() {
        _friends.add(senderId);
        _friendRequests.remove(senderId);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Friend request accepted!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to accept friend request: $e')),
      );
    }
  }

  Future<void> _declineFriendRequest(String senderId) async {
    if (_userId == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_userId)
          .update({
        'friendRequests': FieldValue.arrayRemove([senderId])
      });

      setState(() {
        _friendRequests.remove(senderId);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Friend request declined')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to decline friend request: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Friends'),
          backgroundColor: Colors.deepOrange,
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Friends'),
              Tab(text: 'Requests'),
              Tab(text: 'Find'),
            ],
          ),
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
          child: TabBarView(
            children: [
              _buildFriendsList(),
              _buildFriendRequests(),
              _buildFindFriends(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFriendsList() {
    if (_friends.isEmpty) {
      return const Center(
        child: Text(
          'No friends yet',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where(FieldPath.documentId, whereIn: _friends)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error: ${snapshot.error}',
              style: const TextStyle(color: Colors.white),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final friends = snapshot.data!.docs;
        return ListView.builder(
          itemCount: friends.length,
          itemBuilder: (context, index) {
            final friend = friends[index].data() as Map<String, dynamic>;
            return Container(
              margin: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: Colors.black45,
                borderRadius: BorderRadius.circular(15),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundImage: friend['profilePicture'] != null
                      ? CachedNetworkImageProvider(friend['profilePicture'])
                      : null,
                  child: friend['profilePicture'] == null
                      ? const Icon(Icons.person)
                      : null,
                ),
                title: Text(
                  friend['username'] ?? 'Unknown',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.message, color: Colors.green),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MessagesPage(
                          friendId: friends[index].id,
                        ),
                      ),
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFriendRequests() {
    if (_friendRequests.isEmpty) {
      return const Center(
        child: Text(
          'No friend requests',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where(FieldPath.documentId, whereIn: _friendRequests)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final requests = snapshot.data!.docs;

        return ListView.builder(
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final request = requests[index].data() as Map<String, dynamic>;
            return ListTile(
              leading: CircleAvatar(
                backgroundImage: request['profilePicture'] != null
                    ? CachedNetworkImageProvider(request['profilePicture'])
                    : null,
                child: request['profilePicture'] == null
                    ? const Icon(Icons.person)
                    : null,
              ),
              title: Text(
                request['username'] ?? 'Unknown',
                style: const TextStyle(color: Colors.white),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.check, color: Colors.green),
                    onPressed: () => _acceptFriendRequest(requests[index].id),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.red),
                    onPressed: () => _declineFriendRequest(requests[index].id),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFindFriends() {
    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search users...',
              hintStyle: TextStyle(color: Colors.grey[400]),
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              filled: true,
              fillColor: Colors.black45,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 16,
              ),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value.toLowerCase();
              });
            },
          ),
        ),
        
        // Users list
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .orderBy('username')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Error: ${snapshot.error}',
                    style: const TextStyle(color: Colors.white),
                  ),
                );
              }

              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final users = snapshot.data!.docs.where((doc) {
                // Filter out current user and existing friends
                if (doc.id == _userId || _friends.contains(doc.id)) {
                  return false;
                }
                
                // Apply search filter
                final userData = doc.data() as Map<String, dynamic>;
                final username = (userData['username'] ?? '').toString().toLowerCase();
                return username.contains(_searchQuery);
              }).toList();

              if (users.isEmpty) {
                return Center(
                  child: Text(
                    _searchQuery.isEmpty
                        ? 'No users found'
                        : 'No users found for "$_searchQuery"',
                    style: const TextStyle(color: Colors.white),
                  ),
                );
              }

              return ListView.builder(
                itemCount: users.length,
                itemBuilder: (context, index) {
                  final userData = users[index].data() as Map<String, dynamic>;
                  final userId = users[index].id;
                  final username = userData['username'] ?? 'Unknown';
                  final profilePicture = userData['profilePicture'];
                  final isRequestSent = _friendRequests.contains(userId);

                  return Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundImage: profilePicture != null
                            ? CachedNetworkImageProvider(profilePicture)
                            : null,
                        child: profilePicture == null
                            ? const Icon(Icons.person)
                            : null,
                      ),
                      title: Text(
                        username,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      trailing: ElevatedButton(
                        onPressed: isRequestSent
                            ? null
                            : () => _sendFriendRequest(userId),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepOrange,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: Text(
                          isRequestSent ? 'Request Sent' : 'Add Friend',
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildUserListTile(String username, String? profilePicture, String userId, {required bool isFriend}) {
    return ListTile(
      leading: CircleAvatar(
        backgroundImage: profilePicture != null
            ? CachedNetworkImageProvider(profilePicture)
            : null,
        child: profilePicture == null
            ? const Icon(Icons.person)
            : null,
      ),
      title: Text(
        username,
        style: const TextStyle(color: Colors.white),
      ),
      trailing: isFriend
          ? IconButton(
              icon: const Icon(Icons.message, color: Colors.green),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MessagesPage(friendId: userId),
                  ),
                );
              },
            )
          : IconButton(
              icon: const Icon(Icons.person_add, color: Colors.blue),
              onPressed: () => _sendFriendRequest(userId),
            ),
    );
  }
} 