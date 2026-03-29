import 'dart:io';
import 'dart:convert';
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

  // Множественный выбор
  final Set<String> _selectedMessageIds = {};
  bool get _isMultiSelectMode => _selectedMessageIds.isNotEmpty;

  void _toggleSelection(String messageId) {
    setState(() {
      if (_selectedMessageIds.contains(messageId)) {
        _selectedMessageIds.remove(messageId);
      } else {
        _selectedMessageIds.add(messageId);
      }
    });
  }

  void _clearSelection() {
    setState(() => _selectedMessageIds.clear());
  }

  Future<void> _deleteSelected({required bool forEveryone}) async {
    if (_selectedMessageIds.isEmpty) return;

    final count = _selectedMessageIds.length;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Удалить $count сообщений?'),
        content: Text(forEveryone
            ? 'Сообщения будут удалены у всех участников чата.'
            : 'Сообщения будут удалены только у вас.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final batch = FirebaseFirestore.instance.batch();
    final messagesRef = FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages');

    for (final id in _selectedMessageIds) {
      if (forEveryone) {
        batch.update(messagesRef.doc(id), {'isDeleted': true});
      } else {
        batch.delete(messagesRef.doc(id));
      }
    }

    await batch.commit();
    _clearSelection();
    Fluttertoast.showToast(msg: '$count сообщений удалено');
  }

  // ====================== КОНТЕКСТНОЕ МЕНЮ ======================
  List<Widget> _buildMessageMenuActions(bool isMe, String messageId, String text, {bool isMedia = false}) {
    return [
      CupertinoContextMenuAction(
        child: const Text('Ответить'),
        trailingIcon: Icons.reply,
        onPressed: () {
          Navigator.pop(context);
          widget.onReply(messageId, text);
        },
      ),
      if (!isMedia)
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

  // ====================== ИЗОБРАЖЕНИЕ ======================
  Widget _buildImageMessage(Map<String, dynamic> msgData, bool isMe, String time, bool isLight) {
    final String messageId = msgData['id'] ?? '';
    final String? hexData = msgData['hexData'];
    final String? thumbnailBase64 = msgData['thumbnailBase64'];
    final String fileName = msgData['fileName'] ?? 'Фото';
    final bool isSelected = _selectedMessageIds.contains(messageId);

    return GestureDetector(
      onLongPress: () => _toggleSelection(messageId),
      onTap: _isMultiSelectMode
          ? () => _toggleSelection(messageId)
          : () async {
              if (hexData == null) return;
              try {
                final file = await FileConverterService.hexToFile(hexData, fileName);
                if (context.mounted) _showFullScreenImage(context, file);
              } catch (e) {
                Fluttertoast.showToast(msg: 'Не удалось открыть фото');
              }
            },
      child: Stack(
        children: [
          Align(
            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 6),
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.25)),
              ),
              clipBehavior: Clip.hardEdge,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 280,
                    width: double.infinity,
                    child: thumbnailBase64 != null && thumbnailBase64.isNotEmpty
                        ? Image.memory(base64Decode(thumbnailBase64), fit: BoxFit.cover)
                        : FutureBuilder<File>(
                            future: hexData != null
                                ? FileConverterService.hexToFile(hexData, fileName)
                                : Future.error('no data'),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return _buildLoadingPlaceholder();
                              }
                              if (snapshot.hasData) {
                                return Image.file(snapshot.data!, fit: BoxFit.cover);
                              }
                              return _buildPlaceholder();
                            },
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            fileName,
                            style: TextStyle(
                              color: isMe ? Colors.white70 : Colors.grey.shade600,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          time,
                          style: TextStyle(
                            color: isMe ? Colors.white70 : Colors.grey.shade600,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isSelected)
            Positioned(
              top: 12,
              right: isMe ? 12 : null,
              left: isMe ? null : 12,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 20),
              ),
            ),
        ],
      ),
    );
  }

  // ====================== ФАЙЛ ======================
  Widget _buildFileMessage(Map<String, dynamic> msgData, bool isMe, String time, bool isLight) {
    final String messageId = msgData['id'] ?? '';
    final fileName = msgData['fileName'] ?? 'Файл';
    final fileSize = msgData['fileSize'] ?? 0;
    final fileExtension = (msgData['fileExtension'] ?? '').toString().toLowerCase();
    final bool isSelected = _selectedMessageIds.contains(messageId);

    return GestureDetector(
      onLongPress: () => _toggleSelection(messageId),
      onTap: _isMultiSelectMode
          ? () => _toggleSelection(messageId)
          : () => _downloadFile(msgData),
      child: Stack(
        children: [
          Align(
            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 6),
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isMe
                    ? (isLight ? const Color(0xFF007AFF) : Colors.blue)
                    : (isLight ? Colors.grey[200]! : Colors.grey[800]!),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(_getFileIcon(fileExtension), color: isMe ? Colors.white : Colors.blue, size: 36),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              fileName,
                              style: TextStyle(
                                color: isMe ? Colors.white : Colors.black87,
                                fontWeight: FontWeight.w500,
                                fontSize: 15.5,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _formatFileSize(fileSize),
                              style: TextStyle(
                                color: isMe ? Colors.white70 : Colors.grey.shade600,
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.download_rounded, size: 28),
                        color: isMe ? Colors.white : Colors.blue,
                        onPressed: () => _downloadFile(msgData),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    time,
                    style: TextStyle(
                      color: isMe ? Colors.white70 : Colors.grey.shade600,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isSelected)
            Positioned(
              top: 16,
              right: isMe ? 16 : null,
              left: isMe ? null : 16,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 20),
              ),
            ),
        ],
      ),
    );
  }

  // ====================== ВСПОМОГАТЕЛЬНЫЕ ======================
  Widget _buildPlaceholder() => Container(
        color: Colors.grey[900],
        child: const Center(child: Icon(Icons.broken_image, size: 60, color: Colors.grey)),
      );

  Widget _buildLoadingPlaceholder() => Container(
        color: Colors.grey[850],
        child: const Center(child: CircularProgressIndicator(color: Colors.white70)),
      );

  IconData _getFileIcon(String extension) {
    switch (extension) {
      case 'pdf': return Icons.picture_as_pdf;
      case 'doc': case 'docx': return Icons.description;
      case 'xls': case 'xlsx': return Icons.table_chart;
      case 'zip': case 'rar': return Icons.folder_zip;
      case 'mp3': case 'wav': return Icons.audiotrack;
      case 'mp4': case 'mov': return Icons.video_library;
      default: return Icons.insert_drive_file;
    }
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
        Fluttertoast.showToast(msg: 'Файл не найден');
        return;
      }

      final file = await FileConverterService.hexToFile(hexData, fileName);

      final downloadsDir = Directory('/storage/emulated/0/Download');
      if (await downloadsDir.exists()) {
        final savedFile = File('${downloadsDir.path}/$fileName');
        await file.copy(savedFile.path);
        Fluttertoast.showToast(msg: 'Сохранено в Загрузки');
      } else {
        Fluttertoast.showToast(msg: 'Файл сохранён');
      }
    } catch (e) {
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
            child: Center(child: InteractiveViewer(child: Image.file(file))),
          ),
        ),
      ),
    );
  }

  // ====================== ОСНОВНОЙ BUILD ======================
  @override
  Widget build(BuildContext context) {
    super.build(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isLight = Theme.of(context).brightness == Brightness.light;

    return Scaffold(
      appBar: _isMultiSelectMode
          ? AppBar(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              leading: IconButton(icon: const Icon(Icons.close), onPressed: _clearSelection),
              title: Text('${_selectedMessageIds.length} выбрано'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () => _deleteSelected(forEveryone: false),
                ),
              ],
            )
          : null,
      body: StreamBuilder<QuerySnapshot>(
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
              final messageId = messages[index].id;
              final isMe = msgData['senderId'] == widget.currentUserId;
              final timestamp = msgData['timestamp'] as Timestamp?;
              final time = timestamp != null ? DateFormat('HH:mm').format(timestamp.toDate()) : '';

              final String type = (msgData['type'] ?? '').toString().toLowerCase();
              final String? fileExt = (msgData['fileExtension'] ?? '').toString().toLowerCase();

              final bool isImage = ['jpg', 'jpeg', 'png', 'gif'].contains(fileExt) || type == 'image';
              final bool isFile = (type == 'file_hex' || type == 'file_storage') || (msgData.containsKey('hexData') && !isImage);
              final bool isDeleted = msgData['isDeleted'] == true;

              if (isDeleted) {
                return Align(
                  alignment: Alignment.center,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text('Сообщение удалено', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
                  ),
                );
              }

              if (isImage) {
                return _buildImageMessage(msgData, isMe, time, isLight);
              }
              if (isFile) {
                return _buildFileMessage(msgData, isMe, time, isLight);
              }

              // Текстовое сообщение
              final messageText = msgData['text'] ?? '';
              final replyToId = msgData['replyToMessageId'] as String?;
              final repliedText = msgData['repliedMessageText'] as String?;
              final isRead = msgData['read'] == true;
              final isEdited = msgData['isEdited'] == true;

              return GestureDetector(
                onLongPress: () => _toggleSelection(messageId),
                child: Dismissible(
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
                    child: CupertinoContextMenu.builder(
                      actions: _buildMessageMenuActions(isMe, messageId, messageText),
                      builder: (BuildContext ctx, Animation<double> animation) {
                        final scale = 1.0 + (animation.value * 0.025);
                        final lift = -5.0 * animation.value;
                        return Transform.translate(
                          offset: Offset(0, lift),
                          child: Transform.scale(
                            scale: scale,
                            child: Material(
                              elevation: 10 * animation.value,
                              shadowColor: Colors.black.withOpacity(0.25),
                              borderRadius: BorderRadius.circular(18),
                              color: Colors.transparent,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(18),
                                child: Container(
                                  constraints: BoxConstraints(maxWidth: screenWidth * 0.78),
                                  margin: const EdgeInsets.symmetric(vertical: 4),
                                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                                  decoration: BoxDecoration(
                                    color: isMe
                                        ? (isLight ? const Color(0xFF007AFF) : Colors.blue)
                                        : (isLight ? CupertinoColors.systemGrey5 : Colors.grey[800]!),
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
                                            color: isLight
                                                ? Colors.black.withValues(alpha: 0.06)
                                                : Colors.black.withValues(alpha: 0.25),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.reply, size: 16, color: Colors.white70),
                                              const SizedBox(width: 6),
                                              Flexible(
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
                                        messageText,
                                        style: TextStyle(
                                          color: isMe ? Colors.white : (isLight ? CupertinoColors.label : Colors.white),
                                          fontSize: 16,
                                        ),
                                      ),
                                      if (isEdited)
                                        Text('изменено', style: TextStyle(color: isMe ? Colors.white60 : Colors.grey, fontSize: 10)),
                                      const SizedBox(height: 4),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(time, style: TextStyle(color: isMe ? Colors.white70 : (isLight ? CupertinoColors.secondaryLabel : Colors.white70), fontSize: 11)),
                                          if (isMe)
                                            Icon(isRead ? Icons.done_all : Icons.done, size: 14, color: Colors.white70),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}