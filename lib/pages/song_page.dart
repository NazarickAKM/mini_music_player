// lib/pages/song_page.dart

import 'dart:typed_data'; // **FIX**: Add this import for Uint8List
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';

import '../models/playlist_provider.dart';
import '../components/album_art_image.dart';
import '../components/neu_box.dart';

class BeveledIcon extends StatelessWidget {
  final IconData icon;
  final double size;
  final bool isCircular;

  const BeveledIcon({
    super.key,
    required this.icon,
    this.size = 32.0,
    this.isCircular = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final darkerShadow = Color.lerp(colorScheme.surface, Colors.black, 0.35);
    final lighterHighlight = Color.lerp(colorScheme.surface, Colors.white, 0.35);

    Widget iconWidget = SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          Positioned(
            left: -1,
            top: -1,
            child: Icon(icon, size: size, color: darkerShadow),
          ),
          Positioned(
            left: 1,
            top: 1,
            child: Icon(icon, size: size, color: lighterHighlight),
          ),
          Icon(icon, size: size, color: colorScheme.primary.withOpacity(0.7)),
        ],
      ),
    );

    if (isCircular) {
      return ClipOval(child: iconWidget);
    }
    return iconWidget;
  }
}

class SongPage extends StatefulWidget {
  const SongPage({super.key});

  @override
  State<SongPage> createState() => _SongPageState();
}

class _SongPageState extends State<SongPage> {
  @override
  Widget build(BuildContext context) {
    final playlistProvider = context.watch<PlaylistProvider>();
    final song = playlistProvider.currentSong;

    if (song == null) {
      return Scaffold(
        appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
        body: const Center(
          child: Text("No song selected."),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(left: 25, right: 25, bottom: 25),
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
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
                NeuBox(
                  child: Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: FutureBuilder<Uint8List?>(
                          future: playlistProvider.getArtwork(song.id),
                          builder: (context, snapshot) {
                            return AlbumArtImage(
                              albumArt: snapshot.data,
                              size: 300,
                            );
                          },
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
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold),
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
                StreamBuilder<PlaybackState>(
                  stream: playlistProvider.audioHandler.playbackState,
                  builder: (context, playbackStateSnapshot) {
                    final playbackState = playbackStateSnapshot.data;
                    final progress = playbackState?.updatePosition ?? Duration.zero;
                    final total = song.duration;
                    final isPlaying = playbackState?.playing ?? false;

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 25.0),
                          child: ProgressBar(
                            progress: progress,
                            total: total,
                            onSeek: playlistProvider.audioHandler.seek,
                            barHeight: 5.0,
                            thumbRadius: 8.0,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: playlistProvider.audioHandler.skipToPrevious,
                                child: const NeuBox(
                                  child: BeveledIcon(
                                    icon: Icons.skip_previous,
                                    size: 32,
                                  ),
                                ),
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
                                  child: BeveledIcon(
                                    icon: isPlaying ? Icons.pause : Icons.play_arrow,
                                    size: 48,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: GestureDetector(
                                onTap: playlistProvider.audioHandler.skipToNext,
                                child: const NeuBox(
                                  child: BeveledIcon(
                                    icon: Icons.skip_next,
                                    size: 32,
                                  ),
                                ),
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
      ),
    );
  }
}
