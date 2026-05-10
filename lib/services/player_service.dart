import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../services/library_service.dart';

class PlayerService {
  static final PlayerService _instance = PlayerService._internal();
  factory PlayerService() => _instance;
  
  static const MethodChannel _channel = MethodChannel('com.luminapro/audio');
  static const EventChannel _positionEventChannel = EventChannel('com.luminapro/audio_position');
  static const EventChannel _stateEventChannel = EventChannel('com.luminapro/audio_state');

  PlayerService._internal() {
    _positionEventChannel.receiveBroadcastStream().listen((event) {
      if (event is Map) {
        final posMs = event['position'] as int?;
        final durMs = event['duration'] as int?;
        if (posMs != null) _positionNotifier.value = Duration(milliseconds: posMs);
        if (durMs != null) _durationNotifier.value = Duration(milliseconds: durMs);
      }
    });

    _stateEventChannel.receiveBroadcastStream().listen((event) {
      if (event is Map) {
        final playing = event['playing'] as bool?;
        final finished = event['finished'] as bool?;
        if (playing != null) _playingNotifier.value = playing;
        if (finished == true) skipToNext();
      }
    });
  }

  List<AudioFile> _queue = [];
  int _currentIndex = 0;

  final ValueNotifier<AudioFile?> currentSong = ValueNotifier<AudioFile?>(null);
  
  final ValueNotifier<Duration> _positionNotifier = ValueNotifier(Duration.zero);
  final ValueNotifier<Duration?> _durationNotifier = ValueNotifier(null);
  final ValueNotifier<bool> _playingNotifier = ValueNotifier(false);

  Stream<Duration> get positionStream => Stream.periodic(Duration(milliseconds: 200), (_) => _positionNotifier.value);
  Stream<Duration?> get durationStream => Stream.periodic(Duration(milliseconds: 200), (_) => _durationNotifier.value);
  Stream<bool> get playingStream => Stream.periodic(Duration(milliseconds: 200), (_) => _playingNotifier.value);

  Future<void> playSong(AudioFile song) async {
    await playQueue([song], initialIndex: 0);
  }

  Future<void> playQueue(List<AudioFile> songs, {int initialIndex = 0}) async {
    _queue = List.from(songs);
    _currentIndex = initialIndex;
    await _playCurrent();
  }

  Future<void> _playCurrent() async {
    if (_queue.isEmpty || _currentIndex < 0 || _currentIndex >= _queue.length) return;
    
    final song = _queue[_currentIndex];
    currentSong.value = song;
    
    try {
      await _channel.invokeMethod('play', {
        'path': song.path,
        'title': song.title,
        'artist': song.artist,
      });
      _playingNotifier.value = true;
    } catch (e) {
      print("Error invoking native play: $e");
    }
  }

  Future<void> playPause() async {
    try {
      if (_playingNotifier.value) {
        await _channel.invokeMethod('pause');
        _playingNotifier.value = false;
      } else {
        await _channel.invokeMethod('resume');
        _playingNotifier.value = true;
      }
    } catch (e) {
      print("Error invoking native playPause: $e");
    }
  }

  Future<void> seek(Duration position) async {
    try {
      await _channel.invokeMethod('seek', {'position': position.inMilliseconds});
      _positionNotifier.value = position;
    } catch (e) {
      print("Error invoking native seek: $e");
    }
  }

  void skipToNext() {
    if (_currentIndex < _queue.length - 1) {
      _currentIndex++;
      _playCurrent();
    }
  }

  void skipToPrevious() {
    if (_currentIndex > 0) {
      _currentIndex--;
      _playCurrent();
    } else {
      seek(Duration.zero);
    }
  }

  Future<void> updateEQ(List<Map<String, dynamic>> bands) async {
    try {
      await _channel.invokeMethod('updateEQ', {'bands': bands});
    } catch (e) {
      print("Error invoking native updateEQ: $e");
    }
  }
}
