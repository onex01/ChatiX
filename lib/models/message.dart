import 'package:cloud_firestore/cloud_firestore.dart';

class Message {
  final String id;
  final String senderId;
  final String text;
  final Timestamp timestamp;
  final bool isRead;
   final String? replyToMessageId;
   final String? repliedMessageText;
  final bool isEdited;
  final Timestamp? editedAt;
  final bool isDeleted;
  final String type;                    // ← НОВОЕ: text / image_hex / file_hex

  Message({
    required this.id,
    required this.senderId,
    required this.text,
    required this.timestamp,
    this.isRead = false,
    this.replyToMessageId,
    this.repliedMessageText,
    this.isEdited = false,
    this.editedAt,
    this.isDeleted = false,
    this.type = 'text',
  });

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'text': text,
      'timestamp': timestamp,
      'isRead': isRead,
      'replyToMessageId': replyToMessageId,
      'repliedMessageText': repliedMessageText,
      'isEdited': isEdited,
      'editedAt': editedAt,
      'isDeleted': isDeleted,
      'type': type,
    };
  }

  factory Message.fromMap(String id, Map<String, dynamic> map) {
    return Message(
      id: id,
      senderId: map['senderId'],
      text: map['text'] ?? '',
      timestamp: map['timestamp'] ?? Timestamp.now(),
      isRead: map['isRead'] ?? false,
      replyToMessageId: map['replyToMessageId'],
      repliedMessageText: map['repliedMessageText'],
      isEdited: map['isEdited'] ?? false,
      editedAt: map['editedAt'],
      isDeleted: map['isDeleted'] ?? false,
      type: map['type'] ?? 'text',
    );
  }
}