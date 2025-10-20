import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';

/// A helper class to hold the data from the combined position stream.
class PositionData {
  final Duration position;
  final Duration bufferedPosition;
  final Duration? duration;

  PositionData(this.position, this.bufferedPosition, this.duration);
}

class AudioPlayerHandler extends BaseAudioHandler with SeekHandler {
  final _player = AudioPlayer();
  final _playlist = ConcatenatingAudioSource(children: []);

  AudioPlayerHandler() {
    _loadEmptyPlaylist();
    _notifyAudioHandlerAboutPlaybackEvents();
    _listenForDurationChanges();
    _listenForCurrentSongIndexChanges();
  }

  void _notifyAudioHandlerAboutPlaybackEvents() {
    final positionDataStream =
    Rx.combineLatest3<Duration, Duration, Duration?, PositionData>(
      _player.positionStream,
      _player.bufferedPositionStream,
      _player.durationStream,
          (position, bufferedPosition, duration) =>
          PositionData(position, bufferedPosition, duration),
    );

    Rx.combineLatest2<PlayerState, PositionData, PlaybackState>(
      _player.playerStateStream.distinct(),
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
          systemActions: const {
            MediaAction.seek,
            MediaAction.seekForward,
            MediaAction.seekBackward,
            MediaAction.play,
            MediaAction.pause,
            MediaAction.skipToNext,
            MediaAction.skipToPrevious,
          },
          androidCompactActionIndices: const [0, 1, 3],
          queueIndex: _player.currentIndex,
        );
      },
    ).pipe(playbackState);
  }

  void _listenForCurrentSongIndexChanges() {
    _player.currentIndexStream.listen((index) {
      final currentQueue = queue.value;
      if (index == null || currentQueue.isEmpty || index >= currentQueue.length) {
        mediaItem.add(null);
        return;
      }
      mediaItem.add(currentQueue[index]);
    });
  }

  void _listenForDurationChanges() {
    _player.durationStream.listen((duration) {
      final index = _player.currentIndex;
      final currentQueue = queue.value;
      if (index == null ||
          currentQueue.isEmpty ||
          index >= currentQueue.length) {
        return;
      }
      final oldMediaItem = currentQueue[index];
      // This is the key: when the true duration is discovered by just_audio,
      // we create a NEW MediaItem with this duration and broadcast it.
      if (oldMediaItem.duration != duration) {
        final newMediaItem = oldMediaItem.copyWith(duration: duration);
        mediaItem.add(newMediaItem);
      }
    });
  }

  Future<void> _loadEmptyPlaylist() async {
    try {
      await _player.setAudioSource(_playlist);
    } catch (e) {
      print("Error: $e");
    }
  }

  UriAudioSource _createAudioSource(MediaItem mediaItem) {
    return AudioSource.uri(
      Uri.parse(mediaItem.extras!['url']),
      tag: mediaItem,
    );
  }

  @override
  Future<void> updateQueue(List<MediaItem> newQueue) async {
    await _playlist.clear();
    await _playlist.addAll(newQueue.map(_createAudioSource).toList());
    queue.add(newQueue);
  }

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
    if (index < 0 || index >= _playlist.length) return;
    await _player.seek(Duration.zero, index: index);
    play();
  }

  @override
  Future<void> stop() async {
    await _player.stop();
    return super.stop();
  }
}
