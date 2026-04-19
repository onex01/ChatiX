import 'package:Rizz/core/logger/app_logger.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
 
abstract class FirestoreService {
  Future<DocumentSnapshot> getUser(String uid);
  Future<void> updateUser(String uid, Map<String, dynamic> updates);
  Stream<QuerySnapshot> getChats(String userId);
  Future<void> updateChat(String chatId, Map<String, dynamic> updates);
  Future<bool> isUsernameAvailable(String username);
}

class FirestoreServiceImpl implements FirestoreService {
  final FirebaseFirestore _firestore;
  FirestoreServiceImpl(this._firestore, AppLogger appLogger);

  @override
  Future<DocumentSnapshot> getUser(String uid) => _firestore.collection('users').doc(uid).get();

  @override
  Future<void> updateUser(String uid, Map<String, dynamic> data) =>
      _firestore.collection('users').doc(uid).update(data);

  @override
  Stream<QuerySnapshot> getChats(String userId) => _firestore
      .collection('chats')
      .where('participants', arrayContains: userId)
      .orderBy('lastMessageTime', descending: true)
      .snapshots();
 
  Future<DocumentReference> createChat(Map<String, dynamic> data) =>
      _firestore.collection('chats').add(data);

  @override
  Future<void> updateChat(String chatId, Map<String, dynamic> data) =>
      _firestore.collection('chats').doc(chatId).update(data);
 
  Future<void> addMessage(String chatId, Map<String, dynamic> messageData) =>
      _firestore.collection('chats').doc(chatId).collection('messages').add(messageData);

  @override
  Future<bool> isUsernameAvailable(String username) async {
    final snapshot = await _firestore
        .collection('users')
        .where('username', isEqualTo: username)
        .limit(1)
        .get();
    return snapshot.docs.isEmpty;
  }
}