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
        .where('name', isGreaterThanOrEqualTo: query)
        .where('name', isLessThanOrEqualTo: '$query\uf8ff')
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
        toolbarHeight: 80.0, // Set the height of the AppBar
        title: const Text(
          'Start a new discussion',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color.fromARGB(
            255, 64, 93, 105), // Change to your preferred color
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              onChanged: _searchUsers,
              decoration: InputDecoration(
                hintText: 'Search by name...',
                hintStyle:
                    TextStyle(color: Colors.grey[600]), // Hint text color
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30), // Rounded corners
                  borderSide: BorderSide(color: Colors.teal, width: 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide(
                      color: Colors.teal, width: 2), // Focused border
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide(
                      color: Colors.teal, width: 1), // Enabled border
                ),
              ),
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: CircularProgressIndicator(), // Show loading indicator
            ),
          Expanded(
            child: ListView.builder(
              itemCount: _users.length,
              itemBuilder: (context, index) {
                final user = _users[index];
                return Card(
                  margin: const EdgeInsets.symmetric(
                      vertical: 8.0, horizontal: 16.0), // Card margin
                  elevation: 4, // Shadow effect
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15), // Rounded corners
                  ),
                  child: ListTile(
                    title: Text(
                      user['name'],
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onTap: () => _selectUser(user),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
