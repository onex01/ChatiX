import 'package:ChatiX/services/notification_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/message_list.dart';
import 'user_profile_screen.dart';          // ← Новый импорт

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
      print("Ошибка загрузки профиля: $e");
    }
    // В самом конце _loadOtherUserInfo()
if (mounted) {
  NotificationService.saveTokenToFirestore(currentUser.uid);
}
  }

  void _showFloatingMessageMenu(BuildContext context, LongPressStartDetails details, String messageId, Map<String, dynamic> msgData) {
    final isMe = msgData['senderId'] == currentUser.uid;
    final text = msgData['text'] ?? '';

    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(details.globalPosition, details.globalPosition),
      Offset.zero & overlay.size,
    );

    showMenu<String>(
      context: context,
      position: position,
      color: Colors.grey[850],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      items: [
        PopupMenuItem(value: 'reply', child: _menuRow(Icons.reply, 'Ответить')),
        PopupMenuItem(value: 'copy', child: _menuRow(Icons.copy, 'Копировать')),
        if (isMe) PopupMenuItem(value: 'edit', child: _menuRow(Icons.edit, 'Изменить')),
        PopupMenuItem(value: 'deleteMe', child: _menuRow(Icons.delete_outline, 'Удалить у меня')),
        if (isMe) PopupMenuItem(value: 'deleteAll', child: _menuRow(Icons.delete_forever, 'Удалить у всех', color: Colors.red)),
        PopupMenuItem(value: 'forward', child: _menuRow(Icons.forward, 'Переслать')),
      ],
    ).then((value) {
      if (value == null) return;
      switch (value) {
        case 'reply':
          setState(() {
            _replyingToId = messageId;
            _replyingToText = text;
          });
          break;
        case 'copy':
          Clipboard.setData(ClipboardData(text: text));
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Текст скопирован')));
          break;
        case 'edit':
          _editMessage(messageId, text);
          break;
        case 'deleteMe':
          _deleteMessage(messageId, forEveryone: false);
          break;
        case 'deleteAll':
          _deleteMessage(messageId, forEveryone: true);
          break;
        case 'forward':
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Переслать — в разработке')));
          break;
      }
    });
  }

  Widget _menuRow(IconData icon, String text, {Color? color}) {
    return Row(
      children: [
        Icon(icon, color: color ?? Colors.white, size: 22),
        const SizedBox(width: 16),
        Text(text, style: TextStyle(color: color ?? Colors.white, fontSize: 16)),
      ],
    );
  }

  Future<void> _editMessage(String messageId, String oldText) async {
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

  Future<void> _deleteMessage(String messageId, {required bool forEveryone}) async {
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

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final messageData = {
      'senderId': currentUser.uid,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
      'replyToMessageId': _replyingToId,
      'repliedMessageText': _replyingToText,
    };

    await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .add(messageData);

    await FirebaseFirestore.instance.collection('chats').doc(widget.chatId).update({
      'lastMessage': text,
      'lastMessageTime': FieldValue.serverTimestamp(),
    });

    setState(() {
      _replyingToId = null;
      _replyingToText = null;
    });
    _messageController.clear();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
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

  @override
  void dispose() {
    _scrollController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final displayName = otherUserNickname ?? widget.otherUserId;

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: () {
            // Не открываем профиль для собственных заметок
            if (widget.otherUserId != currentUser.uid) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => UserProfileScreen(userId: widget.otherUserId),
                ),
              );
            }
          },
          child: Row(
            children: [
              if (otherUserPhotoUrl != null || widget.otherUserId == currentUser.uid)
                CircleAvatar(
                  radius: 18,
                  backgroundImage: otherUserPhotoUrl != null ? NetworkImage(otherUserPhotoUrl!) : null,
                  child: otherUserPhotoUrl == null && widget.otherUserId != currentUser.uid ? const Icon(Icons.person, size: 20) : null,
                ),
              const SizedBox(width: 12),
              Text(displayName),
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
              onLongPress: _showFloatingMessageMenu,
              onReplySwipe: _handleReplySwipe,
            ),
          ),

          Container(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 13),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 8, offset: const Offset(0, -3))],
            ),
            child: Column(
              children: [
                if (_replyingToId != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      children: [
                        const Icon(Icons.reply, color: Colors.blue),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Ответ на сообщение', style: TextStyle(color: Colors.blue, fontSize: 12)),
                              Text(_replyingToText ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70)),
                            ],
                          ),
                        ),
                        IconButton(icon: const Icon(Icons.close, color: Colors.grey), onPressed: _cancelReply),
                      ],
                    ),
                  ),
                Row(
                  children: [
                    IconButton(icon: const Icon(Icons.attach_file, color: Colors.grey), onPressed: () {}),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(color: Colors.grey[800], borderRadius: BorderRadius.circular(30)),
                        child: TextField(
                          controller: _messageController,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: const InputDecoration(hintText: 'Сообщение...', border: InputBorder.none, hintStyle: TextStyle(color: Colors.grey)),
                          maxLines: null,
                        ),
                      ),
                    ),
                    IconButton(icon: const Icon(Icons.emoji_emotions_outlined, color: Colors.grey), onPressed: () {}),
                    IconButton(icon: const Icon(Icons.send, color: Colors.blue), onPressed: _sendMessage),
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