import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:mini_music_player/audio_handler.dart';
import 'package:mini_music_player/pages/home_page.dart';
import 'package:mini_music_player/themes/theme_provider.dart';
import 'package:provider/provider.dart';

import 'models/playlist_provider.dart';

late AudioHandler _audioHandler;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _audioHandler = await AudioService.init(
    builder: () => AudioPlayerHandler(), // Use your custom handler
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.ryanheise.myapp.channel.audio',
      androidNotificationChannelName: 'Audio playback',
      androidNotificationOngoing: true,
    ),
  );
  runApp(
    MultiProvider(
      providers: [
        // Provider for Theme
        ChangeNotifierProvider(create: (context) => ThemeProvider()),

        // Provider for Playlist, passing the audioHandler to it
        ChangeNotifierProvider(create: (context) => PlaylistProvider(_audioHandler)),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          home: const HomePage(),
          theme: themeProvider.themeData,
        );
      },
    );
  }
}
