import 'package:cloud_firestore/cloud_firestore.dart';

class Session {
  final String id;
  final String hostUid;
  final String name;
  final String joinCode;
  final DateTime createdAt;
  final bool isActive;
  final NowPlaying? currentTrack;
  final int memberCount;

  Session({
    required this.id,
    required this.hostUid,
    required this.name,
    required this.joinCode,
    required this.createdAt,
    required this.isActive,
    this.currentTrack,
    required this.memberCount,
  });

  factory Session.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data() ?? {};
    return Session(
      id: doc.id,
      hostUid: m['hostUid'] as String? ?? '',
      name: m['name'] as String? ?? '',
      joinCode: m['joinCode'] as String? ?? '',
      createdAt: (m['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isActive: m['isActive'] as bool? ?? true,
      currentTrack: m['currentTrack'] == null
          ? null
          : NowPlaying.fromMap(m['currentTrack'] as Map<String, dynamic>),
      memberCount: m['memberCount'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'hostUid': hostUid,
      'name': name,
      'joinCode': joinCode,
      'createdAt': Timestamp.fromDate(createdAt),
      'isActive': isActive,
      'currentTrack': currentTrack?.toMap(),
      'memberCount': memberCount,
    };
  }
}

class NowPlaying {
  final String trackId;
  final String trackName;
  final String artist;
  final String? albumArt;
  final DateTime startedAt;
  final int durationMs;
  final String addedBy;

  NowPlaying({
    required this.trackId,
    required this.trackName,
    required this.artist,
    this.albumArt,
    required this.startedAt,
    required this.durationMs,
    required this.addedBy,
  });

  factory NowPlaying.fromMap(Map<String, dynamic> m) {
    return NowPlaying(
      trackId: m['trackId'] as String? ?? '',
      trackName: m['trackName'] as String? ?? '',
      artist: m['artist'] as String? ?? '',
      albumArt: m['albumArt'] as String?,
      startedAt: (m['startedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      durationMs: m['durationMs'] as int? ?? 0,
      addedBy: m['addedBy'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'trackId': trackId,
      'trackName': trackName,
      'artist': artist,
      'albumArt': albumArt,
      'startedAt': Timestamp.fromDate(startedAt),
      'durationMs': durationMs,
      'addedBy': addedBy,
    };
  }

  /// Milliseconds elapsed since playback started (clock-derived, no
  /// audio engine yet).
  int elapsedMs() {
    return DateTime.now().difference(startedAt).inMilliseconds.clamp(
      0,
      durationMs,
    );
  }

  bool get isFinished => elapsedMs() >= durationMs;
}
