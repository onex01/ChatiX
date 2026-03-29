import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/message_service.dart';
import '../services/notification_service.dart';
import '../widgets/message_list.dart';
import 'user_profile_screen.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String otherUserId;

  const ChatScreen({super.key, required this.chatId, required this.otherUserId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final currentUser = FirebaseAuth.instance.currentUser!;

  String? otherUserNickname;
  String? otherUserPhotoUrl;

  String? _replyingToId;
  String? _replyingToText;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadOtherUserInfo();
  }

  Future<void> _loadOtherUserInfo() async {
    if (widget.otherUserId == currentUser.uid) {
      setState(() => otherUserNickname = 'Заметки');
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(widget.otherUserId).get();
      if (doc.exists && mounted) {
        setState(() {
          otherUserNickname = doc['nickname'] ?? widget.otherUserId;
          otherUserPhotoUrl = doc['photoUrl'];
        });
      }
    } catch (e) {
      debugPrint("Ошибка загрузки профиля: $e");
    }
    if (mounted) {
      NotificationService.saveTokenToFirestore(currentUser.uid);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _markMessagesAsRead();
    });
  }

  Future<void> _markMessagesAsRead() async {
    if (widget.otherUserId == currentUser.uid) return;

    try {
      final messagesRef = FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages');

      final unreadSnapshot = await messagesRef
          .where('senderId', isEqualTo: widget.otherUserId)
          .where('isRead', isEqualTo: false)
          .get();

      if (unreadSnapshot.docs.isEmpty) return;

      final batch = FirebaseFirestore.instance.batch();
      for (var doc in unreadSnapshot.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    } catch (e) {
      debugPrint("Ошибка при пометке сообщений как прочитанных: $e");
    }
  }

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
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Переслать — в разработке')));
  }

  void _cancelReply() {
    setState(() {
      _replyingToId = null;
      _replyingToText = null;
    });
  }

  void _handleReplySwipe(String messageId, String text) {
    setState(() {
      _replyingToId = messageId;
      _replyingToText = text;
    });
  }

  void _showAttachmentMenu() {
    final isLight = Theme.of(context).brightness == Brightness.light;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: isLight ? Colors.white : const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
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
              leading: CircleAvatar(
                backgroundColor: Colors.blue.withOpacity(0.1),
                child: const Icon(Icons.photo_library, color: Colors.blue),
              ),
              title: const Text('Фото из галереи'),
              onTap: () {
                Navigator.pop(context);
                _sendImage();
              },
            ),
            ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.green.withOpacity(0.1),
                child: const Icon(Icons.insert_drive_file, color: Colors.green),
              ),
              title: const Text('Файл'),
              onTap: () {
                Navigator.pop(context);
                _sendFile();
              },
            ),
            ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.purple.withOpacity(0.1),
                child: const Icon(Icons.camera_alt, color: Colors.purple),
              ),
              title: const Text('Снять фото'),
              onTap: () {
                Navigator.pop(context);
                _takePhoto();
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    await MessageService.sendTextMessage(
      chatId: widget.chatId,
      text: text,
      replyToMessageId: _replyingToId,
      repliedMessageText: _replyingToText,
    );

    setState(() {
      _replyingToId = null;
      _replyingToText = null;
    });
    _messageController.clear();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _sendImage() async {
    await MessageService.pickAndSendImage(
      chatId: widget.chatId,
      replyToMessageId: _replyingToId,
      repliedMessageText: _replyingToText,
    );

    setState(() {
      _replyingToId = null;
      _replyingToText = null;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _sendFile() async {
    await MessageService.pickAndSendFile(
      chatId: widget.chatId,
      replyToMessageId: _replyingToId,
      repliedMessageText: _replyingToText,
    );

    setState(() {
      _replyingToId = null;
      _replyingToText = null;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _takePhoto() async {
    await MessageService.takeAndSendPhoto(
      chatId: widget.chatId,
      replyToMessageId: _replyingToId,
      repliedMessageText: _replyingToText,
    );

    setState(() {
      _replyingToId = null;
      _replyingToText = null;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final displayName = otherUserNickname ?? widget.otherUserId;
    final isLight = Theme.of(context).brightness == Brightness.light;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: isLight ? Colors.white : null,
        foregroundColor: isLight ? Colors.black : null,
        title: GestureDetector(
          onTap: () {
            if (widget.otherUserId != currentUser.uid) {
              Navigator.push(
                context,
                CupertinoPageRoute(builder: (context) => UserProfileScreen(userId: widget.otherUserId)),
              );
            }
          },
          child: Row(
            children: [
              if (otherUserPhotoUrl != null || widget.otherUserId == currentUser.uid)
                CircleAvatar(
                  radius: 18,
                  backgroundImage: otherUserPhotoUrl != null ? NetworkImage(otherUserPhotoUrl!) : null,
                  child: otherUserPhotoUrl == null && widget.otherUserId != currentUser.uid
                      ? const Icon(Icons.person, size: 20)
                      : null,
                ),
              const SizedBox(width: 12),
              Text(
                displayName,
                style: TextStyle(
                  color: isLight ? Colors.black : null,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        centerTitle: false,
      ),
      body: Column(
        children: [
          Expanded(
            child: MessageList(
              chatId: widget.chatId,
              currentUserId: currentUser.uid,
              scrollController: _scrollController,
              onReplySwipe: _handleReplySwipe,
              onReply: _handleReply,
              onCopy: _handleCopy,
              onEdit: _handleEdit,
              onDeleteMe: (id) => _handleDelete(id, forEveryone: false),
              onDeleteAll: (id) => _handleDelete(id, forEveryone: true),
              onForward: _handleForward,
            ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(8, 8, 8, MediaQuery.of(context).padding.bottom + 8),
            decoration: BoxDecoration(
              color: isLight ? CupertinoColors.systemGrey6 : Colors.grey[900],
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isLight ? 0.08 : 0.15),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              children: [
                if (_replyingToId != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isLight ? Colors.blue.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.reply, color: Colors.blue),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Ответ на сообщение', style: TextStyle(color: Colors.blue, fontSize: 12)),
                              Text(
                                _replyingToText ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: isLight ? Colors.black87 : Colors.white70),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.grey),
                          onPressed: _cancelReply,
                        ),
                      ],
                    ),
                  ),
                Row(
                  children: [
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: _showAttachmentMenu,
                      child: Icon(
                        CupertinoIcons.paperclip,
                        color: isLight ? CupertinoColors.systemGrey : Colors.grey,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: isLight ? CupertinoColors.white : Colors.grey[800],
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: isLight ? CupertinoColors.systemGrey4 : Colors.transparent,
                            width: 1,
                          ),
                        ),
                        child: CupertinoTextField(
                          controller: _messageController,
                          placeholder: 'Сообщение...',
                          placeholderStyle: TextStyle(
                            color: isLight ? CupertinoColors.systemGrey : Colors.grey,
                          ),
                          style: TextStyle(
                            color: isLight ? CupertinoColors.black : Colors.white,
                            fontSize: 17,
                          ),
                          decoration: const BoxDecoration(),
                          maxLines: null,
                          keyboardAppearance: isLight ? Brightness.light : Brightness.dark,
                          textCapitalization: TextCapitalization.sentences,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () {},
                      child: Icon(
                        CupertinoIcons.smiley,
                        color: isLight ? CupertinoColors.systemGrey : Colors.grey,
                        size: 28,
                      ),
                    ),
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _messageController,
                      builder: (context, value, child) {
                        final hasText = value.text.trim().isNotEmpty;
                        return CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: hasText ? _sendMessage : null,
                          child: Icon(
                            CupertinoIcons.arrow_up_circle_fill,
                            color: hasText
                                ? CupertinoColors.activeBlue
                                : (isLight ? CupertinoColors.systemGrey3 : Colors.grey),
                            size: 32,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}