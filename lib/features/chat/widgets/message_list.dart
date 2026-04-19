import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/settings/settings_provider.dart';
import '../../../core/platform/platform_info.dart';
import '../../../core/logger/app_logger.dart'; 
import '../../../shared/services/file_converter_service.dart';
import '../data/chat_repository.dart';
import 'message_bubble.dart';

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

  final _chatRepository = GetIt.I<ChatRepository>();
  final _logger = GetIt.I<AppLogger>(); 

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final settings = Provider.of<SettingsProvider>(context);
    final accentColor = settings.accentColor;
    final fontSize = settings.fontSize;

    return StreamBuilder<QuerySnapshot>(
      stream: _chatRepository.getMessages(widget.chatId),
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
          padding: const EdgeInsets.only(left: 12, right: 12, top: 120, bottom: 60),
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
                    style: TextStyle(color: isLight ? Colors.grey.shade500 : Colors.grey.shade600,
                        fontStyle: FontStyle.italic, fontSize: fontSize - 2),
                  ),
                ),
              );
            }

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
                  children: [Icon(Icons.reply, color: Colors.white), SizedBox(width: 8), Text('Ответить', style: TextStyle(color: Colors.white))],
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
                onReply: () => widget.onReply(messageId, messageText),
                onCopy: () => widget.onCopy(messageText),
                onEdit: () => widget.onEdit(messageId, messageText),
                onDeleteMe: () => widget.onDeleteMe(messageId),
                onDeleteAll: () => widget.onDeleteAll(messageId),
                onForward: widget.onForward,
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
      // Использовать платформенный info для сохранения
      final platformInfo = GetIt.I<PlatformInfo>();
      final downloadsDir = await platformInfo.getDownloadsDirectory();
      if (downloadsDir != null) {
        final savedFile = File('${downloadsDir.path}/$fileName');
        await file.copy(savedFile.path);
        Fluttertoast.showToast(msg: 'Файл сохранён в Загрузки');
      } else {
        Fluttertoast.showToast(msg: 'Не удалось сохранить файл');
      }
    } catch (e, stack) {
      _logger.error('Download file error', error: e, stack: stack);
      Fluttertoast.showToast(msg: 'Ошибка сохранения файла');
    }
  }

  void _showFullScreenImage(BuildContext context, File file) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Center(child: InteractiveViewer(child: Image.file(file))),
      ),
    )));
  }
}