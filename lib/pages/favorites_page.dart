// lib/pages/favorites_page.dart
import 'package:flutter/material.dart';
import 'package:mini_music_player/models/playlist_provider.dart';
import 'package:provider/provider.dart';
import '../models/song.dart';
import 'song_page.dart';

class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("F A V O R I T E S"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Consumer<PlaylistProvider>(
        builder: (context, provider, child) {
          final List<Song> favoritesPlaylist = provider.favorites;

          // If there are no favorite songs, show a message.
          if (favoritesPlaylist.isEmpty) {
            return const Center(
              child: Text("No favorite songs yet."),
            );
          }

          // Otherwise, display the list of favorite songs.
          return ListView.builder(
            itemCount: favoritesPlaylist.length,
            itemBuilder: (context, index) {
              final Song song = favoritesPlaylist[index];
              return ListTile(
                title: Text(song.songName),
                subtitle: Text(song.artistName),
                leading: const Icon(Icons.music_note),
                onTap: () {
                  // Find the original index of the song in the main playlist.
                  final originalIndex = provider.playlist.indexWhere((s) => s.id == song.id);
                  if (originalIndex != -1) {
                    // Set the current song index to start playback.
                    provider.currentSongIndex = originalIndex;
                    // Navigate to the song page.
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const SongPage()),
                    );
                  } else {
                    debugPrint("[FAVORITES-LOG] Error: Tapped song not found in main playlist.");
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}
