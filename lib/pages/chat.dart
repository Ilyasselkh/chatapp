import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class Message {
  final String text;
  final String senderId;
  final String receiverId;
  final bool isRead;
  final bool delivered;
  final Timestamp timestamp;

  Message({
    required this.text,
    required this.senderId,
    required this.receiverId,
    required this.isRead,
    required this.delivered,
    required this.timestamp,
  });

  factory Message.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Message(
      text: data['text'] ?? '',
      senderId: data['senderId'] ?? '',
      receiverId: data['receiverId'] ?? '',
      isRead: data['isRead'] ?? false,
      delivered: data['delivered'] ?? false,
      timestamp: data['timestamp'] ?? Timestamp.now(),
    );
  }
}

class ChatPage extends StatefulWidget {
  final String userId; // ID of the user you're chatting with
  final String userName; // Name of the user you're chatting with

  const ChatPage({super.key, required this.userId, required this.userName});

  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  String? profileImage;
  final TextEditingController _controller = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String currentUserId = FirebaseAuth.instance.currentUser!.uid;

  // Mark messages as read
  void _markMessagesAsReadOnInit(String chatUserId) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId != null) {
      QuerySnapshot unreadMessages = await FirebaseFirestore.instance
          .collection('messages')
          .where('senderId', isEqualTo: chatUserId)
          .where('receiverId', isEqualTo: currentUserId)
          .where('isRead', isEqualTo: false)
          .get();

      WriteBatch batch = FirebaseFirestore.instance.batch();
      for (var doc in unreadMessages.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    }
  }

  @override
  void initState() {
    super.initState();
    _markMessagesAsReadOnInit(widget.userId);
    _setUserActive(true);
    _setIsSeen(true);

    _fetchUserProfileImage(widget.userId); // Fetch the user's profile image
  }

  void _fetchUserProfileImage(String userId) async {
    DocumentSnapshot userDoc =
        await _firestore.collection('users').doc(userId).get();
    if (userDoc.exists) {
      setState(() {
        profileImage =
            (userDoc.data() as Map<String, dynamic>)['profileImage'] ?? '';
      });
    }
  }

  @override
  void dispose() {
    _setIsSeen(false); // Marquez l'utilisateur comme inactif
    super.dispose();
  }

  void _setUserActive(bool isActive) async {
    await _firestore.collection('users').doc(currentUserId).update({
      'isActive': isActive,
    });
  }

  void _setIsSeen(bool isSeen) async {
    await _firestore.collection('users').doc(currentUserId).update({
      'isSeen': isSeen,
    });
  }

  void _sendMessage() async {
    if (_controller.text.isNotEmpty) {
      // Récupérer le statut isSeen et isActive du destinataire avant d'envoyer le message
      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(widget.userId).get();
      bool isSeen = userDoc.exists &&
          (userDoc.data() as Map<String, dynamic>)['isSeen'] == true;
      bool isActive = userDoc.exists &&
          (userDoc.data() as Map<String, dynamic>)['isActive'] == true;

      // Préparer les données du message
      Map<String, dynamic> messageData = {
        'text': _controller.text,
        'createdAt': FieldValue.serverTimestamp(),
        'senderId': currentUserId,
        'receiverId': widget.userId,
        'isRead': false, // Par défaut : le message est marqué comme non lu
        'delivered': false, // Par défaut : non livré initialement
        'timestamp': FieldValue.serverTimestamp(),
      };

      // Ajouter le message à Firestore
      DocumentReference messageRef =
          await _firestore.collection('messages').add(messageData);

      // Marquer le statut de l'utilisateur comme inactif
      await _firestore.collection('users').doc(currentUserId).update({
        'isActive': false, // Définir l'utilisateur comme inactif
      });

      // Mettre à jour le statut du message en fonction de isSeen
      if (isSeen) {
        // Si le destinataire a vu les messages, marquez le message comme lu
        await messageRef.update({
          'isRead': true, // Deux coches bleues
          'delivered': true, // Marquer comme livré
        });
      } else if (!isSeen && !isActive) {
        // Si le destinataire n'a pas vu les messages et n'est pas actif
        await messageRef.update({
          'isRead': false, // Reste non lu (une coche grise)
          'delivered': false, // Message est livré
        });
      } else if (!isSeen && isActive) {
        // Si le destinataire n'a pas vu les messages mais est actif
        await messageRef.update({
          'isRead': false, // Reste non lu (une coche grise)
          'delivered': true, // Message est livré
        });
      }

      // Effacer le contrôleur de texte
      _controller.clear();
    }
  }

  // Delete a message
  void _deleteMessage(String messageId) async {
    await _firestore.collection('messages').doc(messageId).delete();
  }

  // Show a confirmation dialog for deletion
  void _showDeleteConfirmation(String messageId, bool isSender) {
    if (isSender) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Delete Message'),
          content: const Text('Are you sure you want to delete this message?'),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(ctx).pop();
              },
            ),
            TextButton(
              child: const Text('Delete'),
              onPressed: () {
                _deleteMessage(messageId);
                Navigator.of(ctx).pop();
              },
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.grey[300],
              backgroundImage: profileImage != null && profileImage!.isNotEmpty
                  ? NetworkImage(profileImage!)
                  : null, // If no image, show initials
              child: profileImage == null || profileImage!.isEmpty
                  ? Text(
                      widget.userName[0].toUpperCase(),
                      style: const TextStyle(color: Colors.black),
                    )
                  : null, // Don't show initials if there's an image
            ),
            const SizedBox(width: 8),
            Text(widget.userName),
            const Spacer(),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('messages')
                  .where('senderId', whereIn: [currentUserId, widget.userId])
                  .where('receiverId', whereIn: [currentUserId, widget.userId])
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                      child: Text('Error: ${snapshot.error.toString()}'));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No messages yet.'));
                }

                final messages = snapshot.data!.docs;
                Stream<List<Message>> getMessagesStream() {
                  return FirebaseFirestore.instance
                      .collection(
                          'messages') // Remplacez par le nom de votre collection
                      .orderBy('timestamp', descending: true) // Trie par date
                      .snapshots()
                      .map((snapshot) {
                    return snapshot.docs.map((doc) {
                      return Message.fromFirestore(doc);
                    }).toList();
                  });
                }

                StreamBuilder<List<Message>>(
                  stream: getMessagesStream(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(child: CircularProgressIndicator());
                    }
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return Center(
                          child: Text('Aucun message pour le moment.'));
                    }
                    final messages = snapshot.data!;
                    return ListView.builder(
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final message = messages[index];
                        return ListTile(
                          title: Text(message.text),
                          subtitle: Text(message.senderId),
                        );
                      },
                    );
                  },
                );

                return ListView.builder(
                  reverse: true,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isSender = message['senderId'] == currentUserId;

                    return GestureDetector(
                      onLongPress: () {
                        _showDeleteConfirmation(message.id, isSender);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 8, horizontal: 16),
                        child: Row(
                          mainAxisAlignment: isSender
                              ? MainAxisAlignment.end
                              : MainAxisAlignment.start,
                          children: [
                            if (!isSender) const SizedBox(width: 8),
                            Flexible(
                              child: ConstrainedBox(
                                constraints:
                                    const BoxConstraints(maxWidth: 250),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 10, horizontal: 14),
                                  decoration: BoxDecoration(
                                    color: isSender
                                        ? Color.fromARGB(186, 101, 11, 103)
                                        : const Color.fromARGB(
                                            255, 216, 216, 216),
                                    borderRadius: BorderRadius.only(
                                      topLeft: const Radius.circular(15),
                                      topRight: const Radius.circular(15),
                                      bottomLeft: isSender
                                          ? const Radius.circular(15)
                                          : const Radius.circular(0),
                                      bottomRight: isSender
                                          ? const Radius.circular(0)
                                          : const Radius.circular(15),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        message['text'],
                                        style: TextStyle(
                                          color: isSender
                                              ? Colors.white
                                              : Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      if (isSender) // Show checkmarks only for sent messages
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.end,
                                          children: [
                                            if (!message['delivered'])
                                              Icon(
                                                Icons.check,
                                                size: 16,
                                                color: Colors.grey,
                                              ),
                                            if (message['delivered'] &&
                                                !message['isRead'])
                                              Row(
                                                children: [
                                                  Icon(
                                                    Icons.check,
                                                    size: 16,
                                                    color: Colors.grey,
                                                  ),
                                                  Icon(
                                                    Icons.check,
                                                    size: 16,
                                                    color: Colors.grey,
                                                  ),
                                                ],
                                              ),
                                            if (message['isRead'])
                                              Row(
                                                children: [
                                                  Icon(
                                                    Icons.check,
                                                    size: 16,
                                                    color: Colors.blue,
                                                  ),
                                                  Icon(
                                                    Icons.check,
                                                    size: 16,
                                                    color: Colors.blue,
                                                  ),
                                                ],
                                              ),
                                          ],
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            if (isSender) const SizedBox(width: 8),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      filled: true,
                      fillColor:
                          isDarkMode ? Colors.grey[800] : Colors.grey[200],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 16),
                    ),
                    style: TextStyle(
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
