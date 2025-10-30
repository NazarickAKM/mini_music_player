// lib/models/playlist_provider.dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
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

  // **ARTWORK CACHE**: In-memory cache for artwork bytes.
  final Map<int, Uint8List> _artworkCache = {};

  PlaylistProvider(this.audioHandler) {
    loadPlaylist();
    _listenToCurrentSongChangesFromHandler();
  }

  Future<void> loadPlaylist() async {
    final file = await _getPlaylistFile();
    if (await file.exists()) {
      debugPrint("[PROVIDER-LOG] Found saved playlist. Loading from file...");
      try {
        final jsonString = await file.readAsString();
        final List<dynamic> jsonList = jsonDecode(jsonString);
        _playlist = jsonList.map((json) => Song.fromJson(json)).toList();
      } catch (e) {
        debugPrint("[PROVIDER-LOG] Error loading playlist: $e. Rescanning.");
        await rescanSongs();
        return;
      }
    } else {
      debugPrint(
        "[PROVIDER-LOG] No saved playlist found. Scanning for songs...",
      );
      await rescanSongs();
      return;
    }

    if (_playlist.isNotEmpty) {
      await _updateAudioHandlerWithPlaylist();
    }
    notifyListeners();
  }

  Future<void> rescanSongs() async {
    debugPrint("[PROVIDER-LOG] Rescanning songs from device storage...");
    await _scanAndSaveSongs();
    if (_playlist.isNotEmpty) {
      await _updateAudioHandlerWithPlaylist();
    }
    notifyListeners();
  }

  Future<void> _scanAndSaveSongs() async {
    // Request permission if not granted
    if (!await _audioQuery.permissionsStatus()) {
      await _audioQuery.permissionsRequest();
    }

    // Query for songs
    List<SongModel> songsFromQuery = await _audioQuery.querySongs(
      sortType: SongSortType.TITLE,
      orderType: OrderType.ASC_OR_SMALLER,
      uriType: UriType.EXTERNAL,
      ignoreCase: true,
    );


    const minDuration = 60 * 1000;
    songsFromQuery = songsFromQuery
        .where((song) => (song.duration ?? 0) > minDuration)
        .toList();

    // Preserve favorite status during rescan.
    final favoriteSongIds =
    _playlist.where((s) => s.isFavorite).map((s) => s.id).toSet();
    if (favoriteSongIds.isNotEmpty) {
      debugPrint(
        "[PROVIDER-LOG] Preserving ${favoriteSongIds.length} favorite songs during rescan.",
      );
    }

    _playlist = songsFromQuery.map((songModel) {
      return Song(
        id: songModel.id,
        songName: songModel.title.isNotEmpty
            ? songModel.title
            : songModel.displayNameWOExt,
        artistName: songModel.artist ?? "Unknown Artist",
        audioPath: songModel.data,
        duration: Duration(milliseconds: songModel.duration ?? 0),
        isFavorite: favoriteSongIds.contains(songModel.id),
      );
    }).toList();

    debugPrint("[PROVIDER-LOG] Song scan complete. Found ${_playlist.length} songs.");

    // Save the newly scanned and corrected playlist to the file.
    await _savePlaylistToFile();
  }

  // **NEW METHOD**: Fetches and caches artwork on demand.
  Future<Uint8List?> getArtwork(int songId) async {
    // If artwork is already in cache, return it.
    if (_artworkCache.containsKey(songId)) {
      return _artworkCache[songId];
    }

    // Otherwise, fetch it, cache it, and then return it.
    final artwork = await _audioQuery.queryArtwork(
      songId,
      ArtworkType.AUDIO,
      size: 800,
    );
    if (artwork != null) {
      _artworkCache[songId] = artwork;
    }
    return artwork;
  }

  // **NEW METHOD**: Toggles the favorite status of a song.
  Future<void> toggleFavorite(int songId) async {
    final songIndex = _playlist.indexWhere((s) => s.id == songId);
    if (songIndex != -1) {
      // Toggle the favorite status.
      _playlist[songIndex].isFavorite = !_playlist[songIndex].isFavorite;
      debugPrint(
        "[PROVIDER-LOG] Toggled favorite for song ID $songId. New status: ${_playlist[songIndex].isFavorite}",
      );

      // Persist the change to the playlist file.
      await _savePlaylistToFile();

      // Notify listeners to update the UI.
      notifyListeners();
    } else {
      debugPrint(
        "[PROVIDER-LOG] ERROR: Could not find song with ID $songId to toggle favorite status.",
      );
    }
  }

  Future<void> _updateAudioHandlerWithPlaylist() async {
    if (_playlist.isEmpty) return;

    final mediaItems = _playlist
        .map(
          (song) => MediaItem(
        id: song.id.toString(),
        title: song.songName,
        artist: song.artistName,
        duration: song.duration,
        extras: {'url': song.audioPath},
      ),
    )
        .toList();
    await audioHandler.updateQueue(mediaItems);
  }

  Future<File> _getPlaylistFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/playlist.json');
  }

  Future<void> _savePlaylistToFile() async {
    final file = await _getPlaylistFile();
    final jsonList = _playlist.map((s) => s.toJson()).toList();
    await file.writeAsString(jsonEncode(jsonList));
  }

  void _listenToCurrentSongChangesFromHandler() {
    audioHandler.mediaItem.listen((mediaItem) {
      if (mediaItem == null) return;
      final index = _playlist.indexWhere(
            (s) => s.id.toString() == mediaItem.id,
      );
      if (index != -1 && _currentSongIndex != index) {
        _currentSongIndex = index;
        notifyListeners();
      }
    });
  }

  void togglePlayPause() {
    final isPlaying = audioHandler.playbackState.value.playing;
    isPlaying ? audioHandler.pause() : audioHandler.play();
  }

  List<Song> get playlist => _playlist;

  // **NEW GETTER**: Returns a list of only the favorite songs.
  List<Song> get favorites => _playlist.where((s) => s.isFavorite).toList();

  int? get currentSongIndex => _currentSongIndex;

  Song? get currentSong => (_currentSongIndex != null && _playlist.isNotEmpty)
      ? _playlist[_currentSongIndex!]
      : null;

  set currentSongIndex(int? newIndex) {
    if (newIndex != null && newIndex >= 0 && newIndex < _playlist.length) {
      _currentSongIndex = newIndex;
      audioHandler.skipToQueueItem(newIndex);
      notifyListeners();
    }
  }
}
