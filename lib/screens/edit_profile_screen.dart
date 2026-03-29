import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../services/avatar_service.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final user = FirebaseAuth.instance.currentUser!;
  final _nicknameController = TextEditingController();
  final _bioController = TextEditingController();
  final _phoneController = TextEditingController();

  String? _photoUrl;
  String? _avatarHex;
  bool _saving = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists && mounted) {
        setState(() {
          _nicknameController.text = doc['nickname'] ?? '';
          _bioController.text = doc['bio'] ?? '';
          _phoneController.text = doc['phoneNumber'] ?? '';
          _photoUrl = doc['photoUrl'];
          _avatarHex = doc['avatarHex'];
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Error loading profile: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    final nickname = _nicknameController.text.trim().toLowerCase();
    final bio = _bioController.text.trim();
    final phone = _phoneController.text.trim();

    if (nickname.isEmpty) {
      Fluttertoast.showToast(msg: "Никнейм не может быть пустым");
      return;
    }

    setState(() => _saving = true);

    try {
      final updates = {
        'nickname': nickname,
        'bio': bio,
      };
      
      if (phone.isNotEmpty) {
        updates['phoneNumber'] = phone;
      }
      
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update(updates);
      
      Fluttertoast.showToast(msg: "Профиль успешно обновлён");
      if (mounted) Navigator.pop(context);
    } catch (e) {
      Fluttertoast.showToast(msg: "Ошибка сохранения профиля: $e");
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    final hexString = await AvatarService.pickAndCropAvatar();
    
    if (hexString != null && mounted) {
      setState(() {
        _avatarHex = hexString;
        _photoUrl = null; // Очищаем старую URL если была
      });
      Fluttertoast.showToast(msg: "Аватар обновлён");
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Редактировать профиль'),
        centerTitle: false,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _saving ? null : _saveProfile,
            child: const Text('Сохранить', style: TextStyle(fontSize: 17, color: Colors.blue)),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Аватар
                  Center(
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        FutureBuilder<File?>(
                          future: _avatarHex != null 
                              ? AvatarService.hexToAvatarFile(_avatarHex!)
                              : Future.value(null),
                          builder: (context, snapshot) {
                            if (_avatarHex != null && snapshot.hasData) {
                              return CircleAvatar(
                                radius: 70,
                                backgroundImage: FileImage(snapshot.data!),
                              );
                            } else if (_photoUrl != null && _photoUrl!.isNotEmpty) {
                              return CircleAvatar(
                                radius: 70,
                                backgroundImage: NetworkImage(_photoUrl!),
                              );
                            } else {
                              return CircleAvatar(
                                radius: 70,
                                child: Icon(Icons.person, size: 70, color: isLight ? Colors.grey : Colors.grey.shade400),
                              );
                            }
                          },
                        ),
                        GestureDetector(
                          onTap: _pickAndUploadAvatar,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isLight ? Colors.white : const Color(0xFF0F0F0F),
                                width: 3,
                              ),
                            ),
                            child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  
                  // Никнейм
                  TextField(
                    controller: _nicknameController,
                    decoration: const InputDecoration(
                      labelText: 'Никнейм',
                      hintText: 'Введите ваш никнейм',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Телефон
                  TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Номер телефона',
                      hintText: '+7 XXX XXX XX XX',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Bio
                  TextField(
                    controller: _bioController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'О себе',
                      hintText: 'Расскажите о себе...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                      prefixIcon: Icon(Icons.description_outlined),
                      alignLabelWithHint: true,
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                  
                  if (_saving)
                    const Center(child: CircularProgressIndicator()),
                ],
              ),
            ),
    );
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _bioController.dispose();
    _phoneController.dispose();
    super.dispose();
  }
}