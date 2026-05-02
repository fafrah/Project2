import 'package:cloud_firestore/cloud_firestore.dart';

class Vote {
  final String uid;
  final int value;
  final DateTime votedAt;

  Vote({required this.uid, required this.value, required this.votedAt});

  factory Vote.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data() ?? {};
    return Vote(
      uid: doc.id,
      value: m['value'] as int? ?? 0,
      votedAt: (m['votedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {'value': value, 'votedAt': Timestamp.fromDate(votedAt)};
  }
}
