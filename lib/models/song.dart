// lib/models/song.dart
import 'package:flutter/foundation.dart';

class Song {
  final int id;
  final String songName;
  final String artistName;
  final String audioPath;
  final Duration duration;
  bool isFavorite; // Add this line

  Song({
    required this.id,
    required this.songName,
    required this.artistName,
    required this.audioPath,
    required this.duration,
    this.isFavorite = false, // Initialize as false
  });

  // Since we are adding a new field, we need to update fromJson and toJson
  factory Song.fromJson(Map<String, dynamic> json) {
    return Song(
      id: json['id'],
      songName: json['songName'],
      artistName: json['artistName'],
      audioPath: json['audioPath'],
      duration: Duration(milliseconds: json['duration']),
      // Load favorite status, default to false if not present
      isFavorite: json['isFavorite'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'songName': songName,
      'artistName': artistName,
      'audioPath': audioPath,
      'duration': duration.inMilliseconds,
      'isFavorite': isFavorite, // Save favorite status
    };
  }

  @override
  String toString() {
    return 'Song{id: $id, name: "$songName", isFavorite: $isFavorite}';
  }
}
