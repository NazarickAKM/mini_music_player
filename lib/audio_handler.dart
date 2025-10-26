// lib/audio_handler.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:path_provider/path_provider.dart';
import 'package:rxdart/rxdart.dart';

// Helper class for UI state
class PositionData {
  final Duration position;
  final Duration bufferedPosition;
  final Duration? duration;
  PositionData(this.position, this.bufferedPosition, this.duration);
}

class AudioPlayerHandler extends BaseAudioHandler with SeekHandler {
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
    _player.currentIndexStream.listen((index) async {
      final currentQueue = queue.value;
      if (index == null || index >= currentQueue.length) return;

      var item = currentQueue[index];

      // Check if the artUri is already a file URI. If not, create one.
      if (item.artUri?.scheme != 'file') {
        debugPrint("[HANDLER-LOG] Art URI for '${item.title}' is not a file URI. Fetching and saving artwork...");
        try {
          final artworkBytes = await _audioQuery.queryArtwork(
            int.parse(item.id),
            ArtworkType.AUDIO,
            size: 400,
          );

          if (artworkBytes != null) {
            final tempDir = (await getExternalCacheDirectories())?.first;
            if (tempDir != null) {
              final artFile = File('${tempDir.path}/artwork_${item.id}.jpg');
              await artFile.writeAsBytes(artworkBytes);
              debugPrint("[HANDLER-LOG] Artwork saved to: ${artFile.path}");

              item = item.copyWith(artUri: Uri.file(artFile.path));

              final newQueue = List<MediaItem>.from(currentQueue);
              newQueue[index] = item;
              this.queue.add(newQueue);
            }
          } else {
            debugPrint("[HANDLER-LOG] No artwork found for this item.");
          }
        } catch (e) {
          debugPrint("[HANDLER-LOG] Error creating artwork file: $e");
        }
      }
      mediaItem.add(item);
    });
  }

  // **FIX**: Re-adding the missing methods that were accidentally removed.
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
