import 'package:cloud_firestore/cloud_firestore.dart';

class QueueItem {
  final String id;
  final String trackId;
  final String trackName;
  final String artist;
  final String? albumArt;
  final String? previewUrl;
  final int durationMs;
  final String addedBy;
  final DateTime addedAt;
  final int voteScore;
  final List<String> tags;

  QueueItem({
    required this.id,
    required this.trackId,
    required this.trackName,
    required this.artist,
    this.albumArt,
    this.previewUrl,
    required this.durationMs,
    required this.addedBy,
    required this.addedAt,
    required this.voteScore,
    required this.tags,
  });

  factory QueueItem.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data() ?? {};
    return QueueItem(
      id: doc.id,
      trackId: m['trackId'] as String? ?? '',
      trackName: m['trackName'] as String? ?? '',
      artist: m['artist'] as String? ?? '',
      albumArt: m['albumArt'] as String?,
      previewUrl: m['previewUrl'] as String?,
      durationMs: m['durationMs'] as int? ?? 0,
      addedBy: m['addedBy'] as String? ?? '',
      addedAt: (m['addedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      voteScore: m['voteScore'] as int? ?? 0,
      tags: List<String>.from(m['tags'] as List? ?? const []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'trackId': trackId,
      'trackName': trackName,
      'artist': artist,
      'albumArt': albumArt,
      'previewUrl': previewUrl,
      'durationMs': durationMs,
      'addedBy': addedBy,
      'addedAt': Timestamp.fromDate(addedAt),
      'voteScore': voteScore,
      'tags': tags,
    };
  }
}
