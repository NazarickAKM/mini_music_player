// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'song.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Song _$SongFromJson(Map<String, dynamic> json) => Song(
  id: (json['id'] as num).toInt(),
  songName: json['songName'] as String,
  artistName: json['artistName'] as String,
  audioPath: json['audioPath'] as String,
  duration: Duration(microseconds: (json['duration'] as num).toInt()),
);

Map<String, dynamic> _$SongToJson(Song instance) => <String, dynamic>{
  'id': instance.id,
  'songName': instance.songName,
  'artistName': instance.artistName,
  'audioPath': instance.audioPath,
  'duration': instance.duration.inMicroseconds,
};
