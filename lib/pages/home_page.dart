// lib/pages/home_page.dart

import 'package:audio_service/audio_service.dart'; // <-- MAKE SURE THIS IMPORT IS HERE
import 'package:flutter/material.dart';
import 'package:mini_music_player/components/my_drawer.dart';
import 'package:mini_music_player/models/playlist_provider.dart';
import 'package:mini_music_player/models/song.dart';
import 'package:mini_music_player/pages/song_page.dart';
import 'package:provider/provider.dart';
import '../components/album_art_image.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final PlaylistProvider playlistProvider;

  @override
  void initState() {
    super.initState();
    playlistProvider = Provider.of<PlaylistProvider>(context, listen: false);
    // Asynchronously pick songs without blocking the build method.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      playlistProvider.pickAndAddSongs();
    });
  }

  void goToSong(int songIndex) {
    // Set the current song index in the provider.
    playlistProvider.currentSongIndex = songIndex;

    // **FIX START**: Immediately start playback.
    // This tells the audio handler to not only switch to the new song but also
    // to start playing it. This ensures the playback state and media item
    // are updated promptly, preventing the loading screen issue.
    playlistProvider.audioHandler.play();
    // **FIX END**

    // Navigate to the song page.
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SongPage()),
    );
  }

  // --- START OF NEW METHOD: Go to the currently playing song page ---
  /// Navigates to the full song page. This is used when the user taps
  /// on the mini player.
  void goToCurrentSongPage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SongPage()),
    );
  }
  // --- END OF NEW METHOD ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text("P L A Y L I S T"),
        centerTitle: true,
      ),
      drawer: const MyDrawer(),
      body: Consumer<PlaylistProvider>(
        builder: (context, value, child) {
          final List<Song> playlist = value.playlist;

          // Edge Case: Show a message and a button to pick songs if the playlist is empty.
          if (playlist.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('No songs added yet.'),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () => value.pickAndAddSongs(),
                    child: const Text('Add Songs'),
                  ),
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
                    return ListTile(
                      title: Text(song.songName),
                      subtitle: Text(song.artistName),
                      leading: SizedBox(
                        width: 50,
                        height: 50,
                        child: AlbumArtImage(
                          albumArt: song.albumArt,
                          size: 50,
                        ),
                      ),
                      onTap: () => goToSong(index),
                    );
                  },
                ),
              ),

              // --- MINI PLAYER WRAPPED IN STREAMBUILDER ---
              // Use a StreamBuilder to listen for the currently playing item from the audio handler.
              StreamBuilder<MediaItem?>(
                  stream: value.audioHandler.mediaItem,
                  builder: (context, mediaItemSnapshot) {
                    final mediaItem = mediaItemSnapshot.data;
                    // Extract the custom Song object from the MediaItem's extras.
                    // This is how we get the rich data like album art.
                    final song = mediaItem?.extras?['song'] as Song?;

                    // Edge Case: If no song is loaded in the handler, show nothing.
                    if (mediaItem == null || song == null) {
                      return const SizedBox.shrink(); // Render an empty box.
                    }

                    // Once we have a song, build the mini player UI.
                    // This inner StreamBuilder listens for playback state changes (play/pause, position).
                    return StreamBuilder<PlaybackState>(
                      stream: value.audioHandler.playbackState,
                      builder: (context, playbackStateSnapshot) {
                        final playbackState = playbackStateSnapshot.data;
                        final isPlaying = playbackState?.playing ?? false;
                        final position = playbackState?.position ?? Duration.zero;
                        // Get total duration from the MediaItem metadata. Fallback to 1ms to avoid division by zero.
                        final duration = mediaItem.duration ?? const Duration(milliseconds: 1);

                        // --- START OF PROGRESS BAR IMPLEMENTATION ---
                        return GestureDetector(
                          onTap: goToCurrentSongPage, // Navigate to full screen player on tap
                          child: Container(
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.secondary,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(20),
                                topRight: Radius.circular(20),
                              ),
                            ),
                            // Use a minimal vertical padding for a compact look.
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // The slider acts as the visual progress bar.
                                SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 0), // Hide the thumb
                                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 0),
                                    trackHeight: 2, // Make the progress bar thin
                                  ),
                                  child: Slider(
                                    value: position.inMilliseconds.toDouble().clamp(0.0, duration.inMilliseconds.toDouble()),
                                    min: 0.0,
                                    max: duration.inMilliseconds.toDouble(),
                                    onChanged: (sliderValue) {
                                      // **FIXED**: Access the audio handler from the provider 'value'
                                      // The 'sliderValue' is the new position from the slider drag.
                                      value.audioHandler.seek(Duration(milliseconds: sliderValue.round()));
                                    },
                                    activeColor: Theme.of(context).colorScheme.primary,
                                    inactiveColor: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                                  ),
                                ),

                                // Player controls and song info
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      // Wrap the song info in an Expanded widget to prevent UI overflow.
                                      Expanded(
                                        child: Row(
                                          children: [
                                            ClipRRect(
                                              borderRadius: BorderRadius.circular(4),
                                              child: AlbumArtImage(
                                                albumArt: song.albumArt,
                                                size: 40,
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            // Also wrap this Column in an Expanded to allow text to truncate gracefully.
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    song.songName,
                                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                                    overflow: TextOverflow.ellipsis, // Prevent long text from overflowing.
                                                  ),
                                                  Text(
                                                    song.artistName,
                                                    style: const TextStyle(fontSize: 12),
                                                    overflow: TextOverflow.ellipsis, // Prevent long text from overflowing.
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Playback control buttons
                                      Row(
                                        children: [
                                          IconButton(onPressed: value.audioHandler.skipToPrevious, icon: const Icon(Icons.skip_previous)),
                                          IconButton(
                                            iconSize: 32, // Make the play/pause button slightly larger
                                            onPressed: isPlaying ? value.audioHandler.pause : value.audioHandler.play,
                                            icon: Icon(isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled),
                                          ),
                                          IconButton(onPressed: value.audioHandler.skipToNext, icon: const Icon(Icons.skip_next)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                        // --- END OF PROGRESS BAR IMPLEMENTATION ---
                      },
                    );
                  }
              ),
            ],
          );
        },
      ),
    );
  }
}
