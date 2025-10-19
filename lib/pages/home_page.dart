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

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  late final PlaylistProvider playlistProvider;

  @override
  void initState() {
    super.initState();
    playlistProvider = Provider.of<PlaylistProvider>(context, listen: false);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      requestStoragePermissionAndLoad();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      requestStoragePermissionAndLoad();
    }
  }

  Future<bool> _handlePermission() async {
    try {
      final sdkInt = await DeviceInfoPlugin().androidInfo.then((info) => info.version.sdkInt);
      final permission = sdkInt >= 33 ? Permission.audio : Permission.storage;

      var status = await permission.status;
      if (status.isDenied) {
        status = await permission.request();
      }

      if (status.isGranted) {
        return true;
      }

      if (status.isPermanentlyDenied) {
        if (kDebugMode) {
          print("Permission is permanently denied. Opening app settings...");
        }
        await openAppSettings();
      } else if (kDebugMode) {
        print("Permission denied.");
      }

      return false;
    } catch (e) {
      if (kDebugMode) {
        print("Error requesting permission: $e");
      }
      return false;
    }
  }

  void requestStoragePermissionAndLoad() async {
    if (playlistProvider.playlist.isNotEmpty) {
      return;
    }

    if (await _handlePermission()) {
      if (kDebugMode) {
        print("Permission granted. Loading songs automatically...");
      }
      playlistProvider.pickAndAddSongs();
    }
  }

  void _scanForSongs() async {
    if (await _handlePermission()) {
      context.read<PlaylistProvider>().pickAndAddSongs();
    }
  }

  void goToSong(int songIndex) {
    playlistProvider.currentSongIndex = songIndex;
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
      floatingActionButton: FloatingActionButton(
        onPressed: _scanForSongs,
        child: const Icon(Icons.refresh), // Changed from Icons.add
      ),
      body: Consumer<PlaylistProvider>(
        builder: (context, value, child) {
          final List<Song> playlist = value.playlist;

          if (playlist.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(25.0),
                // Updated text to reflect the new functionality
                child: Text(
                  "No songs found.\nTap the refresh button to scan for music.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
              ),
            );
          }

          return ListView.builder(
            itemCount: playlist.length,
            itemBuilder: (context, index) {
              final Song song = playlist[index];
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
