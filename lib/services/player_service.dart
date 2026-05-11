import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../services/library_service.dart' hide debugPrint;

enum RepeatMode { off, one, all }

class PlayerService {
  static final PlayerService _instance = PlayerService._internal();
  factory PlayerService() => _instance;

  static const MethodChannel _channel = MethodChannel('com.luminapro/audio');
  static const EventChannel _positionEventChannel =
      EventChannel('com.luminapro/audio_position');
  static const EventChannel _stateEventChannel =
      EventChannel('com.luminapro/audio_state');

  // ── EQ Bands ────────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> eqBands = [
    {'fc': 1000.0, 'gain': -6.0, 'q': 1.41, 'type': 'Preamp'},
    {'fc': 31.0,   'gain': 0.0,  'q': 1.41, 'type': 'PK'},
    {'fc': 250.0,  'gain': 0.0,  'q': 1.41, 'type': 'LSC'},
    {'fc': 8000.0, 'gain': 0.0,  'q': 1.41, 'type': 'HSC'},
  ];

  // ── Crossfade ────────────────────────────────────────────────────────────────
  double crossfadeDuration = 0.0;

  // ── Playback State ───────────────────────────────────────────────────────────
  List<AudioFile> _queue = [];
  List<AudioFile> _originalQueue = [];
  int _currentIndex = 0;
  bool _shuffle = false;
  RepeatMode _repeat = RepeatMode.off;

  // ── Favorites Logic ─────────────────────────────────────────────────────────
  final Set<String> _favorites = {};
  final ValueNotifier<Set<String>> favoritesNotifier = ValueNotifier({});

  // ── ValueNotifiers ──────────────────────────────────────────────────────────
  final ValueNotifier<AudioFile?> currentSong = ValueNotifier<AudioFile?>(null);
  final ValueNotifier<Duration> positionNotifier = ValueNotifier(Duration.zero);
  final ValueNotifier<Duration?> durationNotifier = ValueNotifier(null);
  final ValueNotifier<bool> playingNotifier = ValueNotifier(false);
  final ValueNotifier<bool> shuffleNotifier = ValueNotifier(false);
  final ValueNotifier<RepeatMode> repeatNotifier = ValueNotifier(RepeatMode.off);
  final ValueNotifier<List<AudioFile>> queueNotifier = ValueNotifier(const []);
  final ValueNotifier<double> volumeNotifier = ValueNotifier(0.8);

  // ── Streams ──────────────────────────────────────────────────────────────────
  late final Stream<Duration> positionStream;
  late final Stream<Duration?> durationStream;
  late final Stream<bool> playingStream;

  final StreamController<Duration> _positionController = StreamController<Duration>.broadcast();
  final StreamController<Duration?> _durationController = StreamController<Duration?>.broadcast();
  final StreamController<bool> _playingController = StreamController<bool>.broadcast();

  PlayerService._internal() {
    positionStream = _positionController.stream;
    durationStream = _durationController.stream;
    playingStream = _playingController.stream;

    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'nextTrack': skipToNext(); break;
        case 'previousTrack': skipToPrevious(); break;
        case 'playPause': playPause(); break;
        case 'seek':
          if (call.arguments != null && call.arguments['position'] != null) {
            _emitPosition(Duration(milliseconds: call.arguments['position'] as int));
          }
          break;
      }
    });

    _positionEventChannel.receiveBroadcastStream().listen((event) {
      if (event is Map) {
        final posMs = event['position'] as int?;
        final durMs = event['duration'] as int?;
        if (posMs != null) _emitPosition(Duration(milliseconds: posMs));
        if (durMs != null) _emitDuration(Duration(milliseconds: durMs));
      }
    });

    _stateEventChannel.receiveBroadcastStream().listen((event) {
      if (event is Map) {
        final playing = event['playing'] as bool?;
        final finished = event['finished'] as bool?;
        if (playing != null) _emitPlaying(playing);
        if (finished == true) _onTrackFinished();
      }
    });

    _loadFavorites();
  }

  // ── Favorites ────────────────────────────────────────────────────────────────
  Future<void> _loadFavorites() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/favorites.json');
      if (await file.exists()) {
        final List<dynamic> data = jsonDecode(await file.readAsString());
        _favorites.addAll(data.cast<String>());
        favoritesNotifier.value = Set.from(_favorites);
      }
    } catch (e) {
      debugPrint('PlayerService: error loading favorites: $e');
    }
  }

  Future<void> toggleFavorite(String path) async {
    if (_favorites.contains(path)) {
      _favorites.remove(path);
    } else {
      _favorites.add(path);
    }
    favoritesNotifier.value = Set.from(_favorites);
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/favorites.json');
      await file.writeAsString(jsonEncode(_favorites.toList()));
    } catch (e) {
      debugPrint('PlayerService: error saving favorites: $e');
    }
  }

  bool isFavorite(String path) => _favorites.contains(path);

  // ── Emit Helpers ─────────────────────────────────────────────────────────────
  void _emitPosition(Duration pos) {
    if (positionNotifier.value != pos) {
      positionNotifier.value = pos;
      _positionController.add(pos);
    }
  }

  void _emitDuration(Duration dur) {
    if (durationNotifier.value != dur) {
      durationNotifier.value = dur;
      _durationController.add(dur);
    }
  }

  void _emitPlaying(bool playing) {
    if (playingNotifier.value != playing) {
      playingNotifier.value = playing;
      _playingController.add(playing);
    }
  }

  // ── Actions ──────────────────────────────────────────────────────────────────
  void toggleShuffle() {
    _shuffle = !_shuffle;
    shuffleNotifier.value = _shuffle;
    if (_shuffle) {
      _originalQueue = List.from(_queue);
      final current = _queue.isNotEmpty ? _queue[_currentIndex] : null;
      _queue.shuffle();
      if (current != null) {
        _queue.remove(current);
        _queue.insert(0, current);
        _currentIndex = 0;
      }
    } else {
      final current = currentSong.value;
      _queue = List.from(_originalQueue);
      if (current != null) {
        final idx = _queue.indexWhere((s) => s.path == current.path);
        if (idx >= 0) _currentIndex = idx;
      }
    }
    queueNotifier.value = List.from(_queue);
  }

  void cycleRepeat() {
    switch (_repeat) {
      case RepeatMode.off: _repeat = RepeatMode.all; break;
      case RepeatMode.all: _repeat = RepeatMode.one; break;
      case RepeatMode.one: _repeat = RepeatMode.off; break;
    }
    repeatNotifier.value = _repeat;
  }

  Future<void> playQueue(List<AudioFile> songs, {int initialIndex = 0}) async {
    _originalQueue = List.from(songs);
    _queue = List.from(songs);
    _currentIndex = initialIndex;
    queueNotifier.value = List.from(_queue);
    await _playCurrent();
  }

  Future<void> playFromQueue(int index) async {
    if (index < 0 || index >= _queue.length) return;
    _currentIndex = index;
    await _playCurrent();
  }

  Future<void> _playCurrent() async {
    if (_queue.isEmpty || _currentIndex < 0 || _currentIndex >= _queue.length) return;
    final song = _queue[_currentIndex];
    currentSong.value = song;
    _emitPosition(Duration.zero);
    try {
      await _channel.invokeMethod('play', {'path': song.path, 'title': song.title, 'artist': song.artist});
      _emitPlaying(true);
      await applyCurrentEQ();
      await setVolume(volumeNotifier.value);
    } catch (e) {
      debugPrint('PlayerService: error native play: $e');
    }
  }

  void _onTrackFinished() {
    if (_repeat == RepeatMode.one) {
      _playCurrent();
    } else if (_currentIndex < _queue.length - 1) {
      _currentIndex++;
      _playCurrent();
    } else if (_repeat == RepeatMode.all) {
      _currentIndex = 0;
      _playCurrent();
    } else {
      _emitPlaying(false);
    }
  }

  Future<void> playPause() async {
    try {
      if (playingNotifier.value) {
        await _channel.invokeMethod('pause');
        _emitPlaying(false);
      } else {
        await _channel.invokeMethod('resume');
        _emitPlaying(true);
      }
    } catch (e) {
      debugPrint('PlayerService: error native pause/resume: $e');
    }
  }

  Future<void> seek(Duration pos) async {
    try {
      _emitPosition(pos);
      await _channel.invokeMethod('seek', {'position': pos.inMilliseconds});
    } catch (e) {
      debugPrint('PlayerService: error native seek: $e');
    }
  }

  Future<void> setVolume(double volume) async {
    volumeNotifier.value = volume;
    try {
      await _channel.invokeMethod('setVolume', {'volume': volume});
    } catch (e) {
      debugPrint('PlayerService: error native volume: $e');
    }
  }

  void skipToNext() {
    if (_queue.isEmpty) return;
    if (_currentIndex < _queue.length - 1) {
      _currentIndex++;
      _playCurrent();
    } else if (_repeat == RepeatMode.all) {
      _currentIndex = 0;
      _playCurrent();
    }
  }

  void skipToPrevious() {
    if (_queue.isEmpty) return;
    if (positionNotifier.value.inSeconds > 3) {
      seek(Duration.zero);
    } else if (_currentIndex > 0) {
      _currentIndex--;
      _playCurrent();
    }
  }

  Future<void> updateEQ(List<Map<String, dynamic>> bands) async {
    try { await _channel.invokeMethod('updateEQ', {'bands': bands}); } catch (e) {}
  }

  Future<void> updatePreamp(double gain) async {
    try { await _channel.invokeMethod('updatePreamp', {'gain': gain}); } catch (e) {}
  }

  Future<void> applyCurrentEQ() async {
    double preamp = 0.0;
    List<Map<String, dynamic>> hw = [];
    for (var b in eqBands) {
      if (b['type'] == 'Preamp') preamp += (b['gain'] as num).toDouble();
      else hw.add(b);
    }
    await updatePreamp(preamp);
    await updateEQ(hw);
  }

  void dispose() {
    _positionController.close();
    _durationController.close();
    _playingController.close();
  }
}
