import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
 
class PresenceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
 
  Future<void> initPresence() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final userRef = _firestore.collection('users').doc(user.uid);
    await userRef.update({
      'isOnline': true,
      'lastSeen': FieldValue.serverTimestamp(),
    });
  }

  Future<void> goOffline() async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _firestore.collection('users').doc(user.uid).update({
      'isOnline': false,
      'lastSeen': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateTypingStatus(String chatId, bool isTyping) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _firestore.collection('chats').doc(chatId).update({
      'typingUsers': isTyping ? FieldValue.arrayUnion([user.uid]) : FieldValue.arrayRemove([user.uid])
    });
  }

  Future<void> joinChat(String chatId) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _firestore.collection('chats').doc(chatId).update({
      'onlineUsers': FieldValue.arrayUnion([user.uid]),
      'lastSeen': FieldValue.serverTimestamp(),
    });
  }

  Future<void> leaveChat(String chatId) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _firestore.collection('chats').doc(chatId).update({
      'onlineUsers': FieldValue.arrayRemove([user.uid]),
      'lastSeen': FieldValue.serverTimestamp(),
    });
  }
}