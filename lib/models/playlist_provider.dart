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

  // **NEW**: Set to store the file paths of songs that should be excluded.
  Set<String> _excludedSongPaths = {};

  PlaylistProvider(this.audioHandler) {
    loadPlaylist();
    _listenToCurrentSongChangesFromHandler();
  }

  Future<void> loadPlaylist() async {
    // **NEW**: Load the exclusion list first.
    await _loadExcludedSongs();
    final file = await _getPlaylistFile();
    if (await file.exists()) {
      debugPrint("[PROVIDER-LOG] Found saved playlist. Loading from file...");
      try {
        final jsonString = await file.readAsString();
        final List<dynamic> jsonList = jsonDecode(jsonString);
        _playlist = jsonList.map((json) => Song.fromJson(json)).toList();

        // **MODIFIED**: After loading, ensure no excluded songs are in the playlist.
        // This handles cases where a song was excluded while the app was closed.
        final initialCount = _playlist.length;
        _playlist.removeWhere((song) => _excludedSongPaths.contains(song.audioPath));
        if (initialCount != _playlist.length) {
          debugPrint("[PROVIDER-LOG] Removed ${initialCount - _playlist.length} excluded songs from loaded playlist.");
          // If songs were removed, save the cleaned playlist.
          await _savePlaylistToFile();
        }

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

    // **NEW**: Define duration limits for filtering.
    const minDurationMs = 60 * 1000; // 1 minute in milliseconds
    const maxDurationMs = 10 * 60 * 1000; // 10 minutes in milliseconds

    // **MODIFIED**: Apply the duration filter to the queried songs.
    // This creates a new list containing only the songs that meet the criteria.
    final int totalSongsBeforeFilter = songsFromQuery.length;
    songsFromQuery = songsFromQuery.where((song) {
      final duration = song.duration ?? 0;
      final bool passesFilter = duration >= minDurationMs && duration <= maxDurationMs;
      if (!passesFilter) {
        debugPrint(
            "[FILTER-LOG] Excluding song: \"${song.title}\" (Duration: ${duration / 1000}s)");
      }
      return passesFilter;
    }).toList();

    debugPrint(
        "[FILTER-LOG] Filtered out ${totalSongsBeforeFilter - songsFromQuery.length} songs based on duration.");

    // Preserve favorite status during rescan.
    final favoriteSongIds =
    _playlist.where((s) => s.isFavorite).map((s) => s.id).toSet();
    if (favoriteSongIds.isNotEmpty) {
      debugPrint(
        "[PROVIDER-LOG] Preserving ${favoriteSongIds.length} favorite songs during rescan.",
      );
    }

    _playlist = songsFromQuery
    // **NEW**: Filter out songs that are in the exclusion list.
        .where((songModel) => !_excludedSongPaths.contains(songModel.data))
        .map((songModel) {
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

    debugPrint("[PROVIDER-LOG] Song scan complete. Found ${_playlist.length} songs that meet the criteria.");

    // Save the newly scanned and corrected playlist to the file.
    await _savePlaylistToFile();
  }

  // **NEW METHOD**: Removes selected songs from the playlist and adds them to the exclusion list.
  Future<void> removeSongs(Set<Song> songsToRemove) async {
    if (songsToRemove.isEmpty) {
      debugPrint("[PROVIDER-LOG] removeSongs called with no songs to remove.");
      return;
    }

    final pathsToRemove = songsToRemove.map((song) => song.audioPath).toSet();

    // Add paths to the exclusion set and save it.
    _excludedSongPaths.addAll(pathsToRemove);
    await _saveExcludedSongs();
    debugPrint("[PROVIDER-LOG] Added ${pathsToRemove.length} songs to exclusion list.");

    // Remove songs from the current playlist.
    _playlist.removeWhere((song) => pathsToRemove.contains(song.audioPath));

    // If the currently playing song was removed, stop playback.
    final currentSong = this.currentSong;
    if (currentSong != null && pathsToRemove.contains(currentSong.audioPath)) {
      await audioHandler.stop();
      _currentSongIndex = null;
      debugPrint("[PROVIDER-LOG] Current playing song was removed. Stopping playback.");
    }

    // Update the audio handler's queue with the modified playlist.
    await _updateAudioHandlerWithPlaylist();

    // Save the modified playlist.
    await _savePlaylistToFile();

    // Notify listeners to update the UI.
    notifyListeners();
  }

  // **NEW METHOD**: Gets the file used for storing excluded song paths.
  Future<File> _getExcludedSongsFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/excluded_songs.json');
  }

  // **NEW METHOD**: Saves the current set of excluded paths to a file.
  Future<void> _saveExcludedSongs() async {
    try {
      final file = await _getExcludedSongsFile();
      // Convert the Set to a List for JSON encoding.
      final jsonString = jsonEncode(_excludedSongPaths.toList());
      await file.writeAsString(jsonString);
    } catch (e) {
      debugPrint("[PROVIDER-LOG] CRITICAL: Failed to save excluded songs file: $e");
    }
  }

  // **NEW METHOD**: Loads the excluded paths from the file into memory.
  Future<void> _loadExcludedSongs() async {
    try {
      final file = await _getExcludedSongsFile();
      if (await file.exists()) {
        final jsonString = await file.readAsString();
        final List<dynamic> pathList = jsonDecode(jsonString);
        _excludedSongPaths = Set<String>.from(pathList);
        debugPrint("[PROVIDER-LOG] Loaded ${_excludedSongPaths.length} excluded song paths.");
      } else {
        debugPrint("[PROVIDER-LOG] No excluded songs file found. Starting with an empty list.");
      }
    } catch (e) {
      debugPrint("[PROVIDER-LOG] ERROR: Could not load excluded songs file: $e");
      // Start with an empty set in case of error.
      _excludedSongPaths = {};
    }
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
    if (_playlist.isEmpty) {
      // **MODIFIED**: If the playlist becomes empty, clear the handler's queue.
      await audioHandler.updateQueue([]);
      debugPrint("[PROVIDER-LOG] Playlist is empty, cleared audio handler queue.");
      return;
    }

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
      if (mediaItem == null) {
        // **MODIFIED**: If mediaItem becomes null (e.g., after queue is cleared), reset index.
        if (_currentSongIndex != null) {
          _currentSongIndex = null;
          notifyListeners();
        }
        return;
      }
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

  Song? get currentSong => (_currentSongIndex != null && _playlist.isNotEmpty && _currentSongIndex! < _playlist.length)
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
