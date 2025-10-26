// lib/models/song.dart
import 'package:json_annotation/json_annotation.dart';
part 'song.g.dart';

@JsonSerializable()
class Song {
  // Use the audio query's ID as the true unique identifier.
  final int id;
  final String songName;
  final String artistName;
  final String audioPath;
  final Duration duration;

  Song({
    required this.id,
    required this.songName,
    required this.artistName,
    required this.audioPath,
    required this.duration,
  });

  // No more copyWith or albumArt field needed here.

  factory Song.fromJson(Map<String, dynamic> json) => _$SongFromJson(json);
  Map<String, dynamic> toJson() => _$SongToJson(this);
}
