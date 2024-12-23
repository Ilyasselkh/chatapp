import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  User? user;
  DocumentSnapshot? userData;
  File? _image;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchUserData();
  }

  Future<void> fetchUserData() async {
    user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      userData = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .get();
      setState(() {
        _nameController.text = userData!['name'] ?? '';
        _bioController.text = userData!['bio'] ?? '';
        _phoneController.text = userData!['phone'] ?? '';
      });
    }
  }

  Future<void> updateUserData() async {
    if (user != null) {
      String? imageUrl;

      // If an image is selected, upload it to Firebase Storage
      if (_image != null) {
        imageUrl = await uploadImageToFirebase();
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .update({
        'name': _nameController.text,
        'bio': _bioController.text,
        'phone': _phoneController.text,
        'profileImage': imageUrl, // Store the image URL or leave it null
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully!')),
      );
    }
  }

  Widget _buildProfileImage() {
    if (_image != null) {
      return CircleAvatar(
        radius: 60,
        backgroundImage: FileImage(_image!),
      );
    } else if (userData != null && userData!['profileImage'] != null) {
      return CircleAvatar(
        radius: 60,
        backgroundImage: NetworkImage(userData!['profileImage']),
      );
    } else {
      return const CircleAvatar(
        radius: 60,
        child: Text(
          'U', // Default letter
          style: TextStyle(fontSize: 40),
        ),
      );
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
    }
  }

  Future<String?> uploadImageToFirebase() async {
    try {
      // Create a reference to Firebase Storage
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('profile_images/${user!.uid}.jpg');

      // Upload the file
      await storageRef.putFile(_image!);

      // Get the download URL of the uploaded file
      String downloadUrl = await storageRef.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      print('Error uploading image: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Profile"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _nameController.text,
                          style: const TextStyle(
                              fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          user?.email ?? '',
                          style:
                              const TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16), // Spacing between text and image
                  GestureDetector(
                    onTap: _pickImage,
                    child: _buildProfileImage(),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Name',
                  filled: true,
                  fillColor: Colors.grey[200],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon: const Icon(Icons.person, color: Colors.blueGrey),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _bioController,
                decoration: InputDecoration(
                  labelText: 'About',
                  filled: true,
                  fillColor: Colors.grey[200],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon: const Icon(Icons.info, color: Colors.blueGrey),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _phoneController,
                decoration: InputDecoration(
                  labelText: 'Phone',
                  filled: true,
                  fillColor: Colors.grey[200],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon: const Icon(Icons.phone, color: Colors.blueGrey),
                ),
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: updateUserData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueGrey[800],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 15.0),
                ),
                child: const Text(
                  'Save Changes',
                  style: TextStyle(fontSize: 16.0, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
