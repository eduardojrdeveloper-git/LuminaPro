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

  List<Map<String, dynamic>> eqBands = [
    {'fc': 1000.0, 'gain': -6.0, 'q': 1.41, 'type': 'Preamp'},
    {'fc': 31.0, 'gain': 0.0, 'q': 1.41, 'type': 'PK'},
    {'fc': 250.0, 'gain': 0.0, 'q': 1.41, 'type': 'LSC'},
    {'fc': 8000.0, 'gain': 0.0, 'q': 1.41, 'type': 'HSC'},
  ];

  PlayerService._internal() {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'nextTrack':
          skipToNext();
          break;
        case 'previousTrack':
          skipToPrevious();
          break;
        case 'playPause':
          playPause();
          break;
        case 'seek':
          if (call.arguments != null && call.arguments['position'] != null) {
            _positionNotifier.value = Duration(milliseconds: call.arguments['position']);
          }
          break;
      }
    });

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
      await applyCurrentEQ();
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

  Future<void> updatePreamp(double gain) async {
    try {
      await _channel.invokeMethod('updatePreamp', {'gain': gain});
    } catch (e) {
      print("Error invoking native updatePreamp: $e");
    }
  }

  Future<void> applyCurrentEQ() async {
    double preamp = 0.0;
    List<Map<String, dynamic>> hardwareBands = [];
    for (var b in eqBands) {
      if (b['type'] == 'Preamp') {
        preamp += (b['gain'] as num).toDouble();
      } else {
        hardwareBands.add(b);
      }
    }
    await updatePreamp(preamp);
    await updateEQ(hardwareBands);
  }
}
