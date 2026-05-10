import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../services/library_service.dart';

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
  double crossfadeDuration = 0.0; // seconds

  // ── Playback State ───────────────────────────────────────────────────────────
  List<AudioFile> _queue = [];
  List<AudioFile> _originalQueue = []; // for un-shuffling
  int _currentIndex = 0;

  bool _shuffle = false;
  RepeatMode _repeat = RepeatMode.off;

  // ── ValueNotifiers (reactive, no polling) ────────────────────────────────────
  final ValueNotifier<AudioFile?> currentSong = ValueNotifier<AudioFile?>(null);
  final ValueNotifier<Duration> positionNotifier = ValueNotifier(Duration.zero);
  final ValueNotifier<Duration?> durationNotifier = ValueNotifier(null);
  final ValueNotifier<bool> playingNotifier = ValueNotifier(false);
  final ValueNotifier<bool> shuffleNotifier = ValueNotifier(false);
  final ValueNotifier<RepeatMode> repeatNotifier =
      ValueNotifier(RepeatMode.off);
  final ValueNotifier<List<AudioFile>> queueNotifier =
      ValueNotifier(const []);

  // ── Reactive Streams (emit only on change, no polling) ───────────────────────
  late final Stream<Duration> positionStream;
  late final Stream<Duration?> durationStream;
  late final Stream<bool> playingStream;

  final StreamController<Duration> _positionController =
      StreamController<Duration>.broadcast();
  final StreamController<Duration?> _durationController =
      StreamController<Duration?>.broadcast();
  final StreamController<bool> _playingController =
      StreamController<bool>.broadcast();

  PlayerService._internal() {
    // Expose reactive streams directly from controllers
    positionStream = _positionController.stream;
    durationStream = _durationController.stream;
    playingStream = _playingController.stream;

    // Listen for native -> Dart method calls (lock screen controls etc.)
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
          if (call.arguments != null &&
              call.arguments['position'] != null) {
            final pos = Duration(milliseconds: call.arguments['position'] as int);
            _emitPosition(pos);
          }
          break;
      }
    });

    // Native position / duration events
    _positionEventChannel.receiveBroadcastStream().listen((event) {
      if (event is Map) {
        final posMs = event['position'] as int?;
        final durMs = event['duration'] as int?;
        if (posMs != null) _emitPosition(Duration(milliseconds: posMs));
        if (durMs != null) _emitDuration(Duration(milliseconds: durMs));
      }
    });

    // Native playback state events
    _stateEventChannel.receiveBroadcastStream().listen((event) {
      if (event is Map) {
        final playing = event['playing'] as bool?;
        final finished = event['finished'] as bool?;
        if (playing != null) _emitPlaying(playing);
        if (finished == true) _onTrackFinished();
      }
    });
  }

  // ── Emit helpers (deduplicated — only emit when value changes) ────────────────
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

  // ── Shuffle / Repeat ─────────────────────────────────────────────────────────
  bool get shuffle => _shuffle;
  RepeatMode get repeat => _repeat;

  void toggleShuffle() {
    _shuffle = !_shuffle;
    shuffleNotifier.value = _shuffle;
    if (_shuffle) {
      // Save original queue, shuffle keeping current song first
      _originalQueue = List.from(_queue);
      final current = _queue.isNotEmpty ? _queue[_currentIndex] : null;
      _queue.shuffle();
      if (current != null) {
        _queue.remove(current);
        _queue.insert(0, current);
        _currentIndex = 0;
      }
    } else {
      // Restore original order, find current song
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
      case RepeatMode.off:
        _repeat = RepeatMode.all;
        break;
      case RepeatMode.all:
        _repeat = RepeatMode.one;
        break;
      case RepeatMode.one:
        _repeat = RepeatMode.off;
        break;
    }
    repeatNotifier.value = _repeat;
  }

  // ── Queue ────────────────────────────────────────────────────────────────────
  List<AudioFile> get queue => List.unmodifiable(_queue);
  int get currentQueueIndex => _currentIndex;

  Future<void> playSong(AudioFile song) async {
    await playQueue([song], initialIndex: 0);
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
    if (_queue.isEmpty ||
        _currentIndex < 0 ||
        _currentIndex >= _queue.length) return;

    final song = _queue[_currentIndex];
    currentSong.value = song;
    _emitPosition(Duration.zero);

    try {
      await _channel.invokeMethod('play', {
        'path': song.path,
        'title': song.title,
        'artist': song.artist,
      });
      _emitPlaying(true);
      await applyCurrentEQ();
    } catch (e) {
      debugPrint('PlayerService: error invoking native play: $e');
    }
  }

  void _onTrackFinished() {
    switch (_repeat) {
      case RepeatMode.one:
        _playCurrent();
        break;
      case RepeatMode.all:
        if (_currentIndex < _queue.length - 1) {
          _currentIndex++;
        } else {
          _currentIndex = 0;
        }
        _playCurrent();
        break;
      case RepeatMode.off:
        if (_currentIndex < _queue.length - 1) {
          _currentIndex++;
          _playCurrent();
        } else {
          // End of queue: just stop
          _emitPlaying(false);
        }
        break;
    }
  }

  // ── Transport ────────────────────────────────────────────────────────────────
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
      debugPrint('PlayerService: error invoking native playPause: $e');
    }
  }

  Future<void> seek(Duration position) async {
    try {
      _emitPosition(position);
      await _channel.invokeMethod('seek', {
        'position': position.inMilliseconds,
      });
    } catch (e) {
      debugPrint('PlayerService: error invoking native seek: $e');
    }
  }

  void skipToNext() {
    if (_queue.isEmpty) return;
    if (_repeat == RepeatMode.one) {
      _playCurrent();
    } else if (_currentIndex < _queue.length - 1) {
      _currentIndex++;
      _playCurrent();
    } else if (_repeat == RepeatMode.all) {
      _currentIndex = 0;
      _playCurrent();
    } else {
      seek(Duration.zero);
      _emitPlaying(false);
    }
  }

  void skipToPrevious() {
    if (_queue.isEmpty) return;
    if (positionNotifier.value.inSeconds > 3) {
      seek(Duration.zero);
    } else if (_currentIndex > 0) {
      _currentIndex--;
      _playCurrent();
    } else {
      seek(Duration.zero);
    }
  }

  // ── EQ ───────────────────────────────────────────────────────────────────────
  Future<void> updateEQ(List<Map<String, dynamic>> bands) async {
    try {
      await _channel.invokeMethod('updateEQ', {'bands': bands});
    } catch (e) {
      debugPrint('PlayerService: error invoking native updateEQ: $e');
    }
  }

  Future<void> updatePreamp(double gain) async {
    try {
      await _channel.invokeMethod('updatePreamp', {'gain': gain});
    } catch (e) {
      debugPrint('PlayerService: error invoking native updatePreamp: $e');
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

  void dispose() {
    _positionController.close();
    _durationController.close();
    _playingController.close();
  }
}
