import 'dart:io';
import 'dart:typed_data';
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
    this.format = '',
    this.isLocal = true,
    this.driveFileId,
    this.driveStreamUrl,
  });

  /// e.g. "FLAC · 44.1kHz · 24-bit"
  String get formatBadge {
    final parts = <String>[];
    if (format.isNotEmpty) parts.add(format.toUpperCase());
    if (sampleRate != null) {
      final khz = sampleRate! / 1000.0;
      parts.add('${khz % 1 == 0 ? khz.toInt() : khz}kHz');
    }
    if (bitDepth != null && bitDepth! > 0) parts.add('${bitDepth}-bit');
    return parts.join(' · ');
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
      // To persist drive songs, we would normally serialize them.
      // For this implementation, we will rely on re-scanning if needed,
      // or we can just hold them in memory.
      
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

  static Future<void> updateScanPaths(List<String> paths) async {
    _includePaths = paths;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('include_paths', paths);
  }

  static List<String> get scanPaths => List.unmodifiable(_includePaths);

  static void addDriveSongs(List<AudioFile> songs) {
    _driveSongs.addAll(songs);
  }

  static Future<List<AudioFile>> scanMusic() async {
    final List<AudioFile> songs = [];
    songs.addAll(_driveSongs);

    try {
      await initialize();
      
      for (var path in _includePaths) {
        final dir = Directory(path);
        if (!await dir.exists()) continue;

        final List<FileSystemEntity> entities =
            await dir.list(recursive: true).toList();

        for (var entity in entities) {
          if (entity is File) {
            final ext = p.extension(entity.path).toLowerCase();
            if (ext == '.flac' ||
                ext == '.wav' ||
                ext == '.mp3' ||
                ext == '.m4a' ||
                ext == '.aiff' ||
                ext == '.aif') {
              String fileName = p.basenameWithoutExtension(entity.path);
              String title = fileName;
              String artist = 'Unknown Artist';
              String albumArtist = 'Unknown Artist';
              String album = 'Unknown Album';
              String genre = 'Unknown Genre';
              Uint8List? coverArt;
              Duration? duration;
              int? sampleRate;
              int? bitDepth;
              final format = ext.replaceFirst('.', '');

              try {
                final metadata =
                    await MetadataGod.readMetadata(file: entity.path);
                if (metadata.title != null && metadata.title!.isNotEmpty) {
                  title = metadata.title!;
                }
                if (metadata.artist != null && metadata.artist!.isNotEmpty) {
                  artist = metadata.artist!;
                }
                if (metadata.albumArtist != null && metadata.albumArtist!.isNotEmpty) {
                  albumArtist = metadata.albumArtist!;
                } else if (metadata.artist != null && metadata.artist!.isNotEmpty) {
                  albumArtist = metadata.artist!;
                }
                if (metadata.album != null && metadata.album!.isNotEmpty) {
                  album = metadata.album!;
                }
                if (metadata.genre != null && metadata.genre!.isNotEmpty) {
                  genre = metadata.genre!;
                }
                if (metadata.picture != null) {
                  coverArt = metadata.picture!.data;
                }
                if (metadata.durationMs != null) {
                  duration = Duration(milliseconds: metadata.durationMs!.toInt());
                }
              } catch (e) {
                debugPrint(
                    'LibraryService: metadata error for ${entity.path}: $e');
              }

              // Folder-structure fallback for artist/album tags
              if (artist == 'Unknown Artist' || album == 'Unknown Album') {
                final parts = p.split(entity.path);
                if (parts.length >= 3) {
                  if (album == 'Unknown Album') album = parts[parts.length - 2];
                  if (artist == 'Unknown Artist') {
                    artist = parts[parts.length - 3];
                    if (albumArtist == 'Unknown Artist') albumArtist = artist;
                  }
                }
              }

              songs.add(AudioFile(
                path: entity.path,
                title: title,
                artist: artist,
                albumArtist: albumArtist,
                album: album,
                genre: genre,
                coverArt: coverArt,
                duration: duration,
                sampleRate: sampleRate,
                bitDepth: bitDepth,
                format: format,
              ));
            }
          }
        }
      }
    } catch (e) {
      debugPrint('LibraryService: scan error: $e');
    }

    // Sort alphabetically by title by default
    songs.sort((a, b) => a.title.compareTo(b.title));
    return songs;
  }
}

void debugPrint(String msg) => LogService.log(msg);
