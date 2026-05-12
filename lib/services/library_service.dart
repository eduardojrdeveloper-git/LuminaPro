import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:metadata_god/metadata_god.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'log_service.dart';

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
    path: json['path'] as String,
    title: json['title'] as String,
    artist: json['artist'] as String,
    albumArtist: json['albumArtist'] as String,
    album: json['album'] as String,
    genre: json['genre'] as String,
    duration: json['durationMs'] != null ? Duration(milliseconds: json['durationMs'] as int) : null,
    sampleRate: json['sampleRate'] as int?,
    bitDepth: json['bitDepth'] as int?,
    bitrate: json['bitrate'] as int?,
    format: json['format'] as String,
    isLocal: json['isLocal'] as bool? ?? false,
    driveFileId: json['driveFileId'] as String?,
    driveStreamUrl: json['driveStreamUrl'] as String?,
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
      
      // Default to documents directory if empty
      if (_includePaths.isEmpty) {
        final docDir = await getApplicationDocumentsDirectory();
        _includePaths = [docDir.path];
      }
      
      _initialized = true;
    } catch (e) {
      debugPrint('LibraryService: MetadataGod initialization failed: $e');
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

  static Future<void> updateScanPaths(List<String> paths) async {
    _includePaths = paths;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('include_paths', paths);
  }

  static List<String> get scanPaths => List.unmodifiable(_includePaths);

  static final ValueNotifier<int> libraryUpdateNotifier = ValueNotifier(0);
  
  // ── Indexing Progress State ──
  static final ValueNotifier<bool> isIndexingNotifier = ValueNotifier(false);
  static final ValueNotifier<String> indexCurrentFileNotifier = ValueNotifier('');
  static final ValueNotifier<double> indexProgressNotifier = ValueNotifier(0.0);

  static void addDriveSongs(List<AudioFile> songs) {
    for (final song in songs) {
      // Deduplicate by driveFileId — skip if already present
      if (song.driveFileId != null &&
          _driveSongs.any((s) => s.driveFileId == song.driveFileId)) {
        continue;
      }
      _driveSongs.add(song);
    }
    _saveDriveSongs();
    libraryUpdateNotifier.value++;
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

  static Future<List<AudioFile>> scanMusic() async {
    final List<AudioFile> songs = [];
    songs.addAll(_driveSongs);

    try {
      await initialize();
      
      final List<String> filesToProcess = [];
      for (var path in _includePaths) {
        final dir = Directory(path);
        if (!await dir.exists()) continue;

        final List<FileSystemEntity> entities = await dir.list(recursive: true).toList();

        for (var entity in entities) {
          if (entity is File) {
            final ext = p.extension(entity.path).toLowerCase();
            if (ext == '.flac' ||
                ext == '.wav' ||
                ext == '.mp3' ||
                ext == '.m4a' ||
                ext == '.aiff' ||
                ext == '.aif') {
              filesToProcess.add(entity.path);
            }
          }
        }
      }

      final List<AudioFile> localSongs = await Isolate.run(() async {
        MetadataGod.initialize();
        final List<AudioFile> isolateSongs = [];
        for (final filePath in filesToProcess) {
          final ext = p.extension(filePath).toLowerCase();
          final format = ext.replaceFirst('.', '').toUpperCase();
          String title = p.basenameWithoutExtension(filePath);
          String artist = 'Unknown Artist';
          String albumArtist = 'Unknown Artist';
          String album = 'Unknown Album';
          String genre = 'Unknown Genre';
          Uint8List? coverArt;
          Duration? duration;
          int? sampleRate;
          int? bitDepth;
          int? bitrate;

          try {
            final metadata = await MetadataGod.readMetadata(file: filePath);
            
            if (metadata.title != null && metadata.title!.trim().isNotEmpty) {
              title = metadata.title!.trim();
            }
            if (metadata.artist != null && metadata.artist!.trim().isNotEmpty) {
              artist = metadata.artist!.trim();
            }
            if (metadata.albumArtist != null && metadata.albumArtist!.trim().isNotEmpty) {
              albumArtist = metadata.albumArtist!.trim();
            } else if (artist != 'Unknown Artist') {
              albumArtist = artist;
            }
            if (metadata.album != null && metadata.album!.trim().isNotEmpty) {
              album = metadata.album!.trim();
            }
            if (metadata.genre != null && metadata.genre!.trim().isNotEmpty) {
              genre = metadata.genre!.trim();
            }
            if (metadata.picture != null) coverArt = metadata.picture!.data;
            if (metadata.durationMs != null) {
              duration = Duration(milliseconds: metadata.durationMs!.toInt());
            }
          } catch (e) {
            final parts = p.split(filePath);
            if (parts.length >= 3) {
              album = parts[parts.length - 2];
              artist = parts[parts.length - 3];
              albumArtist = artist;
            }
          }

          isolateSongs.add(AudioFile(
            path: filePath,
            title: title,
            artist: artist,
            albumArtist: albumArtist,
            album: album,
            genre: genre,
            coverArt: coverArt,
            duration: duration,
            sampleRate: sampleRate,
            bitDepth: bitDepth,
            bitrate: bitrate,
            format: format,
            isLocal: true,
          ));
        }
        return isolateSongs;
      });

      // Organize physical files
      final docDir = await getApplicationDocumentsDirectory();
      for (int i = 0; i < localSongs.length; i++) {
        final song = localSongs[i];
        final file = File(song.path);
        if (!song.path.contains('${Platform.pathSeparator}GDrive${Platform.pathSeparator}') && !song.path.contains('${Platform.pathSeparator}Local${Platform.pathSeparator}')) {
          // File is unorganized (probably dropped via iTunes)
          final String safeArtist = (song.albumArtist.trim().isNotEmpty && song.albumArtist != 'Unknown Artist' && song.albumArtist != 'GDrive' && song.albumArtist != 'Cloud') ? song.albumArtist.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_') : 'No Metadata';
          final String safeAlbum = (song.album.trim().isNotEmpty && song.album != 'Unknown Album' && song.album != 'GDrive' && song.album != 'Cloud') ? song.album.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_') : 'No Metadata';
          final String fileName = p.basename(song.path).replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
          
          final destDir = Directory(p.join(docDir.path, 'Local', safeArtist, safeAlbum));
          if (!await destDir.exists()) {
            await destDir.create(recursive: true);
          }
          final destPath = p.join(destDir.path, fileName);
          try {
            await file.copy(destPath);
            await file.delete();
            localSongs[i] = song.copyWith(path: destPath);
          } catch (e) {
            debugPrint('Failed to organize file ${song.path}: $e');
          }
        }
      }

      songs.addAll(localSongs);
    } catch (e) {
      debugPrint('LibraryService: scan error: $e');
    }

    // Deduplicate: If we have a local file, hide the GDrive version
    final localSignatures = songs.where((s) => s.isLocal).map((s) => '${s.title}_${s.albumArtist}').toSet();
    songs.removeWhere((s) => !s.isLocal && localSignatures.contains('${s.title}_${s.albumArtist}'));

    // Sort alphabetically by title case-insensitive
    songs.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    return songs;
  }
}
