import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:flutter/foundation.dart';
import '../services/library_service.dart';

class PlayerService {
  static final PlayerService _instance = PlayerService._internal();
  factory PlayerService() => _instance;
  
  PlayerService._internal() {
    player.currentIndexStream.listen((index) {
      if (index != null && index < _queue.length) {
        currentSong.value = _queue[index];
      }
    });
  }

  final AudioPlayer player = AudioPlayer();
  final ValueNotifier<AudioFile?> currentSong = ValueNotifier<AudioFile?>(null);

  Future<void> playSong(AudioFile song) async {
    await playQueue([song], initialIndex: 0);
  }

  Future<void> playQueue(List<AudioFile> songs, {int initialIndex = 0}) async {
    _queue = List.from(songs);
    if (_queue.isNotEmpty && initialIndex < _queue.length) {
      currentSong.value = _queue[initialIndex];
    }
    final audioSources = songs.map((song) {
      return AudioSource.uri(
        Uri.file(song.path),
        tag: MediaItem(
          id: song.path,
          album: song.album,
          title: song.title,
          artist: song.artist,
          artUri: Uri.file(song.path), // Basic fallback if possible
        ),
      );
    }).toList();

    _playlist = ConcatenatingAudioSource(children: audioSources);
    
    try {
      await player.setAudioSource(_playlist, initialIndex: initialIndex, initialPosition: Duration.zero);
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

  void skipToNext() {
    player.seekToNext();
  }

  void skipToPrevious() {
    player.seekToPrevious();
  }
}

