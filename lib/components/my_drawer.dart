// lib/components/my_drawer.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/playlist_provider.dart';
import '../pages/settings_page.dart';

class MyDrawer extends StatelessWidget {
  const MyDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Theme.of(context).colorScheme.surface,
      child: Column(
        children: [
          // ... (DrawerHeader, Home Tile, Settings Tile are the same)
          DrawerHeader(
            child: Center(
              child: Icon(
                Icons.music_note,
                size: 40,
                color: Theme.of(context).colorScheme.inversePrimary,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 25.0, top: 25.0),
            child: ListTile(
              title: const Text("H O M E"),
              leading: const Icon(Icons.home),
              onTap: () => Navigator.pop(context),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 25.0, top: 0),
            child: ListTile(
              title: const Text("S E T T I N G S"),
              leading: const Icon(Icons.settings),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SettingsPage(),
                  ),
                );
              },
            ),
          ),

          // Refresh tile
          Padding(
            padding: const EdgeInsets.only(left: 25.0, top: 0),
            child: ListTile(
              title: const Text("R E F R E S H"),
              leading: const Icon(Icons.refresh),
              onTap: () {
                Navigator.pop(context);
                // **FIX**: Call the new public method to rescan songs.
                context.read<PlaylistProvider>().rescanSongs();
              },
            ),
          ),
        ],
      ),
    );
  }
}
