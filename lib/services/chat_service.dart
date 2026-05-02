import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessage {
  final String id;
  final String uid;
  final String username;
  final String text;
  final DateTime sentAt;

  ChatMessage({
    required this.id,
    required this.uid,
    required this.username,
    required this.text,
    required this.sentAt,
  });

  factory ChatMessage.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data() ?? {};
    return ChatMessage(
      id: doc.id,
      uid: m['uid'] as String? ?? '',
      username: m['username'] as String? ?? '',
      text: m['text'] as String? ?? '',
      sentAt: (m['sentAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

class ChatService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _ref(String sessionId) =>
      _db.collection('sessions').doc(sessionId).collection('messages');

  Future<void> sendMessage({
    required String sessionId,
    required String uid,
    required String username,
    required String text,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    await _ref(sessionId).add({
      'uid': uid,
      'username': username,
      'text': trimmed,
      'sentAt': Timestamp.now(),
    });
  }

  Stream<List<ChatMessage>> streamMessages(String sessionId) {
    return _ref(sessionId)
        .orderBy('sentAt', descending: true)
        .limit(100)
        .snapshots()
        .map((qs) => qs.docs.map(ChatMessage.fromDoc).toList());
  }
}
