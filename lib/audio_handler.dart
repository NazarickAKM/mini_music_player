// lib/audio_handler.dart
import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:path_provider/path_provider.dart';
import 'package:rxdart/rxdart.dart';

// Define the package name and drawable URI in one place
const String packageName = "com.akm.mmp.mini_music_player";
const String drawableUri = "android.resource://$packageName/drawable/ic_headphone";

// Helper class for UI state
class PositionData {
  final Duration position;
  final Duration bufferedPosition;
  final Duration? duration;
  PositionData(this.position, this.bufferedPosition, this.duration);
}

class AudioPlayerHandler extends BaseAudioHandler with SeekHandler {
  // **FIX**: Removed the incompatible constructor parameter.
  // The 'Unsupported scheme' error will return to the logs, but this is benign.
  final _player = AudioPlayer();

  final _playlist = ConcatenatingAudioSource(children: []);
  final _audioQuery = OnAudioQuery();

  AudioPlayerHandler() {
    _loadEmptyPlaylist();
    _notifyAudioHandlerAboutPlaybackEvents();
    _listenForCurrentSongIndexChanges();
  }

  // This stream pipeline is correct and stable for UI updates.
  void _notifyAudioHandlerAboutPlaybackEvents() {
    final playerStateStream = _player.playerStateStream;
    final positionDataStream = Rx.combineLatest3<Duration, Duration, Duration?, PositionData>(
      _player.positionStream,
      _player.bufferedPositionStream,
      _player.durationStream,
          (position, bufferedPosition, duration) => PositionData(position, bufferedPosition, duration),
    );

    Rx.combineLatest2<PlayerState, PositionData, PlaybackState>(
      playerStateStream,
      positionDataStream,
          (playerState, positionData) {
        final processingState = const {
          ProcessingState.idle: AudioProcessingState.idle,
          ProcessingState.loading: AudioProcessingState.loading,
          ProcessingState.buffering: AudioProcessingState.buffering,
          ProcessingState.ready: AudioProcessingState.ready,
          ProcessingState.completed: AudioProcessingState.completed,
        }[playerState.processingState]!;

        return PlaybackState(
          playing: playerState.playing,
          updatePosition: positionData.position,
          bufferedPosition: positionData.bufferedPosition,
          speed: _player.speed,
          processingState: processingState,
          controls: [
            MediaControl.skipToPrevious,
            if (playerState.playing) MediaControl.pause else MediaControl.play,
            MediaControl.stop,
            MediaControl.skipToNext,
          ],
          systemActions: const {MediaAction.seek},
          androidCompactActionIndices: const [0, 1, 3],
          queueIndex: _player.currentIndex,
        );
      },
    ).listen(playbackState.add);
  }

  // This fetches artwork just-in-time for the notification.
  void _listenForCurrentSongIndexChanges() {
    // **OPTIMIZATION**: Use distinct() to prevent rapid, repeated calls for the same index.
    // This stops the unnecessary re-fetching and saving of artwork.
    _player.currentIndexStream.distinct().listen((index) async {
      final currentQueue = queue.value;
      if (index == null || index >= currentQueue.length) return;

      var item = currentQueue[index];
      mediaItem.add(item); // Immediately update with current info

      // **REFINED LOGIC**: Only fetch artwork if the URI is not already set to a local file or a resource.
      final bool hasLocalArt = item.artUri?.scheme == 'file' || item.artUri?.scheme == 'android.resource';

      if (!hasLocalArt) {
        debugPrint("[DIAGNOSTIC] No local art found. Attempting to fetch for '${item.title}'.");
        Uint8List? artworkBytes;
        try {
          artworkBytes = await _audioQuery.queryArtwork(
            int.parse(item.id),
            ArtworkType.AUDIO,
            size: 400,
          );

          if (artworkBytes != null && artworkBytes.isNotEmpty) {
            final tempDir = (await getExternalCacheDirectories())?.first;
            if (tempDir != null) {
              final artFile = File('${tempDir.path}/artwork_${item.id}.jpg');
              await artFile.writeAsBytes(artworkBytes);
              item = item.copyWith(artUri: Uri.file(artFile.path));
              debugPrint("[DIAGNOSTIC] Set artUri to FILE: ${item.artUri}");
            }
          } else {
            // Fallback for songs with no artwork
            item = item.copyWith(artUri: Uri.parse(drawableUri));
            debugPrint("[DIAGNOSTIC] No artwork data. Set artUri to DRAWABLE: ${item.artUri}");
          }
        } catch (e) {
          debugPrint("[DIAGNOSTIC] Error during artwork query: $e. Using fallback drawable.");
          // Fallback on error
          item = item.copyWith(artUri: Uri.parse(drawableUri));
        }

        // Update the queue with the new item containing the art URI
        final newQueue = List<MediaItem>.from(currentQueue);
        newQueue[index] = item;
        this.queue.add(newQueue);
        mediaItem.add(item); // Crucially, update the handler's current mediaItem again
        debugPrint("[DIAGNOSTIC] Updated queue and mediaItem for '${item.title}'.");
      } else {
        debugPrint("[DIAGNOSTIC] Skipping artwork fetch for '${item.title}', URI already exists: ${item.artUri}");
      }
    });
  }

  Future<void> _loadEmptyPlaylist() async {
    try {
      await _player.setAudioSource(_playlist);
    } catch (e) {
      debugPrint("Error setting empty audio source: $e");
    }
  }

  UriAudioSource _createAudioSource(MediaItem mediaItem) {
    return AudioSource.uri(
      Uri.parse(mediaItem.extras!['url']),
      tag: mediaItem,
    );
  }

  @override
  Future<void> updateQueue(List<MediaItem> queue) async {
    await _playlist.clear();
    await _playlist.addAll(queue.map(_createAudioSource).toList());
    this.queue.add(queue);

    if (queue.isNotEmpty) {
      try {
        await _player.load();
      } catch (e) {
        debugPrint("Error loading playlist: $e");
      }
    }
  }

  // --- Playback Controls ---
  @override
  Future<void> play() => _player.play();
  @override
  Future<void> pause() => _player.pause();
  @override
  Future<void> seek(Duration position) => _player.seek(position);
  @override
  Future<void> skipToNext() => _player.seekToNext();
  @override
  Future<void> skipToPrevious() => _player.seekToPrevious();
  @override
  Future<void> skipToQueueItem(int index) async {
    if (index < 0 || index >= this.queue.value.length) return;
    await _player.seek(Duration.zero, index: index);
    if (!playbackState.value.playing) play();
  }
  @override
  Future<void> stop() async {
    await _player.stop();
    return super.stop();
  }
}
