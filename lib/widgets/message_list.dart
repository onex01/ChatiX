import 'dart:io';
import 'package:ChatiX/providers/settings_provider.dart';
import 'package:ChatiX/widgets/message_bubble.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';

import '../services/file_converter_service.dart';

class MessageList extends StatefulWidget {
  final String chatId;
  final String currentUserId;
  final ScrollController scrollController;
  final Function(String, String) onReplySwipe;
  final Function(String, String) onReply;
  final Function(String) onCopy;
  final Function(String, String) onEdit;
  final Function(String) onDeleteMe;
  final Function(String) onDeleteAll;
  final Function() onForward;

  const MessageList({
    super.key,
    required this.chatId,
    required this.currentUserId,
    required this.scrollController,
    required this.onReplySwipe,
    required this.onReply,
    required this.onCopy,
    required this.onEdit,
    required this.onDeleteMe,
    required this.onDeleteAll,
    required this.onForward,
  });

  @override
  State<MessageList> createState() => _MessageListState();
}

class _MessageListState extends State<MessageList> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    super.dispose();
  }

  List<CupertinoContextMenuAction> _buildMessageMenuActions(
    bool isMe,
    String messageId,
    String text,
    String type,
    Map<String, dynamic> msgData,
  ) {
    return [
      CupertinoContextMenuAction(
        child: const Text('Ответить'),
        trailingIcon: Icons.reply,
        onPressed: () {
          Navigator.pop(context);
          widget.onReply(messageId, text);
        },
      ),
      if (type == 'text') ...[
        CupertinoContextMenuAction(
          child: const Text('Копировать'),
          trailingIcon: Icons.copy,
          onPressed: () {
            Navigator.pop(context);
            widget.onCopy(text);
          },
        ),
        if (isMe)
          CupertinoContextMenuAction(
            child: const Text('Изменить'),
            trailingIcon: Icons.edit,
            onPressed: () {
              Navigator.pop(context);
              widget.onEdit(messageId, text);
            },
          ),
      ],
      if (type == 'image_hex')
        CupertinoContextMenuAction(
          child: const Text('Сохранить в галерею'),
          trailingIcon: Icons.save_alt,
          onPressed: () {
            Navigator.pop(context);
            Fluttertoast.showToast(msg: 'Сохранение изображения... (TODO)');
          },
        ),
      if (type == 'file_hex')
        CupertinoContextMenuAction(
          child: const Text('Скачать файл'),
          trailingIcon: Icons.download,
          onPressed: () {
            Navigator.pop(context);
            _downloadFile(msgData);
          },
        ),
      CupertinoContextMenuAction(
        child: const Text('Удалить у меня'),
        trailingIcon: Icons.delete_outline,
        onPressed: () {
          Navigator.pop(context);
          widget.onDeleteMe(messageId);
        },
      ),
      if (isMe)
        CupertinoContextMenuAction(
          isDestructiveAction: true,
          child: const Text('Удалить у всех'),
          trailingIcon: Icons.delete_forever,
          onPressed: () {
            Navigator.pop(context);
            widget.onDeleteAll(messageId);
          },
        ),
      CupertinoContextMenuAction(
        child: const Text('Переслать'),
        trailingIcon: Icons.forward,
        onPressed: () {
          Navigator.pop(context);
          widget.onForward();
        },
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    final settings = Provider.of<SettingsProvider>(context);
    final accentColor = settings.accentColor;
    final fontSize = settings.fontSize;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && snapshot.data == null) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('Нет сообщений. Напишите первое!'));
        }

        final messages = snapshot.data!.docs;

        return ListView.builder(
          controller: widget.scrollController,
          reverse: true,
          padding: const EdgeInsets.all(12),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final msgData = messages[index].data() as Map<String, dynamic>;
            final isMe = msgData['senderId'] == widget.currentUserId;
            final timestamp = msgData['timestamp'] as Timestamp?;
            final time = timestamp != null ? DateFormat('HH:mm').format(timestamp.toDate()) : '';
            final messageType = msgData['type'] ?? 'text';
            final messageId = messages[index].id;
            final messageText = msgData['text'] ?? msgData['fileName'] ?? '';

            if (msgData['isDeleted'] == true) {
              return Align(
                alignment: Alignment.center,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Сообщение удалено',
                    style: TextStyle(
                      color: isLight ? Colors.grey[500] : Colors.grey[600],
                      fontStyle: FontStyle.italic,
                      fontSize: fontSize - 2,
                    ),
                  ),
                ),
              );
            }

            _buildMessageMenuActions(
              isMe,
              messageId,
              messageText,
              messageType,
              msgData,
            );

                        return Dismissible(
              key: ValueKey(messageId),
              direction: DismissDirection.startToEnd,
              confirmDismiss: (direction) async {
                widget.onReplySwipe(messageId, messageText);
                return false;
              },
              background: Container(
                margin: const EdgeInsets.symmetric(vertical: 6),
                padding: const EdgeInsets.only(left: 20),
                alignment: Alignment.centerLeft,
                color: accentColor,
                child: const Row(
                  children: [
                    Icon(Icons.reply, color: Colors.white),
                    SizedBox(width: 8),
                    Text('Ответить', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              child: MessageBubble(
                msgData: msgData,
                isMe: isMe,
                time: time,
                isLight: isLight,
                screenWidth: screenWidth,
                messageType: messageType,
                accentColor: accentColor,
                fontSize: fontSize,
                onDownloadFile: _downloadFile,
                onShowFullScreenImage: _showFullScreenImage,
                // Новые обязательные параметры для CupertinoContextMenu
                onReply: () => widget.onReply(messageId, messageText),
                onCopy: () => widget.onCopy(messageText),
                onEdit: () => widget.onEdit(messageId, messageText),
                onDeleteMe: () => widget.onDeleteMe(messageId),
                onDeleteAll: () => widget.onDeleteAll(messageId),
                onForward: widget.onForward,
                // ← ОБЯЗАТЕЛЬНЫЙ ПАРАМЕТР ДЛЯ КЭША
                messageId: messageId,
              ),
            );
          },
        );
      },
    );
   }
 
  Future<void> _downloadFile(Map<String, dynamic> msgData) async {
    try {
      final hexData = msgData['hexData'];
      final fileName = msgData['fileName'];

      if (hexData == null || fileName == null) {
        Fluttertoast.showToast(msg: 'Ошибка: файл не найден');
        return;
      }

      final file = await FileConverterService.hexToFile(hexData, fileName);

      final downloadsDir = Directory('/storage/emulated/0/Download');
      if (await downloadsDir.exists()) {
        final savedFile = File('${downloadsDir.path}/$fileName');
        await file.copy(savedFile.path);
        Fluttertoast.showToast(msg: 'Файл сохранён в Загрузки');
      } else {
        final tempDir = Directory.systemTemp;
        final savedFile = File('${tempDir.path}/$fileName');
        await file.copy(savedFile.path);
        Fluttertoast.showToast(msg: 'Файл сохранён: ${savedFile.path}');
      }
    } catch (e) {
      debugPrint('Ошибка сохранения файла: $e');
      Fluttertoast.showToast(msg: 'Ошибка сохранения файла');
    }
  }

  void _showFullScreenImage(BuildContext context, File file) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          body: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Center(
              child: InteractiveViewer(child: Image.file(file)),
            ),
          ),
        ),
      ),
    );
  }
}