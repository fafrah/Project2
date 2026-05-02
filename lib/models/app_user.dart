import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String uid;
  final String email;
  final String username;
  final String? displayName;
  final String? photoUrl;
  final DateTime createdAt;
  final String? currentSessionId;
  final bool spotifyConnected;

  AppUser({
    required this.uid,
    required this.email,
    required this.username,
    this.displayName,
    this.photoUrl,
    required this.createdAt,
    this.currentSessionId,
    this.spotifyConnected = false,
  });

  factory AppUser.fromMap(String uid, Map<String, dynamic> map) {
    return AppUser(
      uid: uid,
      email: map['email'] as String? ?? '',
      username: map['username'] as String? ?? '',
      displayName: map['displayName'] as String?,
      photoUrl: map['photoUrl'] as String?,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      currentSessionId: map['currentSessionId'] as String?,
      spotifyConnected: map['spotifyConnected'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'username': username,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'currentSessionId': currentSessionId,
    };
  }
}
