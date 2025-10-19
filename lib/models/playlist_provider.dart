import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:mini_music_player/models/song.dart';

const String placeholderImagePath = 'assets/images/placeholder.svg';
class PlaylistProvider extends ChangeNotifier {
  //playlist of songs
  final List<Song> _playlist = [];

  //current song playing index
int? _currentSongIndex;


  //audio player
  final AudioPlayer _audioPlayer = AudioPlayer();


  //durations
  Duration _currentDuration = Duration.zero;
  Duration _totalDuration = Duration.zero;

  //constructor
  PlaylistProvider(){
    listenToDuration();
  }

  //initially not playing
  bool _isPlaying = false;

  /// Picks multiple audio files from the device storage and adds them to the playlist.
  void pickAndAddSongs() async {
    // Request permission from the user to access storage.
    var status = await Permission.storage.request();

    // If permission is denied, we can't do anything. Stop here.
    if (!status.isGranted) {
      // Optionally: show a message to the user that permission is required.
      if (kDebugMode) {
        print("Storage permission denied. Cannot pick songs.");
      }
      return;
    }

    // 3. Open the native file picker UI to select audio files.
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.audio,
    );

    // 4. If the user picked files (result is not null), process them.
    if (result != null) {
      // Map the list of file paths to a list of Song objects.
      List<Song> newSongs = result.paths.where((path) => path != null).map((path) {
        final String fileName = path!.split('/').last; // e.g., "MySong.mp3"
        return Song(
          songName: fileName.replaceAll(RegExp(r'\.mp3|\.wav'), ''), // "MySong"
          artistName: "Unknown Artist", // We can't know this without reading metadata
          albumArtImagePath: "assets/images/placeholder.svg", // Use a default image
          audioPath: path, // This is the most important part: the full file path.
        );
      }).toList();

      // Add all the newly selected songs to our main playlist.
      _playlist.addAll(newSongs);
      // Notify all listeners (like the UI) that the playlist has changed.
      notifyListeners();
    }
  }
///AI codes ^^^


  //play song
  void play() async{
    if (_currentSongIndex == null) return;

    final String path = _playlist[_currentSongIndex!].audioPath;

    //stop current song
    await _audioPlayer.stop();

    //play new song
    await _audioPlayer.play(DeviceFileSource(path));
    _isPlaying = true;
    notifyListeners();
  }

  //pause current song
  void pause() async{
    await _audioPlayer.pause();
    _isPlaying = false;
    notifyListeners();
  }

  //resume song
  void resume() async{
    await _audioPlayer.resume();
    _isPlaying = true;
    notifyListeners();
  }

  //pause or resume
  void pauseOrResume() async{
    if(_isPlaying){
      pause();
    }else{
      resume();
    }
    notifyListeners();
  }

  //seek
  void seek(Duration position) async{
    await _audioPlayer.seek(position);
  }

  //play next
  void playNextSong() {
    if (_currentSongIndex != null) {
      if (_currentSongIndex! < _playlist.length - 1) {
        //go to next song if its not the last song
        currentSongIndex = _currentSongIndex! + 1;
      } else {
        //go to first song if its the last song
        currentSongIndex = 0;
      }
    }
  }

  //play previous
  void playPrevSong() async{
    //if more than 2 seconds have passed, restart the current song
    if(_currentDuration.inSeconds > 2){
      seek(Duration.zero);
    }
    //if its within the first 2 seconds of the song, got to the previous song
    else{
      if(_currentSongIndex! > 0){
        currentSongIndex = _currentSongIndex! - 1;
      }else{
        //if its the first song, go to the last song
        currentSongIndex = _playlist.length - 1;
      }
    }
  }

  //listen to duration
  void listenToDuration(){
    //listen for total duration
    _audioPlayer.onDurationChanged.listen((newDuration) {
      _totalDuration = newDuration;
      notifyListeners();
    });

    //listen for current duration
    _audioPlayer.onPositionChanged.listen((newPosition) {
      _currentDuration = newPosition;
      notifyListeners();
    });

    //listen for song completion
    _audioPlayer.onPlayerComplete.listen((event) {
      playNextSong();
    });



  }

  //dispose audio player
  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

//Getters

List<Song> get playlist => _playlist;
int? get currentSongIndex => _currentSongIndex;
bool get isPlaying => _isPlaying;
Duration get currentDuration => _currentDuration;
Duration get totalDuration => _totalDuration;

//Setters
set currentSongIndex(int? newIndex){
  //update current song index
  _currentSongIndex = newIndex;

  if(newIndex != null){
    //play song
    play();
  }

  //update UI
  notifyListeners();
}


}
