// lib/models/playlist_provider.dart

import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:mini_music_player/models/song.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:path_provider/path_provider.dart';

class PlaylistProvider extends ChangeNotifier {
  final AudioHandler audioHandler;
  final OnAudioQuery _audioQuery = OnAudioQuery();
  List<Song> _playlist = [];
  int? _currentSongIndex;

  PlaylistProvider(this.audioHandler) {
    _listenToCurrentSong();
  }

  // **START OF DEFINITIVE FIX: Update local playlist from the handler's stream**
  void _listenToCurrentSong() {
    audioHandler.mediaItem.listen((mediaItem) {
      if (mediaItem == null) {
        _currentSongIndex = null;
        notifyListeners();
        return;
      }

      // Find the index of the song in our local playlist.
      final songIndex =
      _playlist.indexWhere((s) => s.audioPath == mediaItem.extras!['url']);

      if (songIndex != -1) {
        // Update the current song index.
        _currentSongIndex = songIndex;

        // **CRITICAL:** Check if the duration has been updated by the handler.
        final oldSong = _playlist[songIndex];
        if (oldSong.duration != mediaItem.duration) {
          // Create a new song instance with the updated duration.
          _playlist[songIndex] = oldSong.copyWith(duration: mediaItem.duration);
        }
      }

      // Notify listeners of all changes.
      notifyListeners();
    });
  }
  // **END OF DEFINITIVE FIX**

  void togglePlayPause() {
    final isPlaying = audioHandler.playbackState.value.playing;
    if (isPlaying) {
      audioHandler.pause();
    } else {
      audioHandler.play();
    }
  }

  List<Song> get playlist => _playlist;
  int? get currentSongIndex => _currentSongIndex;
  Song? get currentSong {
    if (_currentSongIndex == null || _currentSongIndex! >= _playlist.length) {
      return null;
    }
    return _playlist[_currentSongIndex!];
  }

  set currentSongIndex(int? newIndex) {
    if (newIndex != null && newIndex >= 0 && newIndex < _playlist.length) {
      _currentSongIndex = newIndex;
      audioHandler.skipToQueueItem(newIndex);
    }
    notifyListeners();
  }

  Future<void> pickAndAddSongs() async {
    const minDuration = 60 * 1000;
    const maxDuration = 10 * 60 * 1000;

    if (!await _audioQuery.permissionsStatus()) {
      await _audioQuery.permissionsRequest();
    }

    List<SongModel> songs = await _audioQuery.querySongs(
      sortType: SongSortType.TITLE,
      orderType: OrderType.ASC_OR_SMALLER,
      uriType: UriType.EXTERNAL,
      ignoreCase: true,
    );

    songs = songs.where((song) {
      final duration = song.duration ?? 0;
      return duration > minDuration && duration < maxDuration;
    }).toList();

    _playlist = [];
    List<MediaItem> mediaItems = [];
    final tempDir = await getTemporaryDirectory();

    for (var song in songs) {
      final artwork = await _queryArtwork(song.id);
      final audioUri = Uri.file(song.data);
      Uri? artUri;

      if (artwork != null) {
        final artFile = File('${tempDir.path}/art_${song.id}.jpg');
        await artFile.writeAsBytes(artwork);
        artUri = Uri.file(artFile.path);
      }

      final songObject = Song(
        songName: song.title.isNotEmpty ? song.title : song.displayNameWOExt,
        artistName: song.artist ?? "Unknown Artist",
        albumArt: artwork,
        audioPath: audioUri.toString(),
        // Duration is correctly left null here.
      );
      _playlist.add(songObject);

      final mediaItem = MediaItem(
        id: song.id.toString(),
        title: song.title.isNotEmpty ? song.title : song.displayNameWOExt,
        artist: song.artist ?? "Unknown Artist",
        artUri: artUri,
        // Duration is correctly left null here.
        extras: {'url': audioUri.toString(), 'song': songObject},
      );
      mediaItems.add(mediaItem);
    }

    await audioHandler.updateQueue(mediaItems);
    notifyListeners();
  }

  Future<Uint8List?> _queryArtwork(int songId) async {
    return _audioQuery.queryArtwork(songId, ArtworkType.AUDIO,
        format: ArtworkFormat.JPEG, quality: 100, size: 500);
  }
}
