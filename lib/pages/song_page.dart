// lib/pages/song_page.dart

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';

import '../models/playlist_provider.dart';
import '../components/album_art_image.dart';
import '../components/neu_box.dart';

class SongPage extends StatefulWidget {
  const SongPage({super.key});

  @override
  State<SongPage> createState() => _SongPageState();
}

class _SongPageState extends State<SongPage> {

  @override
  Widget build(BuildContext context) {
    // We use `watch` here so the whole page rebuilds if the song changes (e.g., on skip).
    final playlistProvider = context.watch<PlaylistProvider>();
    final song = playlistProvider.currentSong;

    // Edge Case: If for some reason there is no current song, show a loading screen.
    if (song == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Now we build the UI with the guaranteed 'song' object for static data.
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(left: 25, right: 25, bottom: 25),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // --- CUSTOM APP BAR ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back),
                  ),
                  const Text("N O W   P L A Y I N G"),
                  const IconButton(onPressed: null, icon: Icon(null)),
                ],
              ),

              const SizedBox(height: 25),

              // --- ALBUM ART AND SONG INFO (using static `song` data) ---
              NeuBox(
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: AlbumArtImage(
                        albumArt: song.albumArt,
                        size: 300,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(15.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  song.songName,
                                  style: const TextStyle(
                                      fontSize: 20, fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  song.artistName,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.favorite, color: Colors.red),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 25),

              // --- PLAYBACK PROGRESS AND CONTROLS ---
              StreamBuilder<PlaybackState>(
                stream: playlistProvider.audioHandler.playbackState,
                builder: (context, playbackStateSnapshot) {
                  final playbackState = playbackStateSnapshot.data;
                  final progress = playbackState?.position ?? Duration.zero;
                  // **DEFINITIVE FIX:** Provide a fallback of Duration.zero if song.duration is null.
                  final total = song.duration ?? Duration.zero;
                  final isPlaying = playbackState?.playing ?? false;

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 25.0),
                        child: ProgressBar(
                          progress: progress,
                          total: total, // This is now guaranteed to be non-null
                          onSeek: playlistProvider.audioHandler.seek,
                          barHeight: 5.0,
                          thumbRadius: 8.0,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: playlistProvider.audioHandler.skipToPrevious,
                              child: const NeuBox(child: Icon(Icons.skip_previous)),
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            flex: 2,
                            child: GestureDetector(
                              onTap: isPlaying
                                  ? playlistProvider.audioHandler.pause
                                  : playlistProvider.audioHandler.play,
                              child: NeuBox(
                                child: Icon(isPlaying ? Icons.pause : Icons.play_arrow, size: 40),
                              ),
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: GestureDetector(
                              onTap: playlistProvider.audioHandler.skipToNext,
                              child: const NeuBox(child: Icon(Icons.skip_next)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
