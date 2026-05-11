import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'library_service.dart';
import 'log_service.dart';

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

  // ── Audio Path Info ───────────────────────────────────────────────────────
  final ValueNotifier<Map<String, String>> audioPathNotifier = ValueNotifier({
    'Source': '---',
    'DSP': '---',
    'Output': '---',
  });

  PlayerService._internal() {
    positionStream = _positionController.stream;
    durationStream = _durationController.stream;
    playingStream = _playingController.stream;

    _channel.setMethodCallHandler((call) async {
      try {
        switch (call.method) {
          case 'nextTrack': skipToNext(); break;
          case 'previousTrack': skipToPrevious(); break;
          case 'playPause': playPause(); break;
          case 'audioPathUpdate':
            if (call.arguments is Map) {
              final args = Map<String, dynamic>.from(call.arguments);
              audioPathNotifier.value = {
                'Source': args['source']?.toString() ?? '---',
                'DSP': args['dsp']?.toString() ?? '---',
                'Output': args['output']?.toString() ?? '---',
              };
            }
            break;
          case 'seek':
            final args = call.arguments;
            if (args is Map && args['position'] != null) {
              final posMs = (args['position'] as num).toInt();
              _emitPosition(Duration(milliseconds: posMs));
            }
            break;
        }
      } catch (e) {
        LogService.log('PlayerService call error: $e');
      }
    });

    _positionEventChannel.receiveBroadcastStream().listen((data) {
      if (data is Map && data['position'] != null) {
        final posMs = (data['position'] as num).toInt();
        _emitPosition(Duration(milliseconds: posMs));
      }
    });

    _stateEventChannel.receiveBroadcastStream().listen((data) {
      if (data is Map) {
        if (data['playing'] != null) _emitPlaying(data['playing'] as bool);
        if (data['finished'] == true) _onTrackFinished();
      }
    });
  }

  void _emitPosition(Duration p) {
    positionNotifier.value = p;
    _positionController.add(p);
  }

  void _emitPlaying(bool p) {
    playingNotifier.value = p;
    _playingController.add(p);
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
      LogService.log('PlayerService: error native playPause: $e');
    }
  }

  Future<void> seek(Duration position) async {
    try {
      await _channel.invokeMethod('seek', {'position': position.inMilliseconds});
      _emitPosition(position);
    } catch (e) {
      LogService.log('PlayerService: error native seek: $e');
    }
  }

  // Support for playQueue (used in DetailScreen)
  void playQueue(List<AudioFile> songs, {int initialIndex = 0}) => 
      setQueue(songs, initialIndex: initialIndex);

  void setQueue(List<AudioFile> songs, {int initialIndex = 0}) {
    _originalQueue = List.from(songs);
    _queue = _shuffle ? (List.from(songs)..shuffle()) : List.from(songs);
    _currentIndex = initialIndex;
    queueNotifier.value = _queue;
    _playCurrent();
  }

  Future<void> _playCurrent() async {
    if (_queue.isEmpty || _currentIndex < 0 || _currentIndex >= _queue.length) return;
    final song = _queue[_currentIndex];
    LogService.log('Playing: ${song.title} from ${song.path}');
    
    // Check if file exists before trying to play
    if (!await File(song.path).exists()) {
      LogService.log('PlayerService: file not found: ${song.path}');
      _onTrackFinished(); // Skip to next
      return;
    }

    currentSong.value = song;
    _emitPosition(Duration.zero);
    try {
      await _channel.invokeMethod('play', {
        'path': song.path,
        'title': song.title,
        'artist': song.artist
      });
      _emitPlaying(true);
      
      // Small delay to let native engine initialize before applying EQ
      await Future.delayed(const Duration(milliseconds: 100));
      await applyCurrentEQ();
      await setVolume(volumeNotifier.value);
    } catch (e) {
      LogService.log('PlayerService: error native play: $e');
    }
  }

  void skipToNext() {
    if (_repeat == RepeatMode.one) {
      _playCurrent();
      return;
    }
    _currentIndex++;
    if (_currentIndex >= _queue.length) {
      if (_repeat == RepeatMode.all) {
        _currentIndex = 0;
      } else {
        _currentIndex = _queue.length - 1;
        _emitPlaying(false);
        return;
      }
    }
    _playCurrent();
  }

  void skipToPrevious() {
    _currentIndex--;
    if (_currentIndex < 0) {
      if (_repeat == RepeatMode.all) {
        _currentIndex = _queue.length - 1;
      } else {
        _currentIndex = 0;
      }
    }
    _playCurrent();
  }

  void _onTrackFinished() => skipToNext();

  Future<void> setVolume(double volume) async {
    volumeNotifier.value = volume;
    try {
      await _channel.invokeMethod('setVolume', {'volume': volume});
    } catch (e) {
      LogService.log('PlayerService: error native volume: $e');
    }
  }

  bool get shuffle => _shuffle;

  Future<void> toggleShuffle() async {
    _shuffle = !_shuffle;
    shuffleNotifier.value = _shuffle;
    if (_shuffle) {
      final current = currentSong.value;
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
        _currentIndex = _queue.indexOf(current);
      }
    }
    queueNotifier.value = _queue;
  }

  void cycleRepeat() => toggleRepeat();

  void toggleRepeat() {
    if (_repeat == RepeatMode.off) _repeat = RepeatMode.all;
    else if (_repeat == RepeatMode.all) _repeat = RepeatMode.one;
    else _repeat = RepeatMode.off;
    repeatNotifier.value = _repeat;
  }

  bool isFavorite(String path) => _favorites.contains(path);

  void toggleFavorite(AudioFile song) {
    if (_favorites.contains(song.path)) _favorites.remove(song.path);
    else _favorites.add(song.path);
    favoritesNotifier.value = Set.from(_favorites);
  }

  // For backward compatibility or if only path is available
  void toggleFavoriteByPath(String path) {
    if (_favorites.contains(path)) _favorites.remove(path);
    else _favorites.add(path);
    favoritesNotifier.value = Set.from(_favorites);
  }

  Future<void> updateEQ(List<Map<String, dynamic>> bands) async {
    try {
      // Convert Q to bandwidth (octaves) for AVAudioUnitEQ
      final convertedBands = bands.map((b) {
        final q = (b['q'] as num).toDouble();
        final bandwidth = 2.0 / log(2.0) * _asinh(1.0 / (2.0 * q));
        return {
          ...b,
          'q': bandwidth.clamp(0.05, 5.0),
        };
      }).toList();
      
      await _channel.invokeMethod('updateEQ', {'bands': convertedBands});
    } catch (e) {
      LogService.log('PlayerService: error updateEQ: $e');
    }
  }

  double _asinh(double x) => log(x + sqrt(x * x + 1));

  Future<void> updatePreamp(double gain) async {
    try { await _channel.invokeMethod('updatePreamp', {'gain': gain}); } catch (e) {
      LogService.log('PlayerService: error updatePreamp: $e');
    }
  }

  Future<void> updateEQFromContent(String content) async {
    try {
      await _channel.invokeMethod('updateEQFromContent', {'content': content});
      LogService.log('EQ Profile applied from content');
    } catch (e) {
      LogService.log('PlayerService: error updateEQFromContent: $e');
    }
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
