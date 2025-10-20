import 'dart:typed_data';

class Song {
  final String songName;
  final String artistName;
  final Uint8List? albumArt;
  final String audioPath;
  final Duration? duration;

  Song({
    required this.songName,
    required this.artistName,
    required this.albumArt,
    required this.audioPath,
    this.duration,
  });

  // **DEFINITIVE FIX START:** Add a copyWith method.
  /// Creates a new Song instance with updated values.
  Song copyWith({
    String? songName,
    String? artistName,
    Uint8List? albumArt,
    String? audioPath,
    Duration? duration,
  }) {
    return Song(
      songName: songName ?? this.songName,
      artistName: artistName ?? this.artistName,
      albumArt: albumArt ?? this.albumArt,
      audioPath: audioPath ?? this.audioPath,
      duration: duration ?? this.duration,
    );
  }
// **DEFINITIVE FIX END**
}
