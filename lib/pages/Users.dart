import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat.dart'; // Adjust the import path as necessary

class UserSelectionPage extends StatefulWidget {
  const UserSelectionPage({super.key});

  @override
  _UserSelectionPageState createState() => _UserSelectionPageState();
}

class _UserSelectionPageState extends State<UserSelectionPage> {
  final TextEditingController _searchController = TextEditingController();
  List<DocumentSnapshot> _users = [];
  bool _isLoading = false;

  void _searchUsers(String query) async {
    if (query.isEmpty) {
      setState(() {
        _users = []; // Clear users when query is empty
      });
      return;
    }

    setState(() {
      _isLoading = true; // Start loading
    });

    // Fetch user profiles from Firestore
    final usersSnapshot = await FirebaseFirestore.instance
        .collection('users') // Your collection for user profiles
        .where('email', isGreaterThanOrEqualTo: query)
        .where('email', isLessThanOrEqualTo: '$query\uf8ff')
        .get();

    setState(() {
      _users = usersSnapshot.docs;
      _isLoading = false; // Stop loading
    });
  }

  void _selectUser(DocumentSnapshot user) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatPage(
          userId: user.id,
          userName:
              user['name'], // Assuming the user document has a 'name' field
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select User'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              onChanged: _searchUsers,
              decoration: InputDecoration(
                hintText: 'Search by email...',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          if (_isLoading) CircularProgressIndicator(), // Show loading indicator
          Expanded(
            child: ListView.builder(
              itemCount: _users.length,
              itemBuilder: (context, index) {
                final user = _users[index];
                return ListTile(
                  title: Text(user['name']),
                  subtitle: Text(user['email']),
                  onTap: () => _selectUser(user),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
