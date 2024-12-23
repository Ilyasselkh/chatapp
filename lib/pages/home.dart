import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
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
    // Get the first letter of the user's name
    String firstLetter = userName.isNotEmpty ? userName[0].toUpperCase() : '?';

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
      builder: (context, snapshot) {
        // Show loading indicator while fetching data
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CircularProgressIndicator(); // Customize loading indicator if needed
        }

        // Handle error case
        if (snapshot.hasError) {
          return Container(); // Handle error case appropriately
        }

        // Handle case where document doesn't exist
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Container(); // Optionally handle case when user document doesn't exist
        }

        // Get the profile image from the document
        String? profileImage = snapshot.data!['profileImage'];

        return Container(
          width: 40.0,
          height: 40.0,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.purple, // Background color when showing initials
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
                  firstLetter, // Show the first letter if no image
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
        // Fetch all messages where the receiver is the current user and delivered is false
        QuerySnapshot messagesSnapshot = await FirebaseFirestore.instance
            .collection('messages')
            .where('receiverId', isEqualTo: currentUserId)
            .where('delivered', isEqualTo: false)
            .get();

        // Update the delivered status of each message using a batch
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
    /*  _timer = Timer.periodic(Duration(seconds: 1), (Timer timer) {
      _fetchChatHistory();
    });  */
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

            // Calculer le nombre de nouveaux messages non lus
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
          _filteredChatHistory =
              List.from(_chatHistory); // Initialiser l'historique filtré
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
        _filteredChatHistory = List.from(_chatHistory); // Reset filter
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

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: 'Search...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Colors.white70),
                ),
                style: const TextStyle(color: Colors.white),
                onChanged: _filterChatHistory,
              )
            : const Text('ChatUp'),
        backgroundColor: const Color.fromARGB(186, 101, 11, 103),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear();
                  _filterChatHistory(''); // Reset the filtered chat history
                }
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _filteredChatHistory.isEmpty
                ? const Center(child: Text("No chats found. Start chatting!"))
                : ListView.builder(
                    itemCount: _filteredChatHistory.length,
                    itemBuilder: (context, index) {
                      final chat = _filteredChatHistory[index];
                      return ListTile(
                        leading: UserAvatar(
                            userName: chat['userName'], userId: chat['userId']),
                        title: Text(
                          chat['userName'],
                          style: TextStyle(
                            color: chat['newMessagesCount'] > 0
                                ? const Color.fromARGB(255, 0, 177, 6)
                                : null,
                            fontWeight: chat['newMessagesCount'] > 0
                                ? FontWeight.bold
                                : FontWeight.bold,
                          ),
                        ),
                        subtitle: Row(
                          children: [
                            Expanded(
                              child: Text(
                                chat['lastMessage'],
                                style: TextStyle(
                                  color: chat['newMessagesCount'] > 0
                                      ? const Color.fromARGB(255, 123, 188, 131)
                                      : null,
                                  fontWeight: chat['newMessagesCount'] > 0
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                            if (chat['newMessagesCount'] > 0)
                              Container(
                                margin: const EdgeInsets.only(left: 8.0),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8.0, vertical: 4.0),
                                decoration: BoxDecoration(
                                  color: const Color.fromARGB(255, 5, 88, 15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${chat['newMessagesCount']}',
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                          ],
                        ),
                        trailing: Text(_formatTime(chat['time'] as Timestamp)),
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
                          ).then((value) {
                            _fetchChatHistory();
                          });
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => UserSelectionPage()),
          ).then((value) {
            _fetchChatHistory();
          });
        },
        backgroundColor: const Color.fromARGB(186, 101, 11, 103),
        child: const Icon(Icons.chat),
      ),
      drawer: Drawer(
        child: Column(
          children: [
            FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user?.uid)
                  .get(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const UserAccountsDrawerHeader(
                    accountName: Text('Loading...'),
                    accountEmail: Text('Loading...'),
                    decoration:
                        BoxDecoration(color: Color.fromARGB(186, 101, 11, 103)),
                    currentAccountPicture: CircleAvatar(
                      backgroundColor: Colors.white,
                      child: CircularProgressIndicator(),
                    ),
                  );
                } else if (snapshot.hasError ||
                    !snapshot.hasData ||
                    !snapshot.data!.exists) {
                  return const UserAccountsDrawerHeader(
                    accountName: Text('Error'),
                    accountEmail: Text('Error'),
                    decoration:
                        BoxDecoration(color: Color.fromARGB(186, 101, 11, 103)),
                    currentAccountPicture: CircleAvatar(
                      backgroundColor: Colors.white,
                      child: Icon(Icons.error,
                          color: Color.fromARGB(186, 101, 11, 103), size: 40.0),
                    ),
                  );
                } else {
                  var userData = snapshot.data!.data() as Map<String, dynamic>;
                  String? profileImageUrl = userData['profileImage'];

                  return UserAccountsDrawerHeader(
                    accountName: Text('Welcome ${userData['name'] ?? 'User'}'),
                    accountEmail: Text(user?.email ?? 'No Email'),
                    decoration: const BoxDecoration(
                        color: Color.fromARGB(186, 101, 11, 103)),
                    currentAccountPicture: CircleAvatar(
                      backgroundColor: Colors.white,
                      backgroundImage:
                          profileImageUrl != null && profileImageUrl.isNotEmpty
                              ? NetworkImage(profileImageUrl)
                              : null, // Si aucune image, affichera une initiale
                      child: profileImageUrl == null || profileImageUrl.isEmpty
                          ? Text(
                              userData['name'] != null &&
                                      userData['name'].isNotEmpty
                                  ? userData['name'][0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                  fontSize: 40.0,
                                  color: Color.fromARGB(186, 101, 11, 103)),
                            )
                          : null, // N'affiche pas d'initiales si une image est présente
                    ),
                  );
                }
              },
            ),
            // Les autres éléments du Drawer...
            ListTile(
              leading: const Icon(Icons.dark_mode),
              title: const Text('Change Theme'),
              onTap: () {
                // Toggle the dark mode state
              },
            ),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Profile'),
              onTap: () {
                // Naviguer vers le profil
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ProfilePage()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () async {
                await _updateDeliveredStatusOnLogout(); // Mettre à jour le champ isActive
                await FirebaseAuth.instance.signOut();
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => SignIn()),
                  (Route<dynamic> route) => false,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  DateTime? _logoutTime;
  Future<void> _sendMessage(String message, String receiverId) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final timestamp = Timestamp.now();

    await FirebaseFirestore.instance.collection('messages').add({
      'text': message,
      'senderId': currentUserId,
      'receiverId': receiverId,
      'createdAt': timestamp,
      'delivered': false, // initialiser à false
      'isNew': true, // le message est nouveau
    });

    // Mettre à jour l'état après l'envoi si nécessaire
    if (currentUserId != null) {
      _updateMessageDeliveryStatus(currentUserId);
    }
  }

  Future<void> _updateMessageDeliveryStatus(String currentUserId) async {
    // Mettre à jour les messages précédents
    QuerySnapshot messagesSnapshot = await FirebaseFirestore.instance
        .collection('messages')
        .where('receiverId', isEqualTo: currentUserId)
        .where('createdAt', isLessThan: Timestamp.now())
        .get();

    for (var doc in messagesSnapshot.docs) {
      // Mettez à jour le statut à delivered = true
      await doc.reference.update({'delivered': true, 'isNew': false});
    }
  }

  Widget _buildMessageItem(Message message) {
    if (message.isNew) {
      return Row(
        children: [
          // Affichage du message
          Text(message.text),
          // Affichage des coches
          const Icon(Icons.check,
              color: Colors.grey), // Une coche grise pour un nouveau message
        ],
      );
    } else {
      if (message.delivered) {
        return Row(
          children: [
            // Affichage du message
            Text(message.text),
            // Affichage des coches
            const Icon(Icons.check, color: Colors.blue), // Coche bleue
            const Icon(Icons.check, color: Colors.blue), // Deuxième coche bleue
          ],
        );
      } else {
        return Row(
          children: [
            // Affichage du message
            Text(message.text),
            // Affichage des coches
            const Icon(Icons.check, color: Colors.grey), // Une coche grise
          ],
        );
      }
    }
  }

  void _markMessagesAsRead(String userId) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId != null) {
      try {
        QuerySnapshot messagesSnapshot = await FirebaseFirestore.instance
            .collection('messages')
            .where('senderId', isEqualTo: userId)
            .where('receiverId', isEqualTo: currentUserId)
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

  Future<void> _updateDeliveredStatusOnLogout() async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId != null) {
      try {
        // Mettre à jour le champ isActive à false dans la collection users
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUserId)
            .update({'isActive': false});

        // Mettez à jour les messages pour les définir comme livrés
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
        print("Error updating delivered status on logout: $e");
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel(); // Cancel the timer when disposing
    super.dispose();
  }
}
