class Track {
  final String id;
  final String name;
  final String artist;
  final String? albumArt;
  final String? previewUrl;
  final int durationMs;

  Track({
    required this.id,
    required this.name,
    required this.artist,
    this.albumArt,
    this.previewUrl,
    required this.durationMs,
  });

  factory Track.fromMap(Map<String, dynamic> m) {
    return Track(
      id: m['id'] as String? ?? '',
      name: m['name'] as String? ?? '',
      artist: m['artist'] as String? ?? '',
      albumArt: m['albumArt'] as String?,
      previewUrl: m['previewUrl'] as String?,
      durationMs: m['durationMs'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'artist': artist,
      'albumArt': albumArt,
      'previewUrl': previewUrl,
      'durationMs': durationMs,
    };
  }
}
