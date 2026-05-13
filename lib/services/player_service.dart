import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'library_service.dart';
import 'log_service.dart';
import 'google_drive_service.dart';

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
    {'fc': 1000.0, 'gain': 0.0,  'q': 1.41, 'type': 'Preamp'},
    {'fc': 1000.0, 'gain': 0.0,  'q': 1.41, 'type': 'PK'},
  ];

  static const String ia500Config = '''
Preamp: -7.3 dB
Filter: ON LSC Fc 28 Hz Gain 2.2 dB Q 0.917
Filter: ON LS Fc 90 Hz Gain 5 dB
Filter: ON PK Fc 2335 Hz Gain -0.9 dB Q 1.414
Filter: ON PK Fc 2451 Hz Gain 0.5 dB Q 2.998
Filter: ON PK Fc 3596 Hz Gain -3 dB Q 2.133
Filter: ON PK Fc 4868 Hz Gain 1.6 dB Q 1.826
''';

  List<Map<String, dynamic>> parseApoContent(String content) {
    final List<Map<String, dynamic>> bands = [];
    final lines = content.split('\n');
    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty || line.startsWith('#')) continue;

      if (line.startsWith('Preamp:')) {
        final match = RegExp(r'Preamp:\s+([-\d.]+)\s*dB').firstMatch(line);
        if (match != null) {
          bands.add({
            'fc': 1000.0,
            'gain': double.tryParse(match.group(1)!) ?? 0.0,
            'q': 1.41,
            'type': 'Preamp'
          });
        }
      } else if (line.startsWith('Filter:')) {
        final isOn = line.contains(' ON ');
        if (!isOn) continue;

        String type = 'PK';
        if (line.contains(' LSC ') || line.contains(' LS ')) type = 'LSC';
        else if (line.contains(' HSC ') || line.contains(' HS ')) type = 'HSC';

        double fc = 1000.0;
        double gain = 0.0;
        double q = 1.0;

        final fcMatch = RegExp(r'Fc\s+([\d.]+)\s*Hz').firstMatch(line);
        if (fcMatch != null) fc = double.tryParse(fcMatch.group(1)!) ?? 1000.0;

        final gainMatch = RegExp(r'Gain\s+([-\d.]+)\s*dB').firstMatch(line);
        if (gainMatch != null) gain = double.tryParse(gainMatch.group(1)!) ?? 0.0;

        final qMatch = RegExp(r'Q\s+([\d.]+)\b').firstMatch(line);
        if (qMatch != null) q = double.tryParse(qMatch.group(1)!) ?? 1.0;

        bands.add({
          'fc': fc,
          'gain': gain,
          'q': q,
          'type': type,
        });
      }
    }
    return bands;
  }

  // ── Crossfade ────────────────────────────────────────────────────────────────
  double crossfadeDuration = 0.0;
  final ValueNotifier<bool> crossfadeEnabledNotifier = ValueNotifier(false);
  
  void toggleCrossfadeEnabled() {
    crossfadeEnabledNotifier.value = !crossfadeEnabledNotifier.value;
  }

  // ── Playback State ───────────────────────────────────────────────────────────
  List<AudioFile> _queue = [];
  List<AudioFile> _originalQueue = [];
  int _currentIndex = 0;
  bool _shuffle = false;
  RepeatMode _repeat = RepeatMode.off;

  // ── Favorites Logic ─────────────────────────────────────────────────────────
  final Set<String> _favorites = {};
  final ValueNotifier<Set<String>> favoritesNotifier = ValueNotifier({});

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final favs = prefs.getStringList('favorites_v1');
    if (favs != null) {
      _favorites.addAll(favs);
      favoritesNotifier.value = Set.from(_favorites);
    }
  }

  Future<void> _saveFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('favorites_v1', _favorites.toList());
  }

  // ── ValueNotifiers ──────────────────────────────────────────────────────────
  final ValueNotifier<AudioFile?> currentSong = ValueNotifier<AudioFile?>(null);
  final ValueNotifier<Duration> positionNotifier = ValueNotifier(Duration.zero);
  final ValueNotifier<Duration?> durationNotifier = ValueNotifier(null);
  final ValueNotifier<bool> playingNotifier = ValueNotifier(false);
  final ValueNotifier<bool> shuffleNotifier = ValueNotifier(false);
  final ValueNotifier<RepeatMode> repeatNotifier = ValueNotifier(RepeatMode.off);
  final ValueNotifier<List<AudioFile>> queueNotifier = ValueNotifier(const []);
  final ValueNotifier<double> volumeNotifier = ValueNotifier(0.8);
  final ValueNotifier<double> panNotifier = ValueNotifier(0.0);
  final ValueNotifier<bool> monoNotifier = ValueNotifier(false);
  final ValueNotifier<bool> invertLRNotifier = ValueNotifier(false);
  final ValueNotifier<bool> bufferingNotifier = ValueNotifier(false);
  final ValueNotifier<bool> eqEnabledNotifier = ValueNotifier(true);
  int selectedPresetIndex = 0; // Persistent preset index

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
    _loadFavorites();
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
      if (data is Map) {
        if (data['position'] != null) {
          final posMs = (data['position'] as num).toInt();
          _emitPosition(Duration(milliseconds: posMs));
        }
        if (data['duration'] != null) {
          final durMs = (data['duration'] as num).toInt();
          _emitDuration(Duration(milliseconds: durMs));
        }
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

  void _emitDuration(Duration? d) {
    durationNotifier.value = d;
    _durationController.add(d);
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

  void playQueue(List<AudioFile> songs, {int initialIndex = 0}) => 
      setQueue(songs, initialIndex: initialIndex);

  void setQueue(List<AudioFile> songs, {int initialIndex = 0}) {
    _originalQueue = List.from(songs);
    _queue = _shuffle ? (List.from(songs)..shuffle()) : List.from(songs);
    _currentIndex = initialIndex;
    queueNotifier.value = _queue;
    _playCurrent();
  }

  void addToQueue(AudioFile song) {
    _queue.add(song);
    _originalQueue.add(song);
    queueNotifier.value = List.from(_queue);
  }

  Future<void> _playCurrent() async {
    if (_queue.isEmpty || _currentIndex < 0 || _currentIndex >= _queue.length) return;
    final song = _queue[_currentIndex];
    LogService.log('Playing: ${song.title} from ${song.path}');

    currentSong.value = song;
    _emitPosition(Duration.zero);

    String playPath;

    if (song.isLocal) {
      // ── Local file ──
      if (!await File(song.path).exists()) {
        LogService.log('PlayerService: file not found: ${song.path}');
        _onTrackFinished(); // Skip to next
        return;
      }
      playPath = song.path;
    } else {
      // ── Cloud file: Stream directly ──
      if (song.driveFileId == null || song.driveStreamUrl == null) {
        LogService.log('PlayerService: cloud song has no URL, skipping');
        _onTrackFinished();
        return;
      }

      bufferingNotifier.value = true;
      LogService.log('PlayerService: preparing temp cache for ${song.title}...');

      final gdrive = GoogleDriveService();
      
      // Stop current playback before downloading
      
      final ext = song.format.isNotEmpty ? song.format.toLowerCase() : 'flac';
      final fileName = '${song.title}.$ext';
      final path = await gdrive.streamToTempCache(song.driveFileId!, fileName);
      
      if (path != null) {
        playPath = path;
      } else {
        LogService.log('Failed to cache stream for ${song.title}');
        bufferingNotifier.value = false;
        _onTrackFinished();
        return;
      }

      bufferingNotifier.value = false;

      // If missing cover art, try fetching it dynamically
      if (song.coverArt == null) {
        gdrive.extractMetadataAndCover(song.driveFileId!).then((meta) {
          if (meta != null && meta['coverArt'] != null) {
            final updated = song.copyWith(coverArt: meta['coverArt']);
            LibraryService.updateSongMetadata(song.driveFileId!, updated);
            if (currentSong.value?.driveFileId == song.driveFileId) {
              currentSong.value = updated;
            }
            for (int i = 0; i < _queue.length; i++) {
              if (_queue[i].driveFileId == song.driveFileId) {
                _queue[i] = updated;
              }
            }
            queueNotifier.value = List.from(_queue);
            LogService.log('Dynamically fetched cover art for: ${updated.title}');
            
            // Also update the native player's notification artwork if playing
            if (playingNotifier.value) {
              _channel.invokeMethod('updateCoverArt', {'coverArt': updated.coverArt});
            }
          }
        });
      }
    }

    try {
      await _channel.invokeMethod('play', {
        'path': playPath,
        'title': song.title,
        'artist': song.artist,
        'album': song.album,
        'coverArt': song.coverArt,
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

  /// After caching a cloud song, extract full metadata from the file and update the library.
  void _enrichMetadataInBackground(AudioFile song, String cachedPath) async {
    try {
      if (song.driveFileId == null) return;
      final gdrive = GoogleDriveService();
      final updated = await gdrive.extractMetadataFromCachedFile(cachedPath, song);
      if (updated != null) {
        LibraryService.updateSongMetadata(song.driveFileId!, updated);
        // Also update the current song notifier if it's still the same track
        if (currentSong.value?.driveFileId == song.driveFileId) {
          currentSong.value = updated;
        }
        // Update in queue too
        for (int i = 0; i < _queue.length; i++) {
          if (_queue[i].driveFileId == song.driveFileId) {
            _queue[i] = updated;
          }
        }
        queueNotifier.value = List.from(_queue);
        LogService.log('Enriched metadata for: ${updated.title} by ${updated.artist}');
      }
    } catch (e) {
      LogService.log('_enrichMetadataInBackground error: $e');
    }
  }

  /// Update the current playing song and queue seamlessly when a GDrive song is downloaded
  void promoteSongToLocal(String driveFileId, String localPath) {
    AudioFile promote(AudioFile s) {
      return AudioFile(
        path: localPath,
        title: s.title,
        artist: s.artist,
        albumArtist: s.albumArtist,
        album: s.album,
        genre: s.genre,
        coverArt: s.coverArt,
        duration: s.duration,
        sampleRate: s.sampleRate,
        bitDepth: s.bitDepth,
        bitrate: s.bitrate,
        format: s.format,
        isLocal: true,
        driveFileId: s.driveFileId,
      );
    }

    if (currentSong.value?.driveFileId == driveFileId) {
      currentSong.value = promote(currentSong.value!);
    }

    bool queueChanged = false;
    for (int i = 0; i < _queue.length; i++) {
      if (_queue[i].driveFileId == driveFileId) {
        _queue[i] = promote(_queue[i]);
        queueChanged = true;
      }
    }
    for (int i = 0; i < _originalQueue.length; i++) {
      if (_originalQueue[i].driveFileId == driveFileId) {
        _originalQueue[i] = promote(_originalQueue[i]);
      }
    }

    if (queueChanged) {
      queueNotifier.value = List.from(_queue);
    }
  }

  /// Download the current cloud song to permanent local storage.
  /// If cached, promotes from temp cache (instant). Otherwise downloads fresh.
  Future<String?> downloadCurrentToLocal() async {
    final song = currentSong.value;
    if (song == null || song.isLocal || song.driveFileId == null) return null;

    final gdrive = GoogleDriveService();

    return await gdrive.promoteFromCache(song);
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

  Future<void> setPan(double pan) async {
    panNotifier.value = pan;
    try {
      await _channel.invokeMethod('setPan', {'pan': pan});
    } catch (e) {
      LogService.log('Error setting pan: $e');
    }
  }

  Future<void> toggleMono() async {
    monoNotifier.value = !monoNotifier.value;
    try {
      await _channel.invokeMethod('setMono', {'mono': monoNotifier.value});
    } catch (e) {
      LogService.log('Error setting mono: $e');
    }
  }

  Future<void> toggleInvertLR() async {
    invertLRNotifier.value = !invertLRNotifier.value;
    try {
      await _channel.invokeMethod('setInvertLR', {'invert': invertLRNotifier.value});
    } catch (e) {
      LogService.log('Error setting invert LR: $e');
    }
  }

  void removeQueueItem(int index) {
    if (index >= 0 && index < _queue.length) {
      final item = _queue[index];
      _queue.removeAt(index);
      _originalQueue.remove(item);
      
      if (index < _currentIndex) {
        _currentIndex--;
      } else if (index == _currentIndex && _queue.isNotEmpty) {
        if (_currentIndex >= _queue.length) {
          _currentIndex = 0;
        }
      } else if (_queue.isEmpty) {
        _currentIndex = 0;
      }
      queueNotifier.value = List.from(_queue);
    }
  }

  void reorderQueue(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    if (oldIndex < 0 || oldIndex >= _queue.length || newIndex < 0 || newIndex >= _queue.length) return;

    final item = _queue.removeAt(oldIndex);
    _queue.insert(newIndex, item);
    
    if (_currentIndex == oldIndex) {
      _currentIndex = newIndex;
    } else if (oldIndex < _currentIndex && newIndex >= _currentIndex) {
      _currentIndex--;
    } else if (oldIndex > _currentIndex && newIndex <= _currentIndex) {
      _currentIndex++;
    }
    
    queueNotifier.value = List.from(_queue);
  }

  Future<void> setAudioOutput(String route) async {
    try {
      await _channel.invokeMethod('setAudioOutput', {'route': route});
      LogService.log('Audio output route set to: $route');
    } catch (e) {
      LogService.log('Failed to set audio output: $e');
    }
  }

  Future<Uint8List?> generateSpek(String path) async {
    try {
      final result = await _channel.invokeMethod('generateSpek', {'path': path});
      return result as Uint8List?;
    } catch (e) {
      LogService.log('Error generating Spek: $e');
      return null;
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
    _saveFavorites();
  }

  // For backward compatibility or if only path is available
  void toggleFavoriteByPath(String path) {
    if (_favorites.contains(path)) _favorites.remove(path);
    else _favorites.add(path);
    favoritesNotifier.value = Set.from(_favorites);
    _saveFavorites();
  }

  Future<void> updateEQ(List<Map<String, dynamic>> bands) async {
    try {
      final convertedBands = bands.map((b) {
        final q = (b['q'] as num).toDouble();
        final bandwidth = 2.0 / log(2.0) * _asinh(1.0 / (2.0 * q));
        return {
          ...b,
          'fc': (b['fc'] as num).toDouble(),
          'gain': (b['gain'] as num).toDouble(),
          'q': bandwidth.clamp(0.05, 5.0),
          'type': b['type'].toString(),
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
    if (!eqEnabledNotifier.value) {
      // If disabled, send flat EQ to native engine
      await updatePreamp(0.0);
      await updateEQ([]);
      return;
    }
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
