import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../components/neu_box.dart';
import '../models/playlist_provider.dart';
import '../components/album_art_image.dart';
import 'package:mini_music_player/components/my_drawer.dart';

class SongPage extends StatelessWidget {
  const SongPage({super.key});

  //convert duration into min:sec
  String formatTime(Duration duration) {
    String twoDigitSeconds = duration.inSeconds
        .remainder(60)
        .toString()
        .padLeft(2, '0');
    String formattedTime = "${duration.inMinutes}:$twoDigitSeconds";

    return formattedTime;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PlaylistProvider>(
      builder: (context, value, child) {
        //get playlist
        final playlist = value.playlist;

        //get current song index
        final currentSong = playlist[value.currentSongIndex ?? 0];

        //return scaffold UI
        return Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surface,

          drawer: const MyDrawer(),

          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(left: 25, right: 25, bottom: 25),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // app bar
                  AppBar(
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    leading: IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back),
                    ),
                      //title
                      title: const Text("P L A Y L I S T"),
                      actions: [
                      //menu button
                        Builder(
                            builder: (context) {
                              return IconButton(
                                onPressed: () {
                                  Scaffold.of(context).openDrawer();
                                },
                                icon: const Icon(Icons.menu),
                              );
                            }
                        ),
                      ],
                  ),

                  const SizedBox(height: 25),

                  //album artwork
                  NeuBox(
                    child: Column(
                      children: [
                        //image
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: AlbumArtImage(
                            imagePath: currentSong.albumArtImagePath,
                            size: 250,
                          ),
                        ),

                        //song and artis name and icon
                        Padding(
                          padding: const EdgeInsets.all(15.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              //song and artis name
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      currentSong.songName,
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                      softWrap: false,
                                    ),
                                    Text(
                                      currentSong.artistName,
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                      softWrap: false,
                                    ),
                                  ],
                                ),
                              ),

                              //heart icon
                              const Icon(Icons.favorite, color: Colors.red),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 25),

                  //song duration progress
                  Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 25.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            //start time
                            Text(formatTime(value.currentDuration)),

                            //shuffle icon
                            const Icon(Icons.shuffle),

                            //repeat icon
                            const Icon(Icons.repeat),

                            //end time
                            Text(formatTime(value.totalDuration)),
                          ],
                        ),
                      ),

                      //song duration progress
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 0,
                          ),
                        ),
                        child: Slider(
                          min: 0,
                          max: value.totalDuration.inSeconds.toDouble(),
                          value: value.currentDuration.inSeconds.toDouble(),
                          activeColor: Colors.grey.shade800,
                          onChanged: (double double) {
                            //when the user is sliding around
                          },
                          onChangeEnd: (double double) {
                            //sliding has finished, go to that position in song duration
                            value.seek(Duration(seconds: double.toInt()));
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  //playback controls
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      //skip previous
                      Expanded(
                        child: GestureDetector(
                          onTap: value.playPrevSong,
                          child: const NeuBox(child: Icon(Icons.skip_previous)),
                        ),
                      ),

                      const SizedBox(width: 20),

                      //play pause
                      Expanded(
                        flex: 2,
                        child: GestureDetector(
                          onTap: value.pauseOrResume,
                          child: NeuBox(
                            child: Icon(
                              value.isPlaying ? Icons.pause : Icons.play_arrow,
                            ),
                          ),
                        ),
                      ),

                      //skip next
                      Expanded(
                        child: GestureDetector(
                          onTap: value.playNextSong,
                          child: const NeuBox(child: Icon(Icons.skip_next)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
