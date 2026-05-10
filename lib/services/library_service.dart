import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:metadata_god/metadata_god.dart';

class AudioFile {
  final String path;
  final String title;
  final String artist;
  final String album;
  final Uint8List? coverArt;
  final Duration? duration;
  final int? sampleRate;
  final int? bitDepth;
  final String format;

  AudioFile({
    required this.path,
    required this.title,
    this.artist = 'Unknown Artist',
    this.album = 'Unknown Album',
    this.coverArt,
    this.duration,
    this.sampleRate,
    this.bitDepth,
    this.format = '',
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
  static Future<List<AudioFile>> scanMusic() async {
    final List<AudioFile> songs = [];
    try {
      MetadataGod.initialize();
      final directory = await getApplicationDocumentsDirectory();
      final List<FileSystemEntity> entities =
          directory.listSync(recursive: true);

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
            String album = 'Unknown Album';
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
              if (metadata.album != null && metadata.album!.isNotEmpty) {
                album = metadata.album!;
              }
              if (metadata.picture != null) {
                coverArt = metadata.picture!.data;
              }
              if (metadata.durationMs != null) {
                duration = Duration(milliseconds: metadata.durationMs!.toInt());
              }
              if (metadata.sampleRate != null) {
                sampleRate = metadata.sampleRate!.toInt();
              }
              if (metadata.bitDepth != null) {
                bitDepth = metadata.bitDepth!.toInt();
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
                }
              }
            }

            songs.add(AudioFile(
              path: entity.path,
              title: title,
              artist: artist,
              album: album,
              coverArt: coverArt,
              duration: duration,
              sampleRate: sampleRate,
              bitDepth: bitDepth,
              format: format,
            ));
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

// ignore_for_file: avoid_print
void debugPrint(String msg) => print(msg);
