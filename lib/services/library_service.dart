import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:metadata_god/metadata_god.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'player_service.dart';
import 'log_service.dart';
import 'platform_bridge.dart';

class AudioFile {
  final String path;
  final String title;
  final String artist;
  final String albumArtist;
  final String album;
  final String genre;
  final Uint8List? coverArt;
  final Duration? duration;
  final int? sampleRate;
  final int? bitDepth;
  final int? bitrate; // in kbps
  final String format;
  final bool isLocal;
  final String? driveFileId;
  final String? driveStreamUrl;

  AudioFile({
    required this.path,
    required this.title,
    this.artist = 'Unknown Artist',
    this.albumArtist = 'Unknown Artist',
    this.album = 'Unknown Album',
    this.genre = 'Unknown Genre',
    this.coverArt,
    this.duration,
    this.sampleRate,
    this.bitDepth,
    this.bitrate,
    this.format = '',
    this.isLocal = true,
    this.driveFileId,
    this.driveStreamUrl,
  });

  /// e.g. "FLAC · 44.1kHz · 24-bit · 850 kbps"
  String get formatBadge {
    final parts = <String>[];
    if (format.isNotEmpty) parts.add(format.toUpperCase());
    if (sampleRate != null && sampleRate! > 0) {
      final khz = sampleRate! / 1000.0;
      parts.add('${khz % 1 == 0 ? khz.toInt() : khz.toStringAsFixed(1)}kHz');
    }
    if (bitDepth != null && bitDepth! > 0) parts.add('${bitDepth}-bit');
    if (bitrate != null && bitrate! > 0) parts.add('${bitrate} kbps');
    return parts.join(' · ');
  }

  String get formatInfoOnly {
    final parts = <String>[];
    if (sampleRate != null && sampleRate! > 0) {
      final khz = sampleRate! / 1000.0;
      parts.add('${khz % 1 == 0 ? khz.toInt() : khz.toStringAsFixed(1)}kHz');
    }
    if (bitDepth != null && bitDepth! > 0) parts.add('${bitDepth}-bit');
    if (bitrate != null && bitrate! > 0) parts.add('${bitrate} kbps');
    return parts.join(' · ');
  }

  Color get formatColor {
    final fmt = format.toUpperCase();
    if (fmt == 'FLAC') return const Color(0xFFFA233B);
    if (fmt == 'MP3') return const Color(0xFFFF9500);
    if (fmt == 'M4A' || fmt == 'AAC') return const Color(0xFF007AFF);
    if (fmt == 'WAV') return const Color(0xFF34C759);
    if (fmt == 'OGG') return const Color(0xFFAF52DE);
    if (fmt == 'ALAC') return const Color(0xFF5856D6);
    return const Color(0xFF8E8E93);
  }

  Map<String, dynamic> toJson() => {
    'path': path,
    'title': title,
    'artist': artist,
    'albumArtist': albumArtist,
    'album': album,
    'genre': genre,
    'durationMs': duration?.inMilliseconds,
    'sampleRate': sampleRate,
    'bitDepth': bitDepth,
    'bitrate': bitrate,
    'format': format,
    'isLocal': isLocal,
    'driveFileId': driveFileId,
    'driveStreamUrl': driveStreamUrl,
    // coverArt is skipped to save space in shared_preferences
  };

  factory AudioFile.fromJson(Map<String, dynamic> json) => AudioFile(
    path: json['path']?.toString() ?? '',
    title: json['title']?.toString() ?? 'Unknown',
    artist: json['artist']?.toString() ?? 'Unknown Artist',
    albumArtist: json['albumArtist']?.toString() ?? 'Unknown Artist',
    album: json['album']?.toString() ?? 'Unknown Album',
    genre: json['genre']?.toString() ?? 'Unknown',
    duration: json['durationMs'] != null ? Duration(milliseconds: (json['durationMs'] as num).toInt()) : null,
    sampleRate: json['sampleRate'] != null ? (json['sampleRate'] as num).toInt() : null,
    bitDepth: json['bitDepth'] != null ? (json['bitDepth'] as num).toInt() : null,
    bitrate: json['bitrate'] != null ? (json['bitrate'] as num).toInt() : null,
    format: json['format']?.toString() ?? '',
    isLocal: json['isLocal'] as bool? ?? false,
    driveFileId: json['driveFileId']?.toString(),
    driveStreamUrl: json['driveStreamUrl']?.toString(),
  );

  AudioFile copyWith({
    String? path,
    String? title,
    String? artist,
    String? albumArtist,
    String? album,
    String? genre,
    Uint8List? coverArt,
    Duration? duration,
    int? sampleRate,
    int? bitDepth,
    int? bitrate,
    String? format,
    bool? isLocal,
    String? driveFileId,
    String? driveStreamUrl,
  }) {
    return AudioFile(
      path: path ?? this.path,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      albumArtist: albumArtist ?? this.albumArtist,
      album: album ?? this.album,
      genre: genre ?? this.genre,
      coverArt: coverArt ?? this.coverArt,
      duration: duration ?? this.duration,
      sampleRate: sampleRate ?? this.sampleRate,
      bitDepth: bitDepth ?? this.bitDepth,
      bitrate: bitrate ?? this.bitrate,
      format: format ?? this.format,
      isLocal: isLocal ?? this.isLocal,
      driveFileId: driveFileId ?? this.driveFileId,
      driveStreamUrl: driveStreamUrl ?? this.driveStreamUrl,
    );
  }
}

class LibraryService {
  static bool _initialized = false;
  static List<String> _includePaths = [];
  static List<AudioFile> _driveSongs = [];

  static Future<void> initialize() async {
    if (_initialized) return;
    try {
      MetadataGod.initialize();
      final prefs = await SharedPreferences.getInstance();
      _includePaths = prefs.getStringList('include_paths') ?? [];
      
      // Load persisted drive songs
      final driveSongsJson = prefs.getString('drive_songs');
      if (driveSongsJson != null) {
        try {
          final List<dynamic> decoded = jsonDecode(driveSongsJson);
          _driveSongs = decoded.map((e) => AudioFile.fromJson(e as Map<String, dynamic>)).toList();
        } catch (e) {
          debugPrint('LibraryService: Failed to decode drive_songs: $e');
        }
      }

      // Load persisted local songs
      final localSongsJson = prefs.getString('local_songs');
      if (localSongsJson != null) {
        try {
          final List<dynamic> decoded = jsonDecode(localSongsJson);
          _localSongsCache = decoded.map((e) => AudioFile.fromJson(e as Map<String, dynamic>)).toList();
          if (_localSongsCache.isNotEmpty) _hasInitialScanCompleted = true;
        } catch (e) {
          debugPrint('LibraryService: Failed to decode local_songs: $e');
        }
      }
      
      final docDir = await getApplicationDocumentsDirectory();
      if (_includePaths.isEmpty) {
        _includePaths = [docDir.path];
      }

      // ── EXTENSION SYSTEM INITIALIZATION ─────────────────────────────────────
      final extDir = Directory('${docDir.path}/Extensions');
      if (!await extDir.exists()) await extDir.create(recursive: true);
      
      final dataDir = Directory('${docDir.path}/AppData');
      if (!await dataDir.exists()) await dataDir.create(recursive: true);
      
      final cacheDir = Directory('${docDir.path}/Cache');
      if (!await cacheDir.exists()) await cacheDir.create(recursive: true);

      await PlatformBridge.initExtensionSystem(extDir.path, dataDir.path);
      await PlatformBridge.initExtensionStore(cacheDir.path);
      
      // Use registry.json from project root (mocking for mobile if needed, 
      // but here we set the URL to a local placeholder or known repo)
      await PlatformBridge.setStoreRegistryUrl('https://raw.githubusercontent.com/eduardojrdeveloper-git/LuminaPro/main/registry.json');

      final installed = await PlatformBridge.getInstalledExtensions();
      if (installed.isEmpty) {
        debugPrint('LibraryService: Auto-installing extensions from registry...');
        final storeExts = await PlatformBridge.getStoreExtensions(forceRefresh: true);
        for (var ext in storeExts) {
          try {
            final extId = ext['id'];
            if (extId != null) {
              await PlatformBridge.downloadStoreExtension(extId, extDir.path);
            }
          } catch (e) {
            debugPrint('LibraryService: Failed to auto-install extension: $e');
          }
        }
        await PlatformBridge.loadExtensionsFromDir(extDir.path);
      }
      
      _initialized = true;
    } catch (e) {
      debugPrint('LibraryService: Initialization failed: $e');
    }
  }

  static Future<void> _saveDriveSongs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(_driveSongs.map((e) => e.toJson()).toList());
      await prefs.setString('drive_songs', encoded);
    } catch (e) {
      debugPrint('LibraryService: _saveDriveSongs error: $e');
    }
  }

  static Future<void> _saveLocalSongs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(_localSongsCache.map((e) => e.toJson()).toList());
      await prefs.setString('local_songs', encoded);
    } catch (e) {
      debugPrint('LibraryService: _saveLocalSongs error: $e');
    }
  }

  static Future<void> updateScanPaths(List<String> paths) async {
    _includePaths = paths;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('include_paths', paths);
    _hasInitialScanCompleted = false; // Force rescan next time
    libraryUpdateNotifier.value++; // Trigger UI update
  }

  static List<String> get scanPaths => List.unmodifiable(_includePaths);

  static final ValueNotifier<int> libraryUpdateNotifier = ValueNotifier(0);
  
  // ── Indexing Progress State ──
  static final ValueNotifier<bool> isIndexingNotifier = ValueNotifier(false);
  static final ValueNotifier<String> indexCurrentFileNotifier = ValueNotifier('');
  static final ValueNotifier<double> indexProgressNotifier = ValueNotifier(0.0);

  static void addDriveSongs(List<AudioFile> songs) {
    bool added = false;
    for (final song in songs) {
      if (song.driveFileId != null &&
          _driveSongs.any((s) => s.driveFileId == song.driveFileId)) {
        continue;
      }
      _driveSongs.add(song);
      added = true;
    }
    if (added) {
      _saveDriveSongs();
      libraryUpdateNotifier.value++;
    }
  }

  /// Adds a single cloud song and notifies the UI immediately, saving progressively to prevent data loss on crash.
  static void addDriveSongProgressive(AudioFile song) {
    if (song.driveFileId != null &&
        _driveSongs.any((s) => s.driveFileId == song.driveFileId)) {
      return;
    }
    _driveSongs.add(song);
    
    // Save every 10 songs to persist state against crashes
    if (_driveSongs.length % 10 == 0) {
      _saveDriveSongs();
    }
    
    libraryUpdateNotifier.value++;
  }


  /// Manually trigger a save to SharedPreferences (e.g. after a progressive scan finishes).
  static Future<void> saveDriveSongsState() async {
    await _saveDriveSongs();
  }

  /// Remove all cloud songs. Call before re-scanning to avoid stale data.
  static void clearDriveSongs() {
    _driveSongs.clear();
    _saveDriveSongs();
    libraryUpdateNotifier.value++;
  }

  /// Remove a specific cloud song by driveFileId.
  static void removeDriveSong(String driveFileId) {
    _driveSongs.removeWhere((s) => s.driveFileId == driveFileId);
    _saveDriveSongs();
    libraryUpdateNotifier.value++;
  }

  /// Replace a cloud song's metadata in-place after streaming/caching.
  /// Returns true if the song was found and updated.
  static bool updateSongMetadata(String driveFileId, AudioFile updated) {
    final idx = _driveSongs.indexWhere((s) => s.driveFileId == driveFileId);
    if (idx >= 0) {
      _driveSongs[idx] = updated;
      libraryUpdateNotifier.value++;
      return true;
    }
    return false;
  }

  static Future<void> clearAllLocalCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('include_paths');
    _includePaths = [];
    _localSongsCache = [];
    _hasInitialScanCompleted = false;
    libraryUpdateNotifier.value++;
  }

  static Future<void> clearAllDriveCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('drive_songs');
    _driveSongs = [];
    libraryUpdateNotifier.value++;
  }

  static Future<void> clearFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('favorites_v1');
    PlayerService().clearFavoritesLocal();
  }

  static bool _hasInitialScanCompleted = false;
  static List<AudioFile> _localSongsCache = [];
  static bool _isBackgroundIndexing = false;

  static Future<List<AudioFile>> scanMusic({bool forceRescan = false}) async {
    final List<AudioFile> songs = [];
    songs.addAll(_driveSongs);

    try {
      await initialize();
      
      if (_hasInitialScanCompleted && !forceRescan) {
        songs.addAll(_localSongsCache);
        _applyDeduplicationAndSort(songs);
        return songs;
      }
      
      final List<String> unorganizedFiles = [];
      final List<String> organizedFiles = [];
      final docDir = await getApplicationDocumentsDirectory();

      for (var path in _includePaths) {
        final dir = Directory(path);
        if (!await dir.exists()) continue;

        final List<FileSystemEntity> entities = await dir.list(recursive: true).toList();

        for (var entity in entities) {
          if (entity is File) {
            final ext = p.extension(entity.path).toLowerCase();
            if (['.flac', '.wav', '.mp3', '.m4a', '.aiff', '.aif'].contains(ext)) {
              if (entity.path.contains('${Platform.pathSeparator}GDrive${Platform.pathSeparator}') || entity.path.contains('${Platform.pathSeparator}Local${Platform.pathSeparator}')) {
                organizedFiles.add(entity.path);
              } else {
                unorganizedFiles.add(entity.path);
              }
            }
          }
        }
      }

      // Process unorganized files sequentially so we don't hold up forever
      if (unorganizedFiles.isNotEmpty) {
        isIndexingNotifier.value = true;
        MetadataGod.initialize();
        
        final Set<String> dirsToClean = {};

        for (int i = 0; i < unorganizedFiles.length; i++) {
          final filePath = unorganizedFiles[i];
          final file = File(filePath);
          indexCurrentFileNotifier.value = 'Organizing: ${p.basename(filePath)}';
          
          String album = 'Unknown Album';
          String artist = 'Unknown Artist';
          try {
            final metadata = await MetadataGod.readMetadata(file: filePath);
            if (metadata.albumArtist != null && metadata.albumArtist!.trim().isNotEmpty) {
              artist = metadata.albumArtist!.trim();
            } else if (metadata.artist != null && metadata.artist!.trim().isNotEmpty) {
              artist = metadata.artist!.trim();
            }
            if (metadata.album != null && metadata.album!.trim().isNotEmpty) {
              album = metadata.album!.trim();
            }
          } catch (e) {
            // Fallback to Unknown if parsing fails
          }

          final String safeArtist = (artist.trim().isNotEmpty && artist != 'Unknown Artist' && artist != 'GDrive' && artist != 'Cloud') ? artist.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_') : 'No Metadata';
          final String safeAlbum = (album.trim().isNotEmpty && album != 'Unknown Album' && album != 'GDrive' && album != 'Cloud') ? album.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_') : 'No Metadata';
          final String fileName = p.basename(filePath).replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
          
          final destDir = Directory(p.join(docDir.path, 'Local', safeArtist, safeAlbum));
          if (!await destDir.exists()) {
            await destDir.create(recursive: true);
          }
          final destPath = p.join(destDir.path, fileName);
          try {
            final parentDir = file.parent.path;
            await file.copy(destPath);
            await file.delete();
            organizedFiles.add(destPath);
            
            // Mark original directory for cleanup if it's not the root docDir
            if (parentDir != docDir.path && !parentDir.contains('${Platform.pathSeparator}Local') && !parentDir.contains('${Platform.pathSeparator}GDrive')) {
              dirsToClean.add(parentDir);
            }
          } catch (e) {
            debugPrint('Failed to organize file $filePath: $e');
            organizedFiles.add(filePath); // Leave as is if fail to copy
          }
        }
        
        // Clean up empty directories from the outside (only bottom-up)
        final sortedDirs = dirsToClean.toList()..sort((a, b) => b.length.compareTo(a.length)); // Longest paths first
        for (final dirPath in sortedDirs) {
          try {
            final dir = Directory(dirPath);
            if (await dir.exists() && (await dir.list().isEmpty)) {
              await dir.delete();
            }
          } catch (e) {
            debugPrint('Failed to clean directory $dirPath: $e');
          }
        }

        isIndexingNotifier.value = false;
      }

      // Fast instant parse based on path
      final List<AudioFile> localSongs = [];
      for (final filePath in organizedFiles) {
        final parts = p.split(filePath);
        String artist = 'Unknown Artist';
        String album = 'Unknown Album';
        String title = p.basenameWithoutExtension(filePath);
        
        final localIdx = parts.lastIndexOf('Local');
        if (localIdx != -1 && localIdx + 2 < parts.length) {
            artist = parts[localIdx + 1];
            album = parts[localIdx + 2];
        } else {
            final gdriveIdx = parts.lastIndexOf('GDrive');
            if (gdriveIdx != -1 && gdriveIdx + 2 < parts.length) {
                artist = parts[gdriveIdx + 1];
                album = parts[gdriveIdx + 2];
            }
        }

        final ext = p.extension(filePath).toLowerCase();
        final format = ext.replaceFirst('.', '').toUpperCase();

        localSongs.add(AudioFile(
          path: filePath,
          title: title,
          artist: artist,
          albumArtist: artist,
          album: album,
          format: format,
          isLocal: true,
        ));
      }

      _localSongsCache = localSongs;
      _hasInitialScanCompleted = true;
      
      songs.addAll(_localSongsCache);

      // Start background metadata extraction progressively
      _startBackgroundMetadataExtraction();

    } catch (e) {
      debugPrint('LibraryService: scan error: $e');
    }

    _applyDeduplicationAndSort(songs);
    return songs;
  }

  static void _applyDeduplicationAndSort(List<AudioFile> songs) {
    final localSignatures = songs.where((s) => s.isLocal).map((s) => '${s.title}_${s.albumArtist}').toSet();
    songs.removeWhere((s) => !s.isLocal && localSignatures.contains('${s.title}_${s.albumArtist}'));
    songs.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
  }

  static Future<void> _startBackgroundMetadataExtraction() async {
    if (_isBackgroundIndexing) return;
    _isBackgroundIndexing = true;
    
    isIndexingNotifier.value = true;
    int processed = 0;
    MetadataGod.initialize();
    
    for (int i = 0; i < _localSongsCache.length; i++) {
      final song = _localSongsCache[i];
      // Skip if we already extracted rich metadata (we can guess this if we have a duration, since instant parse doesn't set duration)
      if (song.duration != null) continue;
      
      indexCurrentFileNotifier.value = 'Indexing metadata: ${song.title}';
      
      try {
        final metadata = await MetadataGod.readMetadata(file: song.path);
        
        String title = song.title;
        String artist = song.artist;
        String albumArtist = song.albumArtist;
        String album = song.album;
        String genre = song.genre;
        Uint8List? coverArt;
        Duration? duration;
        int? sRate;
        int? bDepth;
        int? bRate;

        if (metadata.title != null && metadata.title!.trim().isNotEmpty) title = metadata.title!.trim();
        if (metadata.artist != null && metadata.artist!.trim().isNotEmpty) artist = metadata.artist!.trim();
        if (metadata.albumArtist != null && metadata.albumArtist!.trim().isNotEmpty) albumArtist = metadata.albumArtist!.trim();
        if (metadata.album != null && metadata.album!.trim().isNotEmpty) album = metadata.album!.trim();
        if (metadata.genre != null && metadata.genre!.trim().isNotEmpty) genre = metadata.genre!.trim();
        if (metadata.picture != null) coverArt = metadata.picture!.data;
        if (metadata.durationMs != null) duration = Duration(milliseconds: metadata.durationMs!.toInt());

        final dynamic safeMeta = metadata;
        try { sRate = safeMeta.sampleRate?.toInt(); } catch (_) {}
        try { bDepth = safeMeta.bitDepth?.toInt(); } catch (_) {}
        try { bRate = safeMeta.bitrate?.toInt(); } catch (_) {}

        _localSongsCache[i] = song.copyWith(
          title: title,
          artist: artist,
          albumArtist: albumArtist,
          album: album,
          genre: genre,
          coverArt: coverArt,
          duration: duration,
          sampleRate: sRate,
          bitDepth: bDepth,
          bitrate: bRate,
        );
        
        processed++;
        
        // Update progress notifier
        indexProgressNotifier.value = processed / _localSongsCache.length;

        // Save progressively and notify UI every 5 songs
        if (processed % 5 == 0 || i == _localSongsCache.length - 1) {
          _saveLocalSongs();
          libraryUpdateNotifier.value++;
        }
      } catch (e) {
        // Just keep the instant path-based metadata
      }
      
      // Yield to the event loop so the UI doesn't freeze
      await Future.delayed(const Duration(milliseconds: 5));
    }
    
    // Final save
    await _saveLocalSongs();
    
    isIndexingNotifier.value = false;
    indexProgressNotifier.value = 0;
    indexCurrentFileNotifier.value = '';
    _isBackgroundIndexing = false;
  }
}
