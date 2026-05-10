import 'package:just_audio/just_audio.dart';
import 'package:flutter/foundation.dart';
import '../services/library_service.dart';

class PlayerService {
  static final PlayerService _instance = PlayerService._internal();
  factory PlayerService() => _instance;
  PlayerService._internal();

  final AudioPlayer player = AudioPlayer();
  final ValueNotifier<AudioFile?> currentSong = ValueNotifier<AudioFile?>(null);
  
  // Expose player state
  Stream<Duration> get positionStream => player.positionStream;
  Stream<Duration?> get durationStream => player.durationStream;
  Stream<bool> get playingStream => player.playingStream;

  Future<void> playSong(AudioFile song) async {
    currentSong.value = song;
    try {
      await player.setAudioSource(AudioSource.uri(Uri.file(song.path)));
      player.play();
    } catch (e) {
      print("Error playing audio: $e");
    }
  }

  void playPause() {
    if (player.playing) {
      player.pause();
    } else {
      player.play();
    }
  }

  void seek(Duration position) {
    player.seek(position);
  }
}
