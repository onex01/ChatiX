import 'message.dart';

class Chat {
  final String chatId;
  final String otherUserId;
  final String otherUserNickname;
  final String? otherUserPhotoUrl;
  final Message? lastMessage;
  final DateTime lastMessageTime;

  Chat({
    required this.chatId,
    required this.otherUserId,
    required this.otherUserNickname,
    this.otherUserPhotoUrl,
    this.lastMessage,
    required this.lastMessageTime,
  });
}