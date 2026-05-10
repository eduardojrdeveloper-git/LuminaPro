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

  AudioFile({
    required this.path,
    required this.title,
    this.artist = 'Unknown Artist',
    this.album = 'Unknown Album',
    this.coverArt,
  });
}

class LibraryService {
  static Future<List<AudioFile>> scanMusic() async {
    List<AudioFile> songs = [];
    try {
      MetadataGod.initialize();
      final directory = await getApplicationDocumentsDirectory();
      final List<FileSystemEntity> entities = directory.listSync(recursive: true);

      for (var entity in entities) {
        if (entity is File) {
          String ext = p.extension(entity.path).toLowerCase();
          if (ext == '.flac' || ext == '.wav' || ext == '.mp3' || ext == '.m4a') {
            String fileName = p.basenameWithoutExtension(entity.path);
            String title = fileName;
            String artist = 'Unknown Artist';
            String album = 'Unknown Album';
            Uint8List? coverArt;

            try {
              final metadata = await MetadataGod.readMetadata(entity.path);
              if (metadata.title != null) title = metadata.title!;
              if (metadata.artist != null) artist = metadata.artist!;
              if (metadata.album != null) album = metadata.album!;
              if (metadata.picture != null) {
                coverArt = metadata.picture!.data;
              }
            } catch (e) {
              print("Error reading metadata for ${entity.path}: $e");
            }

            // Fallback: If tags are missing, try extracting from folder structure
            if (artist == 'Unknown Artist' || album == 'Unknown Album') {
              List<String> parts = p.split(entity.path);
              if (parts.length >= 3) {
                if (album == 'Unknown Album') album = parts[parts.length - 2];
                if (artist == 'Unknown Artist') artist = parts[parts.length - 3];
              }
            }

            songs.add(AudioFile(
              path: entity.path,
              title: title,
              artist: artist,
              album: album,
              coverArt: coverArt,
            ));
          }
        }
      }
    } catch (e) {
      print("Error scanning music: $e");
    }
    return songs;
  }
}
