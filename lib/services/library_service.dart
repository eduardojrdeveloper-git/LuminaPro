import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class AudioFile {
  final String path;
  final String title;
  final String artist;
  final String album;

  AudioFile({required this.path, required this.title, this.artist = 'Unknown', this.album = 'Unknown'});
}

class LibraryService {
  static Future<List<AudioFile>> scanMusic() async {
    List<AudioFile> songs = [];
    try {
      // Access the /Documents folder (visible in 3uTools)
      final directory = await getApplicationDocumentsDirectory();
      final List<FileSystemEntity> entities = directory.listSync(recursive: true);

      for (var entity in entities) {
        if (entity is File) {
          String ext = p.extension(entity.path).toLowerCase();
          if (ext == '.flac' || ext == '.wav' || ext == '.mp3' || ext == '.m4a') {
            // Basic metadata extraction from path/filename
            // Assuming Folder/Album/Artist/Song format or just Filename
            String fileName = p.basenameWithoutExtension(entity.path);
            
            // Try to guess artist/album from parent directories
            List<String> parts = p.split(entity.path);
            String album = 'Unknown Album';
            String artist = 'Unknown Artist';
            
            if (parts.length >= 3) {
              album = parts[parts.length - 2];
              artist = parts[parts.length - 3];
            }

            songs.add(AudioFile(
              path: entity.path,
              title: fileName,
              artist: artist,
              album: album,
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
