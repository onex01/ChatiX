import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fluttertoast/fluttertoast.dart';
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
  Widget build(BuildContext context) {
    super.build(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isLight = Theme.of(context).brightness == Brightness.light;

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
            final isDeleted = msgData['isDeleted'] == true;

            if (isDeleted) {
              return Align(
                alignment: Alignment.center,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Сообщение удалено',
                    style: TextStyle(
                      color: isLight ? Colors.grey[500] : Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              );
            }

            // Для hex изображений
            if (messageType == 'image_hex') {
              return _buildImageMessage(msgData, isMe, time, isLight);
            }
            
            // Для hex файлов
            if (messageType == 'file_hex') {
              return _buildFileMessage(msgData, isMe, time, isLight);
            }

            // Обычное текстовое сообщение
            return _buildTextMessage(msgData, isMe, time, isLight, screenWidth, messages[index].id);
          },
        );
      },
    );
  }

  Widget _buildTextMessage(Map<String, dynamic> msgData, bool isMe, String time, bool isLight, double screenWidth, String messageId) {
    final text = msgData['text'] ?? '';
    final replyToId = msgData['replyToMessageId'] as String?;
    final repliedText = msgData['repliedMessageText'] as String?;
    final isRead = msgData['isRead'] == true;

    final bubbleColor = isMe
        ? (isLight ? const Color(0xFF007AFF) : Colors.blue)
        : (isLight ? Colors.grey[200]! : Colors.grey[800]!);

    final textColor = isMe
        ? Colors.white
        : (isLight ? Colors.black87 : Colors.white);

    return Dismissible(
      key: ValueKey(messageId),
      direction: DismissDirection.startToEnd,
      confirmDismiss: (direction) async {
        widget.onReplySwipe(messageId, text);
        return false;
      },
      background: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.only(left: 20),
        alignment: Alignment.centerLeft,
        color: Colors.blue,
        child: const Row(
          children: [
            Icon(Icons.reply, color: Colors.white),
            SizedBox(width: 8),
            Text('Ответить', style: TextStyle(color: Colors.white)),
          ],
        ),
      ),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          constraints: BoxConstraints(maxWidth: screenWidth * 0.78),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (replyToId != null && repliedText != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isMe ? Colors.white.withOpacity(0.2) : Colors.black.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.reply, size: 14, color: Colors.white70),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          repliedText,
                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              Text(
                text,
                style: TextStyle(color: textColor, fontSize: 16),
              ),
              if (msgData['isEdited'] == true)
                Text(
                  'изменено',
                  style: TextStyle(
                    color: isMe ? Colors.white60 : Colors.grey.shade500,
                    fontSize: 10,
                  ),
                ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    time,
                    style: TextStyle(
                      color: isMe ? Colors.white70 : Colors.grey.shade500,
                      fontSize: 11,
                    ),
                  ),
                  if (isMe) ...[
                    const SizedBox(width: 4),
                    if (isRead)
                      const Icon(Icons.done_all, size: 14, color: Colors.white70)
                    else
                      Icon(
                        Icons.done,
                        size: 14,
                        color: Colors.white70,
                      ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageMessage(Map<String, dynamic> msgData, bool isMe, String time, bool isLight) {
    final hexData = msgData['hexData'];
    final fileName = msgData['fileName'];
    final isRead = msgData['isRead'] == true;
    
    return FutureBuilder<File?>(
      future: hexData != null && fileName != null 
          ? FileConverterService.hexToFile(hexData, fileName)
          : Future.value(null),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.all(12),
            child: const CircularProgressIndicator(),
          );
        }
        
        final file = snapshot.data!;
        
        return Align(
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: GestureDetector(
            onTap: () => _showFullScreenImage(context, file),
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.7,
                maxHeight: 250,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      file,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        time,
                        style: TextStyle(
                          color: isLight ? Colors.grey.shade500 : Colors.grey.shade400,
                          fontSize: 11,
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        if (isRead)
                          const Icon(Icons.done_all, size: 14, color: Colors.blue)
                        else
                          Icon(
                            Icons.done,
                            size: 14,
                            color: isLight ? Colors.grey.shade500 : Colors.grey.shade400,
                          ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFileMessage(Map<String, dynamic> msgData, bool isMe, String time, bool isLight) {
    final fileName = msgData['fileName'] ?? 'Файл';
    final fileSize = msgData['fileSize'] ?? 0;
    final isRead = msgData['isRead'] == true;
    
    final bubbleColor = isMe
        ? (isLight ? const Color(0xFF007AFF) : Colors.blue)
        : (isLight ? Colors.grey[200]! : Colors.grey[800]!);
    
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _getFileIcon(msgData['fileExtension']),
                  color: isMe ? Colors.white : Colors.blue,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fileName,
                        style: TextStyle(
                          color: isMe ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        _formatFileSize(fileSize),
                        style: TextStyle(
                          color: isMe ? Colors.white70 : Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.download, color: isMe ? Colors.white : Colors.blue),
                  onPressed: () => _downloadFile(msgData),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  time,
                  style: TextStyle(
                    color: isMe ? Colors.white70 : Colors.grey.shade500,
                    fontSize: 11,
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  if (isRead)
                    const Icon(Icons.done_all, size: 14, color: Colors.white70)
                  else
                    Icon(
                      Icons.done,
                      size: 14,
                      color: Colors.white70,
                    ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _getFileIcon(String? extension) {
    if (extension == null) return Icons.insert_drive_file;
    final ext = extension.toLowerCase();
    if (ext.contains('pdf')) return Icons.picture_as_pdf;
    if (ext.contains('doc')) return Icons.description;
    if (ext.contains('xls')) return Icons.table_chart;
    if (ext.contains('ppt')) return Icons.slideshow;
    if (ext.contains('zip') || ext.contains('rar')) return Icons.folder_zip;
    if (ext.contains('mp3') || ext.contains('wav')) return Icons.audiotrack;
    if (ext.contains('mp4') || ext.contains('mov')) return Icons.video_library;
    return Icons.insert_drive_file;
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
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
      
      // Сохраняем в загрузки
      final downloadsDir = Directory('/storage/emulated/0/Download');
      if (await downloadsDir.exists()) {
        final savedFile = File('${downloadsDir.path}/$fileName');
        await file.copy(savedFile.path);
        Fluttertoast.showToast(msg: 'Файл сохранён в Загрузки');
      } else {
        // Альтернативный путь
        final tempDir = Directory.systemTemp;
        final savedFile = File('${tempDir.path}/$fileName');
        await file.copy(savedFile.path);
        Fluttertoast.showToast(msg: 'Файл сохранён: ${savedFile.path}');
      }
    } catch (e) {
      print('Ошибка сохранения файла: $e');
      Fluttertoast.showToast(msg: 'Ошибка сохранения файла');
    }
  }

  void _showFullScreenImage(BuildContext context, File file) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          body: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Center(
              child: InteractiveViewer(
                child: Image.file(file),
              ),
            ),
          ),
        ),
      ),
    );
  }
}