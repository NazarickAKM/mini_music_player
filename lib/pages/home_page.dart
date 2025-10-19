import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mini_music_player/pages/song_page.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../components/my_drawer.dart';
import '../models/playlist_provider.dart';
import '../models/song.dart';
import '../components/album_art_image.dart';
import 'package:device_info_plus/device_info_plus.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // get the playlist provider
  late final PlaylistProvider playlistProvider;

  @override
  void initState() {
    super.initState();

    // The context is available here, but we listen:false so it's safe.
    playlistProvider = Provider.of<PlaylistProvider>(context, listen: false);

    // THIS IS THE FIX:
    // Wait until the first frame is rendered before requesting permission.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // By now, the Android Activity is guaranteed to be ready.
      requestStoragePermissionAndLoad();
    });
  }

  void requestStoragePermissionAndLoad() async {

    await Future.delayed(const Duration(milliseconds: 500));

    // Check if songs are already loaded to avoid loading every time
    if (playlistProvider.playlist.isNotEmpty) {
      return;
    }

    try {
      PermissionStatus status;

      // Check Android version to request the correct permission.
      if (await DeviceInfoPlugin().androidInfo.then((info) => info.version.sdkInt) >= 33) {
        status = await Permission.audio.request();
      } else {
        status = await Permission.storage.request();
      }

      if (status.isGranted) {
        if (kDebugMode) {
          print("Permission granted. Loading songs automatically...");
        }
        playlistProvider.pickAndAddSongs();
      } else {
        if (kDebugMode) {
          print("Storage permission denied. Cannot automatically load songs.");
        }
      }
    } catch (e) {
      // If any error happens during permission request, log it.
      if (kDebugMode) {
        print("Error requesting permission: $e");
      }
    }
  }

  // go to a song
  void goToSong(int songIndex){
    //update current song index
    playlistProvider.currentSongIndex = songIndex;

    //navigate to song page
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => const SongPage(),
  ),
);


  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(title: const Text("P L A Y L I S T")),
      drawer: const MyDrawer(),
///
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () {
          // When pressed, call the new method we created in the provider.
          // We use context.read because we are in a button's callback, not building UI.
          context.read<PlaylistProvider>().pickAndAddSongs();
        },
      ),
///
      body: Consumer<PlaylistProvider>(
        builder: (context, value, child) {
          //get the playlist
          final List<Song> playlist = value.playlist;
///
          // If the playlist has no songs, display a helpful message.
          if (playlist.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(25.0),
                child: Text(
                  "No songs found.\nTap the '+' button to add music from your device.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
              ),
            );
          }
///
          // return list view UI
          return ListView.builder(
              itemCount: playlist.length,
              itemBuilder: (context, index) {
                //get individual song
                final Song song = playlist[index];

                //return list tile UI
                return ListTile(
                  title: Text(
                    song.songName,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    softWrap: false,
                  ),
                  subtitle: Text(
                    song.artistName,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    softWrap: false,
                  ),
                  leading: AlbumArtImage(imagePath: song.albumArtImagePath),

                  onTap: () => goToSong(index),
                );
              },
          );
        },
      ),
    );
  }
}
