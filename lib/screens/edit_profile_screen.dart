import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final user = FirebaseAuth.instance.currentUser!;
  final _nicknameController = TextEditingController();
  final _bioController = TextEditingController();

  String? _photoUrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    if (doc.exists && mounted) {
      setState(() {
        _nicknameController.text = doc['nickname'] ?? '';
        _bioController.text = doc['bio'] ?? '';
        _photoUrl = doc['photoUrl'];
      });
    }
  }

  Future<void> _saveProfile() async {
    final nickname = _nicknameController.text.trim().toLowerCase();
    final bio = _bioController.text.trim();

    if (nickname.isEmpty) {
      Fluttertoast.showToast(msg: "Никнейм не может быть пустым");
      return;
    }

    setState(() => _saving = true);

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'nickname': nickname,
        'bio': bio,
      });
      Fluttertoast.showToast(msg: "Профиль успешно обновлён");
      if (mounted) Navigator.pop(context); // возвращаемся назад
    } catch (e) {
      Fluttertoast.showToast(msg: "Ошибка сохранения профиля");
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1000,
      imageQuality: 85,
    );

    if (pickedFile == null) return;

    setState(() => _saving = true);

    try {
      final ref = FirebaseStorage.instance.ref().child('avatars/${user.uid}.jpg');
      await ref.putFile(File(pickedFile.path));
      final url = await ref.getDownloadURL();

      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({'photoUrl': url});

      if (mounted) setState(() => _photoUrl = url);
      Fluttertoast.showToast(msg: "Фото обновлено");
    } catch (e) {
      Fluttertoast.showToast(msg: "Ошибка загрузки фото");
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _saveProfile,
            child: const Text('Done', style: TextStyle(fontSize: 17, color: Colors.blue)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Center(
              child: GestureDetector(
                onTap: _pickAndUploadAvatar,
                child: CircleAvatar(
                  radius: 80,
                  backgroundImage: _photoUrl != null ? NetworkImage(_photoUrl!) : null,
                  child: _photoUrl == null ? const Icon(Icons.person, size: 80, color: Colors.grey) : null,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text('Set New Photo or Video', style: TextStyle(color: Colors.blue, fontSize: 16)),

            const SizedBox(height: 40),

            TextField(
              controller: _nicknameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
              ),
            ),
            const SizedBox(height: 24),

            TextField(
              controller: _bioController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Bio',
                border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                hintText: 'Any details such as age, occupation or city...',
              ),
            ),

            const SizedBox(height: 40),

            ListTile(
              title: const Text('Change Number'),
              trailing: Text('+65 8379 4988', style: TextStyle(color: Colors.grey[400])),
              onTap: () {},
            ),
            const Divider(),

            ListTile(
              title: const Text('Username'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {},
            ),
            const Divider(),

            const SizedBox(height: 40),

            ListTile(
              title: const Text('Add Another Account', style: TextStyle(color: Colors.blue)),
              onTap: () {},
            ),

            const SizedBox(height: 40),

            ListTile(
              title: const Text('Log Out', style: TextStyle(color: Colors.red)),
              onTap: () async {
                await FirebaseAuth.instance.signOut();
                if (mounted) Navigator.popUntil(context, (route) => route.isFirst);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _bioController.dispose();
    super.dispose();
  }
}