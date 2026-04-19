import 'dart:io';
import 'dart:async';
import 'dart:ui';
import 'package:Rizz/shared/services/audio_player_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../../../core/logger/app_logger.dart'; 
import '../../../core/settings/settings_provider.dart';
import '../../../shared/services/firestore_service.dart'; 
import '../../../shared/services/voice_service.dart';
import '../../../shared/services/chunked_file_service.dart';
import '../../profile/presentation/user_profile_screen.dart';
import '../data/chat_repository.dart';
import '../domain/message.dart';
import '../widgets/message_list.dart';
import '../widgets/chat_background.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String otherUserId;

  const ChatScreen({super.key, required this.chatId, required this.otherUserId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with SingleTickerProviderStateMixin {
  final _currentUser = FirebaseAuth.instance.currentUser!;
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final GlobalKey _textFieldKey = GlobalKey();

  // Инжектированные зависимости
  final _audioPlayerService = GetIt.I<AudioPlayerService>();
  final _chatRepository = GetIt.I<ChatRepository>();
  final _firestoreService = GetIt.I<FirestoreService>();
  final _logger = GetIt.I<AppLogger>(); 
  final _chunkedFileService = GetIt.I<ChunkedFileService>();

  String? _otherUserNickname;
  String? _otherUserPhotoUrl;
  bool? _isOnlineInChat;
  DateTime? _lastSeen;
  bool _isTyping = false;
  StreamSubscription? _chatStatusSubscription;

  String? _replyingToId;
  String? _replyingToText;
  bool _showScrollToBottom = false;
  String? _otherPinnedSongTitle;
  String? _otherPinnedSongArtist;
  String? _otherPinnedSongDuration;
  String? _otherPinnedSongUrl;   // для плеера

  // === ГЛОБАЛЬНЫЙ ПЛЕЕР (пункты 7 и 8) ===
  bool _isPlayerVisible = false;
  String? _nowPlayingTitle;
  String? _nowPlayingArtist;
  bool _isPlaying = false;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;

    String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  void initState() {
    super.initState();
    _loadOtherUserInfo();
    _setupRealTimeChatStatus();
    _joinChat();

    _audioPlayerService.isPlayingStream.listen((playing) {
  if (mounted) setState(() => _isPlaying = playing);
});
_audioPlayerService.positionStream.listen((pos) {
  if (mounted) setState(() => _currentPosition = pos);
});
_audioPlayerService.durationStream.listen((dur) {
  if (mounted) setState(() => _totalDuration = dur ?? Duration.zero);
});
_audioPlayerService.currentTitleStream.listen((title) {
  if (mounted) setState(() => _nowPlayingTitle = title);
});

    _scrollController.addListener(() {
      if (_scrollController.offset > 300 && !_showScrollToBottom) {
        setState(() => _showScrollToBottom = true);
      } else if (_scrollController.offset <= 300 && _showScrollToBottom) {
        setState(() => _showScrollToBottom = false);
      }
    });
  }

    Future<void> _loadOtherUserInfo() async {
    if (widget.otherUserId == _currentUser.uid) {
      setState(() => _otherUserNickname = 'Заметки');
      return;
    }

    try {
      final doc = await _firestoreService.getUser(widget.otherUserId);
      if (!doc.exists || !mounted) return;

      final data = doc.data() as Map<String, dynamic>;
      final pinnedSong = data['pinnedSong'] as Map<String, dynamic>? ?? {};

      setState(() {
        _otherUserNickname = data['nickname'] ?? widget.otherUserId;
        _otherUserPhotoUrl = data['photoUrl'];
        _otherPinnedSongTitle = pinnedSong['title'];
        _otherPinnedSongArtist = pinnedSong['artist'];
        _otherPinnedSongDuration = pinnedSong['duration'] ?? '3:45';
        _otherPinnedSongUrl = pinnedSong['audioUrl']; // если есть
      });
    } catch (e, stack) {
      _logger.error('Failed to load other user info', error: e, stack: stack);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => _markMessagesAsRead());
  }

  void _setupRealTimeChatStatus() {
    final chatRef = FirebaseFirestore.instance.collection('chats').doc(widget.chatId);
    _chatStatusSubscription = chatRef.snapshots().listen((snapshot) {
      if (!mounted || !snapshot.exists) return;
      final data = snapshot.data()!;
      final onlineUsers = List<String>.from(data['onlineUsers'] ?? []);
      final typingUsers = List<String>.from(data['typingUsers'] ?? []);
      setState(() {
        _isOnlineInChat = onlineUsers.contains(widget.otherUserId);
        _isTyping = typingUsers.contains(widget.otherUserId);
        _lastSeen = data['lastSeen']?.toDate();
      });
    });
  }

  Future<void> _joinChat() async {
    await _firestoreService.updateChat(widget.chatId, {
      'onlineUsers': FieldValue.arrayUnion([_currentUser.uid]),
      'lastSeen': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _leaveChat() async {
    await _firestoreService.updateChat(widget.chatId, {
      'onlineUsers': FieldValue.arrayRemove([_currentUser.uid]),
      'lastSeen': FieldValue.serverTimestamp(),
    });
  }

  void _updateTypingStatus() {
    if (widget.otherUserId == _currentUser.uid) return;
    final hasText = _messageController.text.trim().isNotEmpty;
    _firestoreService.updateChat(widget.chatId, {
      'typingUsers': hasText
          ? FieldValue.arrayUnion([_currentUser.uid])
          : FieldValue.arrayRemove([_currentUser.uid])
    });
  }

  Future<void> _markMessagesAsRead() async {
    if (widget.otherUserId == _currentUser.uid) return;
    try {
      final messagesRef = FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages');
      final unread = await messagesRef
          .where('senderId', isEqualTo: widget.otherUserId)
          .where('isRead', isEqualTo: false)
          .get();

      if (unread.docs.isEmpty) return;
      final batch = FirebaseFirestore.instance.batch();
      for (var doc in unread.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    } catch (e, stack) {
      _logger.error('Failed to mark messages as read', error: e, stack: stack);
    }
  }

  // ==================== ОТПРАВКА СООБЩЕНИЙ ====================
  void _playSendAnimation(String text, Color bubbleColor) {
    final renderBox = _textFieldKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    
    final offset = renderBox.localToGlobal(Offset.zero);
    final width = renderBox.size.width;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) {
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
          onEnd: () => entry.remove(),
          builder: (context, value, child) {
            return Positioned(
              left: offset.dx + 40, // Сдвиг от скрепки
              top: offset.dy - (value * 120), // Вылет вверх
              width: width * 0.75,
              child: Opacity(
                opacity: 1.0 - value, // Плавное исчезновение
                child: Transform.scale(
                  scale: 1.0 - (value * 0.1), // Легкое уменьшение
                  child: Material(
                    color: Colors.transparent,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                        decoration: BoxDecoration(
                          color: bubbleColor,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Text(
                          text,
                          style: const TextStyle(color: Colors.white, fontSize: 17),
                          maxLines: null,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
    Overlay.of(context).insert(entry);
  }
  // ==================== ИСПРАВЛЕННЫЙ _sendMessage() с Telegram-анимацией ====================
  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
 
    await _firestoreService.updateChat(widget.chatId, {
      'typingUsers': FieldValue.arrayRemove([_currentUser.uid])
    });

    HapticFeedback.lightImpact(); // Нативный тактильный отклик

    final settings = Provider.of<SettingsProvider>(context, listen: false);
    
    // Запускаем красивую анимацию
    _playSendAnimation(text, settings.accentColor);

    final message = Message(
      id: '',
      senderId: _currentUser.uid,
      text: text,
      timestamp: Timestamp.now(),
      replyToMessageId: _replyingToId,
      repliedMessageText: _replyingToText,
    );
 
    _messageController.clear();
    setState(() {
      _replyingToId = null;
      _replyingToText = null;
    });

    await _chatRepository.sendMessage(widget.chatId, message);
    await _chatRepository.updateLastMessage(widget.chatId, text, 'text');

    _scrollToBottom();
  }

  Future<void> _sendImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 800);
    if (picked == null) return;

    await _sendMediaMessage(
      file: File(picked.path),
      type: 'image_hex',
      previewText: '📷 Фото',
    );
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _sendFile() async {
  // Changed from FilePicker.platform.pickFiles()
  final FilePickerResult? result = await FilePicker.pickFiles();

  if (result == null || result.files.isEmpty) return;

  final file = File(result.files.first.path!);
  
  await _sendMediaMessage(
    file: file,
    type: 'file_hex',
    previewText: '📎 ${file.path.split('/').last}',
  );
}

  Future<void> _takePhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.camera, imageQuality: 85, maxWidth: 800);
    if (picked == null) return;

    await _sendMediaMessage(
      file: File(picked.path),
      type: 'image_hex',
      previewText: '📷 Фото',
    );
  }

    Future<void> _playOtherUserSong() async {
    if (_otherPinnedSongUrl == null) {
      _showToast('Песня пока не доступна для прослушивания');
      return;
    }

    setState(() {
      _nowPlayingTitle = _otherPinnedSongTitle;
      _nowPlayingArtist = _otherPinnedSongArtist;
      _isPlayerVisible = true;
      _isPlaying = true;
    });

    await _audioPlayerService.playUrl(
  _otherPinnedSongUrl!,
  title: _otherPinnedSongTitle!,
  artist: _otherPinnedSongArtist,
);
  }

  Future<void> _sendMediaMessage({
    required File file,
    required String type,
    required String previewText,
  }) async {
    try {
      final fileSize = await file.length();
      final fileName = file.path.split('/').last;
      final fileExtension = fileName.split('.').last;

      // Проверка размера: если > 500 KB, используем чанки
      if (fileSize > 500 * 1024) {
        await _sendLargeFile(file, fileName, fileSize, previewText);
        return;
      }

      final bytes = await file.readAsBytes();
      final hexData = _bytesToHex(bytes);

      final mediaData = {
        'hexData': hexData,
        'fileName': fileName,
        'fileSize': fileSize,
        'fileExtension': fileExtension,
      };

      final message = Message(
        id: '',
        senderId: _currentUser.uid,
        text: '',
        timestamp: Timestamp.now(),
        replyToMessageId: _replyingToId,
        repliedMessageText: _replyingToText,
        type: type,
        mediaData: mediaData,
      );

      await _chatRepository.sendMessage(widget.chatId, message);
      await _chatRepository.updateLastMessage(widget.chatId, previewText, type);
      setState(() {
        _replyingToId = null;
        _replyingToText = null;
      });
      _scrollToBottom();
    } catch (e, stack) {
      _logger.error('Failed to send media message', error: e, stack: stack);
      _showToast('Ошибка отправки файла');
    }
  }

  Future<void> _sendLargeFile(File file, String fileName, int fileSize, String previewText) async {
    try {
      final bytes = await file.readAsBytes();
      final fileId = await _chunkedFileService.uploadLargeFile(bytes, fileName);

      final mediaData = {
        'largeFileId': fileId,
        'fileName': fileName,
        'fileSize': fileSize,
      };

      final message = Message(
        id: '',
        senderId: _currentUser.uid,
        text: '',
        timestamp: Timestamp.now(),
        replyToMessageId: _replyingToId,
        repliedMessageText: _replyingToText,
        type: 'large_file',
        mediaData: mediaData,
      );

      await _chatRepository.sendMessage(widget.chatId, message);
      await _chatRepository.updateLastMessage(widget.chatId, '📁 $fileName', 'large_file');
      setState(() {
        _replyingToId = null;
        _replyingToText = null;
      });
      _scrollToBottom();
    } catch (e, stack) {
      _logger.error('Failed to send large file', error: e, stack: stack);
      _showToast('Ошибка отправки большого файла');
    }
  }

  // Вспомогательная функция для конвертации байт в hex
  String _bytesToHex(List<int> bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
 
  // ==================== ГОЛОСОВЫЕ И ВИДЕОКРУЖКИ ====================
  Future<void> _startVoiceRecording() async {
    await VoiceService.startRecording();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => VoiceRecorderDialog(
        onSend: (File file) async {
          // Отправка голосового через hex
          await _sendMediaMessage(
            file: file,
            type: 'voice',
            previewText: '🎤 Голосовое',
          );
        },
      ),
    );
  } 
  // ==================== ДЕЙСТВИЯ С СООБЩЕНИЯМИ ====================
  void _handleReply(String messageId, String text) {
    setState(() {
      _replyingToId = messageId;
      _replyingToText = text;
    });
  }

  void _handleCopy(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Текст скопирован')));
  }

  Future<void> _handleEdit(String messageId, String oldText) async {
    final controller = TextEditingController(text: oldText);
    final newText = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Изменить сообщение'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
          TextButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Сохранить')),
        ],
      ),
    );
    if (newText == null || newText.isEmpty || newText == oldText) return;

    await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .doc(messageId)
        .update({'text': newText, 'isEdited': true, 'editedAt': FieldValue.serverTimestamp()});
  }

  Future<void> _handleDelete(String messageId, {required bool forEveryone}) async {
    if (forEveryone) {
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .doc(messageId)
          .update({'isDeleted': true});
    } else {
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .doc(messageId)
          .delete();
    }
  }

  void _handleForward() {
    _showToast('Переслать — в разработке');
  }

  void _cancelReply() {
    setState(() {
      _replyingToId = null;
      _replyingToText = null;
    });
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  String _getStatusText() {
    if (_isTyping) return 'печатает...';
    if (_isOnlineInChat == true) return 'В сети';
    if (_lastSeen == null) return 'Был(а) недавно';
    final diff = DateTime.now().difference(_lastSeen!);
    if (diff.inMinutes < 1) return 'Был(а) недавно';
    if (diff.inHours < 1) return 'Был(а) ${diff.inMinutes} мин назад';
    if (diff.inDays < 1) return 'Был(а) ${diff.inHours} ч назад';
    if (diff.inDays < 7) return 'Был(а) ${diff.inDays} дн назад';
    return 'Был(а) ${_lastSeen!.day}.${_lastSeen!.month}.${_lastSeen!.year}';
  }

  // ==================== ДОПОЛНИТЕЛЬНО: обновлённый _showAttachmentMenu (ещё один Telegram-штрих) ====================
  void _showAttachmentMenu() {
    final isLight = Theme.of(context).brightness == Brightness.light;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            color: isLight ? Colors.white.withOpacity(0.95) : Colors.black.withOpacity(0.95),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: isLight ? Colors.grey.shade300 : Colors.grey.shade600,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  ListTile(
                    leading: CircleAvatar(backgroundColor: Colors.blue.withValues(alpha: 0.1), child: const Icon(Icons.photo_library, color: Colors.blue)),
                    title: const Text('Фото из галереи'),
                    onTap: () { Navigator.pop(context); _sendImage(); },
                  ),
                  ListTile(
                    leading: CircleAvatar(backgroundColor: Colors.green.withValues(alpha: 0.1), child: const Icon(Icons.insert_drive_file, color: Colors.green)),
                    title: const Text('Файл'),
                    onTap: () { Navigator.pop(context); _sendFile(); },
                  ),
                  ListTile(
                    leading: CircleAvatar(backgroundColor: Colors.purple.withValues(alpha: 0.1), child: const Icon(Icons.camera_alt, color: Colors.purple)),
                    title: const Text('Снять фото'),
                    onTap: () { Navigator.pop(context); _takePhoto(); },
                  ),
                  ListTile(
                    leading: CircleAvatar(backgroundColor: Colors.red.withValues(alpha: 0.1), child: const Icon(Icons.mic, color: Colors.red)),
                    title: const Text('Голосовое сообщение'),
                    onTap: () { Navigator.pop(context); _startVoiceRecording(); },
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _leaveChat();
    _chatStatusSubscription?.cancel();
    _scrollController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final displayName = _otherUserNickname ?? widget.otherUserId;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final settings = Provider.of<SettingsProvider>(context);
    final bgColor = settings.chatBackgroundColor ?? (isLight ? Colors.white : Colors.black);
    final accentColor = settings.accentColor;

    return Scaffold(
      extendBodyBehindAppBar: true, // КРИТИЧНО ДЛЯ БЛЮРА APPBAR
      backgroundColor: bgColor,
      
      // ==================== БЛЮР TOP-BAR ====================
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
            child: AppBar(
              backgroundColor: isLight
                  ? Colors.white.withOpacity(0.65) // Более прозрачный для iOS стиля
                  : Colors.black.withOpacity(0.65),
              foregroundColor: isLight ? Colors.black : Colors.white,
              elevation: 0,
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(0.5),
                child: Container(
                  color: isLight ? Colors.black.withOpacity(0.1) : Colors.white.withOpacity(0.1),
                  height: 0.5,
                ),
              ),
              title: GestureDetector(
                onTap: () {
                  if (widget.otherUserId != _currentUser.uid) {
                    Navigator.push(context, CupertinoPageRoute(builder: (_) => UserProfileScreen(userId: widget.otherUserId)));
                  }
                },
                child: Row(
                  children: [
                    if (_otherUserPhotoUrl != null || widget.otherUserId == _currentUser.uid)
                      CircleAvatar(
                        radius: 18,
                        backgroundImage: _otherUserPhotoUrl != null ? NetworkImage(_otherUserPhotoUrl!) : null,
                        child: _otherUserPhotoUrl == null && widget.otherUserId != _currentUser.uid
                            ? const Icon(Icons.person, size: 20)
                            : null,
                      ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(displayName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 17)),
                        if (widget.otherUserId != _currentUser.uid)
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: Text(
                              _getStatusText(),
                              key: ValueKey(_isTyping),
                              style: TextStyle(
                                fontSize: 13,
                                color: _isTyping ? accentColor : (_isOnlineInChat == true ? accentColor : Colors.grey),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              centerTitle: false,
            ),
          ),
        ),
      ),

      body: Stack(
        children: [
          // 1. Фон и Сообщения (скроллятся под блюром)
          ChatBackground(
            backgroundColor: bgColor,
            wallpaperUrl: settings.wallpaperUrl,
            enableEffects: settings.useProceduralBackground,
            child: MessageList(
              chatId: widget.chatId,
              currentUserId: _currentUser.uid,
              scrollController: _scrollController,
              onReplySwipe: _handleReply,
              onReply: _handleReply,
              onCopy: _handleCopy,
              onEdit: _handleEdit,
              onDeleteMe: (id) => _handleDelete(id, forEveryone: false),
              onDeleteAll: (id) => _handleDelete(id, forEveryone: true),
              onForward: _handleForward,
              // Убедитесь, что в MessageList добавлен padding снизу (около 120), чтобы нижний бар не перекрывал последнее сообщение!
            ),
          ),

                    // ==================== 10. БЛЮР-Виджет музыки собеседника ====================
          if (_otherPinnedSongTitle != null && _otherPinnedSongTitle!.isNotEmpty)
            Positioned(
              top: kToolbarHeight + 22,
              left: 16,
              right: 16,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isLight
                          ? Colors.white.withOpacity(0.65)
                          : Colors.black.withOpacity(0.65),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isLight ? Colors.black.withOpacity(0.1) : Colors.white.withOpacity(0.1),
                        width: 0.5,
                      ),
                    ),
                    child: GestureDetector(
                      onTap: _playOtherUserSong,
                      child: Row(
                        children: [
                          const Icon(Icons.music_note, color: Colors.deepPurple, size: 28),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_otherPinnedSongTitle!, style: const TextStyle(fontWeight: FontWeight.w600)),
                                Text(_otherPinnedSongArtist ?? '', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                              ],
                            ),
                          ),
                          Text(_otherPinnedSongDuration ?? '', style: const TextStyle(fontSize: 13)),
                          const SizedBox(width: 8),
                          const Icon(Icons.play_arrow_rounded, color: Colors.deepPurple),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // 2. Плавающая кнопка "Вниз" (Telegram Feature)
          Positioned(
            bottom: 90 + MediaQuery.of(context).viewInsets.bottom, // Над полем ввода
            right: 16,
            child: AnimatedScale(
              scale: _showScrollToBottom ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutBack,
              child: FloatingActionButton(
                mini: true,
                backgroundColor: isLight ? Colors.white : Colors.grey[800],
                foregroundColor: isLight ? Colors.black54 : Colors.white70,
                elevation: 4,
                onPressed: _scrollToBottom,
                child: const Icon(Icons.keyboard_arrow_down, size: 30),
              ),
            ),
          ),

          // 3. БЛЮР ПОЛЯ ОТПРАВКИ СООБЩЕНИЯ (Glassmorphism)
          Align(
            alignment: Alignment.bottomCenter,
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                child: Container(
                  padding: EdgeInsets.fromLTRB(8, 8, 8, MediaQuery.of(context).padding.bottom + 8),
                  decoration: BoxDecoration(
                    color: isLight
                        ? Colors.white.withOpacity(0.7) // Telegram iOS style
                        : const Color(0xFF1C1C1D).withOpacity(0.7),
                    border: Border(
                      top: BorderSide(
                        color: isLight ? Colors.black.withOpacity(0.1) : Colors.white.withOpacity(0.1),
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Плашка ответа
                      if (_replyingToId != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isLight ? Colors.black.withOpacity(0.05) : Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Container(width: 3, height: 35, color: accentColor),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Ответ', style: TextStyle(color: accentColor, fontSize: 13, fontWeight: FontWeight.w600)),
                                    Text(
                                      _replyingToText ?? '',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(color: isLight ? Colors.black87 : Colors.white70, fontSize: 14),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(CupertinoIcons.clear_circled_solid, color: Colors.grey, size: 20),
                                onPressed: _cancelReply,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                        ),
                      
                      // Поле ввода
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          CupertinoButton(
                            padding: const EdgeInsets.only(bottom: 4),
                            onPressed: _showAttachmentMenu,
                            child: Icon(CupertinoIcons.paperclip, color: isLight ? CupertinoColors.systemGrey : Colors.grey, size: 26),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            key: _textFieldKey, // Ключ для анимации вылета
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 2),
                              decoration: BoxDecoration(
                                color: isLight ? Colors.black.withOpacity(0.05) : Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.transparent),
                              ),
                              child: CupertinoTextField(
                                controller: _messageController,
                                placeholder: 'Напишите, скучно...',
                                placeholderStyle: TextStyle(color: isLight ? CupertinoColors.systemGrey : Colors.grey.shade400),
                                style: TextStyle(color: isLight ? CupertinoColors.black : Colors.white, fontSize: 17),
                                decoration: const BoxDecoration(),
                                maxLines: 5,
                                minLines: 1,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                keyboardAppearance: isLight ? Brightness.light : Brightness.dark,
                                textCapitalization: TextCapitalization.sentences,
                                onChanged: (_) => _updateTypingStatus(),
                                onSubmitted: (_) {
                                  if (settings.sendByEnter) _sendMessage();
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          
                          // Микрофон / Кнопка отправки с морфингом
                          ValueListenableBuilder<TextEditingValue>(
                            valueListenable: _messageController,
                            builder: (context, value, child) {
                              final hasText = value.text.trim().isNotEmpty;
                              return AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                                child: hasText
                                    ? CupertinoButton(
                                        key: const ValueKey('send'),
                                        padding: const EdgeInsets.only(bottom: 4),
                                        onPressed: _sendMessage,
                                        child: Icon(CupertinoIcons.arrow_up_circle_fill, color: accentColor, size: 32),
                                      )
                                    : CupertinoButton(
                                        key: const ValueKey('mic'),
                                        padding: const EdgeInsets.only(bottom: 4),
                                        onPressed: () {}, // Заглушка клика
                                        onLongPress: _startVoiceRecording,
                                        child: Icon(CupertinoIcons.mic, color: isLight ? CupertinoColors.systemGrey : Colors.grey, size: 28),
                                      ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
                    // ==================== 7. ПАНЕЛЬ ПЛЕЕРА (аудио + голосовые) ====================
                    // ==================== 7. ПАНЕЛЬ ПЛЕЕРА С ПРОГРЕСС-БАРОМ ====================
          if (_isPlayerVisible)
            Positioned(
              bottom: 90 + MediaQuery.of(context).viewInsets.bottom + 8,
              left: 16,
              right: 16,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isLight 
                          ? Colors.white.withOpacity(0.92)
                          : const Color(0xFF1C1C1D).withOpacity(0.92),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isLight ? Colors.black.withOpacity(0.08) : Colors.white.withOpacity(0.08),
                        width: 0.5,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Заголовок трека
                        Row(
                          children: [
                            const Icon(Icons.music_note, color: Colors.deepPurple, size: 24),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _nowPlayingTitle ?? 'Сейчас играет',
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (_nowPlayingArtist != null)
                                    Text(
                                      _nowPlayingArtist!,
                                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Icon(_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, 
                                         color: Colors.deepPurple),
                              onPressed: () async {
                                if (_isPlaying) {
                                  await _audioPlayerService.pause();
                                } else {
                                  await _audioPlayerService.resume();
                                }
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded, size: 22),
                              onPressed: () {
                                _audioPlayerService.stop();
                                setState(() => _isPlayerVisible = false);
                              },
                            ),
                          ],
                        ),

                        const SizedBox(height: 8),

                        // Прогресс-бар + время
                        Row(
                          children: [
                            Text(
                              _formatDuration(_currentPosition),
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                            Expanded(
                              child: SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  trackHeight: 3,
                                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                                ),
                                child: Slider(
                                  value: _currentPosition.inMilliseconds.toDouble().clamp(
                                        0,
                                        (_totalDuration.inMilliseconds > 0 
                                            ? _totalDuration.inMilliseconds 
                                            : 1).toDouble(),
                                      ),
                                  max: _totalDuration.inMilliseconds.toDouble() > 0 
                                      ? _totalDuration.inMilliseconds.toDouble() 
                                      : 1,
                                  activeColor: Colors.deepPurple,
                                  inactiveColor: Colors.grey.withOpacity(0.3),
                                  onChanged: (value) {
                                    _audioPlayerService.seek(Duration(milliseconds: value.toInt()));
                                  },
                                ),
                              ),
                            ),
                            Text(
                              _formatDuration(_totalDuration),
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}