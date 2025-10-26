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

          if (playlist.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 10),
                  Text('Loading Songs...'),
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
                        // FIX: Pass the song ID to the updated widget
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
                      onTap: () {
                        if (value.currentSongIndex != index) {
                          goToSong(index);
                        } else {
                          navigateToSongPage();
                        }
                      },
                    );
                  },
                ),
              ),

              // MINI PLAYER
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
