import 'dart:io';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get_it/get_it.dart';
import 'package:image_picker/image_picker.dart';

import '../../../shared/services/firestore_service.dart';
import '../../../shared/services/file_converter_service.dart';
import '../../../core/logger/app_logger.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _user = FirebaseAuth.instance.currentUser!;
  final _firestoreService = GetIt.I<FirestoreService>();
  final _logger = GetIt.I<AppLogger>();

  final _nicknameController = TextEditingController();
  final _bioController = TextEditingController();
  final _phoneController = TextEditingController();
  final _usernameController = TextEditingController();
  final _songTitleController = TextEditingController();
  final _songArtistController = TextEditingController();

  String? _avatarHex;
  bool _saving = false;
  bool _isLoading = true;
  String? _usernameError;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _checkUsername() async {
    final username = _usernameController.text.trim();
    if (username.isEmpty) {
      setState(() => _usernameError = null);
      return;
    }
    if (!RegExp(r'^[a-zA-Z0-9_]{3,20}$').hasMatch(username)) {
      setState(() => _usernameError = 'Только латиница, цифры и _, 3-20 символов');
      return;
    }
    final available = await _firestoreService.isUsernameAvailable(username);
    setState(() => _usernameError = available ? null : 'Имя уже занято');
  }

    Future<void> _loadProfile() async {
    try {
      final doc = await _firestoreService.getUser(_user.uid);
      if (doc.exists && mounted) {
        final data = doc.data() as Map<String, dynamic>;
        final pinnedSong = data['pinnedSong'] as Map<String, dynamic>? ?? {};

        setState(() {
          _nicknameController.text = data['nickname'] ?? '';
          _usernameController.text = data['username'] ?? '';
          _bioController.text = data['bio'] ?? '';
          _phoneController.text = data['phoneNumber'] ?? '';
          _avatarHex = data['avatarHex'];

          _songTitleController.text = pinnedSong['title'] ?? '';
          _songArtistController.text = pinnedSong['artist'] ?? '';

          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      _logger.error('Error loading profile', error: e);
      setState(() => _isLoading = false);
    }
  }

    Future<void> _saveProfile() async {
    final nickname = _nicknameController.text.trim();
    if (nickname.isEmpty) {
      Fluttertoast.showToast(msg: "Никнейм не может быть пустым");
      return;
    }

    if (_usernameError != null) {
      Fluttertoast.showToast(msg: "Исправьте ошибку в имени пользователя");
      return;
    }

    setState(() => _saving = true);
    try {
      final updates = {
        'nickname': nickname,
        'bio': _bioController.text.trim(),
        'username': _usernameController.text.trim(),
        'pinnedSong': {
          'title': _songTitleController.text.trim(),
          'artist': _songArtistController.text.trim(),
          // duration и audioUrl можно добавить позже через отдельный сервис
        },
      };
      if (_phoneController.text.isNotEmpty) {
        updates['phoneNumber'] = _phoneController.text.trim();
      }

      await _firestoreService.updateUser(_user.uid, updates);
      Fluttertoast.showToast(msg: "Профиль обновлён");
      if (mounted) Navigator.pop(context);
    } catch (e) {
      Fluttertoast.showToast(msg: "Ошибка сохранения профиля");
    } finally {
      setState(() => _saving = false);
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 800, imageQuality: 85);
    if (picked == null) return;

    setState(() => _saving = true);
    try {
      final file = File(picked.path);
      final hex = await FileConverterService.fileToHex(file);
      final bytes = await file.readAsBytes();
      final base64 = base64Encode(bytes);
      final photoUrl = 'data:image/jpeg;base64,$base64';

      await _firestoreService.updateUser(_user.uid, {
        'avatarHex': hex,
        'photoUrl': photoUrl,
      });
      setState(() => _avatarHex = hex);
      Fluttertoast.showToast(msg: "Фото обновлено");
    } catch (e) {
      Fluttertoast.showToast(msg: "Ошибка загрузки фото");
    } finally {
      setState(() => _saving = false);
    }
  }

  Widget _buildAvatar() {
    if (_avatarHex != null && _avatarHex!.isNotEmpty) {
      return FutureBuilder<File?>(
        future: FileConverterService.hexToFile(_avatarHex!, 'avatar_${_user.uid}.jpg'),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return CircleAvatar(
              radius: 70,
              backgroundImage: FileImage(snapshot.data!),
            );
          }
          return const CircleAvatar(radius: 70, child: Icon(Icons.person, size: 70));
        },
      );
    }
    return const CircleAvatar(radius: 70, child: Icon(Icons.person, size: 70));
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
                  // ... аватар
                  Center(
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        _buildAvatar(),
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
                  TextField(
                    controller: _usernameController,
                    decoration: InputDecoration(
                      labelText: 'Имя пользователя',
                      hintText: 'username',
                      errorText: _usernameError,
                      border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                      prefixIcon: const Icon(Icons.alternate_email),
                    ),
                    onChanged: (_) => _checkUsername(),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _nicknameController,
                    decoration: const InputDecoration(
                      labelText: 'Отображаемое имя',
                      hintText: 'Введите ваше имя',
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Номер телефона',
                      hintText: '+7 XXX XXX XX XX',
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _bioController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'О себе',
                      hintText: 'Расскажите о себе...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                      prefixIcon: Icon(Icons.description_outlined),
                      alignLabelWithHint: true,
                    ),
                  ),
                                    const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 10),
                  const Text('Закреплённая песня (статус)', 
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _songTitleController,
                    decoration: const InputDecoration(
                      labelText: 'Название трека',
                      hintText: 'Blinding Lights',
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                      prefixIcon: Icon(Icons.music_note),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _songArtistController,
                    decoration: const InputDecoration(
                      labelText: 'Исполнитель',
                      hintText: 'The Weeknd',
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 40),
                  if (_saving) const Center(child: CircularProgressIndicator()),
                ],
              ),
            ),
    );
  }
}