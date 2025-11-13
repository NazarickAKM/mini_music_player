// lib/pages/home_page.dart

import 'dart:typed_data';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:mini_music_player/components/my_drawer.dart';
import 'package:mini_music_player/models/playlist_provider.dart';
import 'package:mini_music_player/models/song.dart';
import 'package:mini_music_player/pages/song_page.dart';
import 'package:provider/provider.dart';
import '../components/album_art_image.dart';

// FIX: Re-adding the main StatefulWidget class definition.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final PlaylistProvider playlistProvider;
  // **NEW**: State variables for managing multi-select and deletion.
  bool _isSelectionMode = false;
  final Set<Song> _selectedSongs = {};

  @override
  void initState() {
    super.initState();
    // The PlaylistProvider now handles its own loading logic in its constructor.
    // So, we no longer need to call a method here.
    // The provider will either load from the file or scan automatically.
    playlistProvider = Provider.of<PlaylistProvider>(context, listen: false);
  }

  // Plays a new song and navigates to the song page.
  void goToSong(int songIndex) {
    playlistProvider.currentSongIndex = songIndex;
    navigateToSongPage();
  }

  // Navigates to the currently playing song page without restarting it.
  void navigateToSongPage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SongPage()),
    );
  }

  // **NEW METHOD**: Toggles the selection of a single song.
  void _toggleSelection(Song song) {
    setState(() {
      if (_selectedSongs.contains(song)) {
        _selectedSongs.remove(song);
        // If the last item is deselected, exit selection mode.
        if (_selectedSongs.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedSongs.add(song);
      }
    });
  }

  // **NEW METHOD**: Exits selection mode and clears the selection.
  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedSongs.clear();
    });
  }

  // **NEW METHOD**: Shows a confirmation dialog and then removes songs.
  void _confirmAndRemoveSongs() {
    // Show a confirmation dialog before deleting.
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Remove Songs"),
        content: Text("Are you sure you want to permanently remove ${_selectedSongs.length} selected song(s)? They won't be scanned again."),
        actions: [
          // Cancel button
          TextButton(
            child: const Text("Cancel"),
            onPressed: () => Navigator.of(context).pop(),
          ),
          // Confirm button
          TextButton(
            child: const Text("Remove"),
            onPressed: () {
              // Use context.read in a callback
              context.read<PlaylistProvider>().removeSongs(_selectedSongs);
              _exitSelectionMode(); // Exit selection mode after removal
              Navigator.of(context).pop(); // Close the dialog
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      // **MODIFIED**: The AppBar is now dynamic based on selection mode.
      appBar: _isSelectionMode
          ? AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _exitSelectionMode, // Button to cancel selection.
        ),
        title: Text("${_selectedSongs.length} selected"),
        actions: [
          // Delete button appears when items are selected.
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _selectedSongs.isNotEmpty
                ? _confirmAndRemoveSongs
                : null, // Disable button if nothing is selected.
          ),
        ],
      )
          : AppBar(
        title: const Text("P L A Y L I S T"),
        centerTitle: true,
      ),
      drawer: _isSelectionMode ? null : const MyDrawer(), // Hide drawer in selection mode.
      body: Consumer<PlaylistProvider>(
        builder: (context, value, child) {
          final List<Song> playlist = value.playlist;

          if (playlist.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_isSelectionMode) // This case can happen if all songs are deleted
                    const Text('No songs to select.')
                  else ...[
                    const CircularProgressIndicator(),
                    const SizedBox(height: 10),
                    const Text('Loading Songs...'),
                  ]
                ],
              ),
            );
          }

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  itemCount: playlist.length,
                  itemBuilder: (context, index) {
                    final Song song = playlist[index];
                    final bool isSelected = _selectedSongs.contains(song);

                    return ListTile(
                      title: Text(song.songName),
                      subtitle: Text(song.artistName),
                      leading: GestureDetector(
                        // **MODIFIED**: Add long press to start selection mode.
                        onLongPress: () {
                          if (!_isSelectionMode) {
                            setState(() {
                              _isSelectionMode = true;
                              _toggleSelection(song);
                            });
                          }
                        },
                        // **MODIFIED**: Tap behavior changes based on selection mode.
                        onTap: () {
                          if (_isSelectionMode) {
                            _toggleSelection(song);
                          }
                          // In normal mode, this tap is ignored, letting the ListTile's onTap handle it.
                        },
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 50,
                              height: 50,
                              child: FutureBuilder<Uint8List?>(
                                future: value.getArtwork(song.id),
                                builder: (context, snapshot) {
                                  return AlbumArtImage(
                                    albumArt: snapshot.data,
                                    size: 50,
                                  );
                                },
                              ),
                            ),
                            // **NEW**: Show a selection indicator overlay.
                            if (isSelected)
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(4.0),
                                ),
                                child: const Icon(
                                  Icons.check_circle,
                                  color: Colors.white,
                                ),
                              ),
                          ],
                        ),
                      ),
                      onTap: () {
                        // **MODIFIED**: Tap the list tile to either select or play.
                        if (_isSelectionMode) {
                          _toggleSelection(song);
                        } else {
                          // Normal playback behavior.
                          if (value.currentSongIndex != index) {
                            goToSong(index);
                          } else {
                            navigateToSongPage();
                          }
                        }
                      },
                      // **NEW**: Change tile color when selected.
                      tileColor: isSelected
                          ? Theme.of(context).colorScheme.primary.withOpacity(0.2)
                          : null,
                    );
                  },
                ),
              ),

              // MINI PLAYER
              // **MODIFIED**: Hide the mini player when in selection mode.
              if (!_isSelectionMode)
                StreamBuilder<MediaItem?>(
                    stream: value.audioHandler.mediaItem,
                    builder: (context, mediaItemSnapshot) {
                      final mediaItem = mediaItemSnapshot.data;
                      if (mediaItem == null) {
                        return const SizedBox.shrink();
                      }

                      final currentSong = value.currentSong;

                      return StreamBuilder<PlaybackState>(
                        stream: value.audioHandler.playbackState,
                        builder: (context, playbackStateSnapshot) {
                          final playbackState = playbackStateSnapshot.data;
                          final isPlaying = playbackState?.playing ?? false;
                          final position =
                              playbackState?.updatePosition ?? Duration.zero;
                          final duration =
                              mediaItem.duration ?? const Duration(milliseconds: 1);

                          return GestureDetector(
                            onTap: navigateToSongPage,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.secondary,
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(20),
                                  topRight: Radius.circular(20),
                                ),
                              ),
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16.0),
                                    child: SliderTheme(
                                      data: SliderTheme.of(context).copyWith(
                                        thumbShape: const RoundSliderThumbShape(
                                            enabledThumbRadius: 0),
                                        overlayShape:
                                        const RoundSliderOverlayShape(
                                            overlayRadius: 0),
                                        trackHeight: 2,
                                      ),
                                      child: Slider(
                                        value: position.inMilliseconds
                                            .toDouble()
                                            .clamp(
                                            0.0,
                                            duration.inMilliseconds
                                                .toDouble()),
                                        min: 0.0,
                                        max: duration.inMilliseconds.toDouble(),
                                        onChanged: (sliderValue) {
                                          value.audioHandler.seek(Duration(
                                              milliseconds:
                                              sliderValue.round()));
                                        },
                                        activeColor:
                                        Theme.of(context).colorScheme.primary,
                                        inactiveColor: Theme.of(context)
                                            .colorScheme
                                            .primary
                                            .withAlpha(75),
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                        16.0, 0, 16.0, 8.0),
                                    child: Row(
                                      mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Row(
                                            children: [
                                              if (currentSong != null)
                                                ClipRRect(
                                                  borderRadius: BorderRadius.circular(4),
                                                  child: FutureBuilder<Uint8List?>(
                                                    future: value.getArtwork(currentSong.id),
                                                    builder: (context, snapshot) {
                                                      return AlbumArtImage(
                                                        albumArt: snapshot.data,
                                                        size: 40,
                                                      );
                                                    },
                                                  ),
                                                ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                                  mainAxisSize:
                                                  MainAxisSize.min,
                                                  children: [
                                                    Text(
                                                      mediaItem.title,
                                                      style: const TextStyle(
                                                          fontWeight:
                                                          FontWeight.bold),
                                                      overflow:
                                                      TextOverflow.ellipsis,
                                                    ),
                                                    Text(
                                                      mediaItem.artist ?? '',
                                                      style: const TextStyle(
                                                          fontSize: 12),
                                                      overflow:
                                                      TextOverflow.ellipsis,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Row(
                                          children: [
                                            IconButton(
                                                onPressed: value.audioHandler
                                                    .skipToPrevious,
                                                icon: const Icon(
                                                    Icons.skip_previous)),
                                            IconButton(
                                              iconSize: 32,
                                              onPressed: isPlaying
                                                  ? value.audioHandler.pause
                                                  : value.audioHandler.play,
                                              icon: Icon(isPlaying
                                                  ? Icons.pause_circle_filled
                                                  : Icons
                                                  .play_circle_filled),
                                            ),
                                            IconButton(
                                                onPressed: value
                                                    .audioHandler.skipToNext,
                                                icon:
                                                const Icon(Icons.skip_next)),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    }),
            ],
          );
        },
      ),
    );
  }
}
