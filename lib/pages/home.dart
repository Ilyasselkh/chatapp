import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '/pages/Profile.dart';
import '/pages/Users.dart';
import '/pages/login.dart';
import '/pages/chat.dart';
import 'package:intl/intl.dart';

class UserAvatar extends StatelessWidget {
  final String userName;
  final String userId;

  const UserAvatar({super.key, required this.userName, required this.userId});

  @override
  Widget build(BuildContext context) {
    String firstLetter = userName.isNotEmpty ? userName[0].toUpperCase() : '?';

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CircularProgressIndicator();
        }

        if (snapshot.hasError) {
          return Container();
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Container();
        }

        String? profileImage = snapshot.data!['profileImage'];

        return Container(
          width: 40.0,
          height: 40.0,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.purple,
          ),
          alignment: Alignment.center,
          child: profileImage != null && profileImage.isNotEmpty
              ? ClipOval(
                  child: Image.network(
                    profileImage,
                    fit: BoxFit.cover,
                    width: 40.0,
                    height: 40.0,
                  ),
                )
              : Text(
                  firstLetter,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 20.0,
                  ),
                ),
        );
      },
    );
  }
}

class Message {
  final String text;
  final bool isNew;
  final bool delivered;

  Message({required this.text, required this.isNew, required this.delivered});
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _chatHistory = [];
  List<Map<String, dynamic>> _filteredChatHistory = [];
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _fetchChatHistory();
    _startTimer();
    _updateDeliveredStatus();
  }

  void _updateDeliveredStatus() async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId != null) {
      try {
        QuerySnapshot messagesSnapshot = await FirebaseFirestore.instance
            .collection('messages')
            .where('receiverId', isEqualTo: currentUserId)
            .where('delivered', isEqualTo: false)
            .get();

        WriteBatch batch = FirebaseFirestore.instance.batch();
        for (var doc in messagesSnapshot.docs) {
          batch.update(doc.reference, {'delivered': true});
        }
        await batch.commit();
      } catch (e) {
        print("Error updating delivered status: $e");
      }
    }
  }

  void _startTimer() {
    // _timer = Timer.periodic(Duration(seconds: 1), (Timer timer) {
    //   _fetchChatHistory();
    // });
  }

  void _fetchChatHistory() async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId != null) {
      try {
        QuerySnapshot sentMessagesSnapshot = await FirebaseFirestore.instance
            .collection('messages')
            .where('senderId', isEqualTo: currentUserId)
            .get();

        QuerySnapshot receivedMessagesSnapshot = await FirebaseFirestore
            .instance
            .collection('messages')
            .where('receiverId', isEqualTo: currentUserId)
            .get();

        List<Map<String, dynamic>> messages = [];

        for (var doc in sentMessagesSnapshot.docs) {
          messages.add({
            'senderId': doc['senderId'],
            'receiverId': doc['receiverId'],
            'text': doc['text'],
            'timestamp': doc['createdAt'],
            'isRead': doc['isRead'] ?? false,
          });
        }

        for (var doc in receivedMessagesSnapshot.docs) {
          messages.add({
            'senderId': doc['senderId'],
            'receiverId': doc['receiverId'],
            'text': doc['text'],
            'timestamp': doc['createdAt'],
            'isRead': doc['isRead'] ?? false,
          });
        }

        Map<String, Map<String, dynamic>> latestMessages = {};
        for (var message in messages) {
          String otherUserId = message['senderId'] == currentUserId
              ? message['receiverId']
              : message['senderId'];

          DocumentSnapshot userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(otherUserId)
              .get();

          if (userDoc.exists) {
            String userName = userDoc['name'] ?? 'Unknown';

            int newMessagesCount =
                (message['receiverId'] == currentUserId && !message['isRead'])
                    ? 1
                    : 0;

            if (latestMessages.containsKey(otherUserId)) {
              newMessagesCount +=
                  (latestMessages[otherUserId]!['newMessagesCount'] ?? 0)
                      as int;
            }

            if (!latestMessages.containsKey(otherUserId) ||
                (message['timestamp'] as Timestamp)
                        .compareTo(latestMessages[otherUserId]!['timestamp']) >
                    0) {
              latestMessages[otherUserId] = {
                'lastMessage': message['text'],
                'timestamp': message['timestamp'],
                'userId': otherUserId,
                'userName': userName,
                'newMessagesCount': newMessagesCount,
                'isRead': message['isRead'],
              };
            }
          }
        }

        setState(() {
          _chatHistory = latestMessages.entries.map((entry) {
            return {
              'userId': entry.value['userId'],
              'userName': entry.value['userName'],
              'lastMessage': entry.value['lastMessage'],
              'time': entry.value['timestamp'],
              'newMessagesCount': entry.value['newMessagesCount'],
              'isRead': entry.value['isRead'],
            };
          }).toList()
            ..sort((a, b) => (b['time'] as Timestamp).compareTo(a['time']));
          _filteredChatHistory = List.from(_chatHistory);
        });
      } catch (e) {
        print("Error fetching messages: $e");
      }
    }
  }

  String _formatTime(Timestamp timestamp) {
    final date = timestamp.toDate();
    final now = DateTime.now();

    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      return DateFormat.jm().format(date);
    } else if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day - 1) {
      return "Yesterday";
    } else {
      return DateFormat('MMM dd, HH:mm').format(date);
    }
  }

  void _filterChatHistory(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredChatHistory = List.from(_chatHistory);
      } else {
        _filteredChatHistory = _chatHistory.where((chat) {
          return chat['lastMessage']
              .toString()
              .toLowerCase()
              .contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  void _markMessagesAsRead(String userId) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId != null) {
      try {
        QuerySnapshot messagesSnapshot = await FirebaseFirestore.instance
            .collection('messages')
            .where('receiverId', isEqualTo: currentUserId)
            .where('senderId', isEqualTo: userId)
            .where('isRead', isEqualTo: false)
            .get();

        WriteBatch batch = FirebaseFirestore.instance.batch();
        for (var doc in messagesSnapshot.docs) {
          batch.update(doc.reference, {'isRead': true});
        }
        await batch.commit();
      } catch (e) {
        print("Error marking messages as read: $e");
      }
    }
  }

  void _startNewDiscussion() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const UserSelectionPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80.0),
        child: AppBar(
          backgroundColor: const Color.fromARGB(255, 64, 93, 105),
          automaticallyImplyLeading: false,
          title: Padding(
            padding: const EdgeInsets.only(top: 20.0), // Adjust the top padding
            child: _isSearching
                ? Container(
                    width: MediaQuery.of(context).size.width *
                        0.7, // Search bar width
                    decoration: BoxDecoration(
                      color: Colors.white, // Background color
                      borderRadius:
                          BorderRadius.circular(30), // Rounded corners
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 6,
                          offset: Offset(0, 3), // Shadow offset
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: _filterChatHistory,
                      decoration: const InputDecoration(
                        hintText: 'Search...',
                        border: InputBorder.none,
                        prefixIcon: Icon(Icons.search),
                      ),
                    ),
                  )
                : const Text(
                    'ChatApp',
                    style: TextStyle(
                        color: Colors.white), // Set the text style here
                  ),
          ),
          actions: [
            Padding(
              padding:
                  const EdgeInsets.only(top: 20.0), // Adjust the top padding
              child: IconButton(
                icon: Icon(
                  _isSearching ? Icons.close : Icons.search,
                  color: Colors.white,
                ),
                onPressed: () {
                  setState(() {
                    _isSearching = !_isSearching;
                    if (!_isSearching) {
                      _searchController.clear();
                      _filteredChatHistory = List.from(_chatHistory);
                    }
                  });
                },
              ),
            ),
            Padding(
              padding:
                  const EdgeInsets.only(top: 20.0), // Adjust the top padding
              child: IconButton(
                icon: const Icon(Icons.person, color: Colors.white),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const ProfilePage()),
                  );
                },
              ),
            ),
            Padding(
              padding:
                  const EdgeInsets.only(top: 20.0), // Adjust the top padding
              child: IconButton(
                icon: const Icon(Icons.logout, color: Colors.white),
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                  Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (context) => const SignIn()));
                },
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _filteredChatHistory.length,
              itemBuilder: (context, index) {
                final chat = _filteredChatHistory[index];
                return ListTile(
                  leading: UserAvatar(
                    userName: chat['userName'],
                    userId: chat['userId'],
                  ),
                  title: Text(chat['userName']),
                  subtitle: Text(chat['lastMessage']),
                  trailing: chat['newMessagesCount'] > 0
                      ? CircleAvatar(
                          radius: 12,
                          backgroundColor: Colors.red,
                          child: Text(
                            chat['newMessagesCount'].toString(),
                            style: const TextStyle(color: Colors.white),
                          ),
                        )
                      : null,
                  onTap: () {
                    _markMessagesAsRead(chat['userId']);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatPage(
                          userId: chat['userId'],
                          userName: chat['userName'],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton(
              onPressed: _startNewDiscussion,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 58, 90, 115),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: const Text(
                'Start New Discussion',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          children: [
            UserAccountsDrawerHeader(
              accountName: Text(user?.displayName ?? 'User'),
              accountEmail: Text(user?.email ?? ''),
              currentAccountPicture: CircleAvatar(
                child: ClipOval(
                  child: Image.network(
                    user?.photoURL ?? '',
                    fit: BoxFit.cover,
                    width: 40.0,
                    height: 40.0,
                  ),
                ),
              ),
            ),
            ListTile(
              title: const Text('Profile'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ProfilePage()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
