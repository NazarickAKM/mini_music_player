import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:mini_music_player/models/playlist_provider.dart';
import 'package:mini_music_player/themes/theme_provider.dart';
import 'package:mini_music_player/pages/home_page.dart';
import 'package:provider/provider.dart';
import 'audio_handler.dart';

late AudioHandler _audioHandler;

Future<void> main() async {
  _audioHandler = await AudioService.init(
    builder: () => AudioPlayerHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.akm.mmp.channel.audio',
      androidNotificationChannelName: 'Mini Music Player',
      androidNotificationIcon: 'drawable/ic_music_note',
      androidNotificationOngoing: true,
    ),
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Theme provider
        ChangeNotifierProvider(create: (context) => ThemeProvider()),
        // Playlist provider
        ChangeNotifierProvider(create: (context) => PlaylistProvider(_audioHandler)),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            home: const HomePage(),
            theme: themeProvider.themeData,
          );
        },
      ),
    );
  }
}
