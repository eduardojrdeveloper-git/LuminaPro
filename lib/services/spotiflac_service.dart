import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:metadata_god/metadata_god.dart';
import 'library_service.dart';
import 'log_service.dart';

class SpotiflacTrack {
  final String id;
  final String title;
  final String artist;
  final String album;
  final String? coverUrl;
  final String? isrc;
  final String? spotifyUrl;

  SpotiflacTrack({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    this.coverUrl,
    this.isrc,
    this.spotifyUrl,
  });

  factory SpotiflacTrack.fromJson(Map<String, dynamic> json) {
    return SpotiflacTrack(
      id: json['id'] ?? '',
      title: json['name'] ?? 'Unknown',
      artist: (json['artists'] as List?)?.map((e) => e['name']).join(', ') ?? 'Unknown',
      album: json['album']?['name'] ?? 'Unknown',
      coverUrl: (json['album']?['images'] as List?)?.first['url'],
      isrc: json['external_ids']?['isrc'],
      spotifyUrl: json['external_urls']?['spotify'],
    );
  }
}

class SpotiflacService {
  static final SpotiflacService _instance = SpotiflacService._internal();
  factory SpotiflacService() => _instance;
  SpotiflacService._internal();

  // Note: These are example public endpoints often used by SpotiFLAC.
  // In a production environment, you would use your own backend proxy.
  final String _searchApi = 'https://api.spotiflac.app/search'; 
  final String _downloadApi = 'https://api.spotiflac.app/download';

  Future<List<SpotiflacTrack>> search(String query) async {
    try {
      LogService.log('Searching SpotiFLAC for: $query');
      final response = await http.get(Uri.parse('$_searchApi?q=${Uri.encodeComponent(query)}'));
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final List<dynamic> items = data['items'] ?? [];
        return items.map((e) => SpotiflacTrack.fromJson(e)).toList();
      } else {
        throw Exception('Search failed: ${response.statusCode}');
      }
    } catch (e) {
      LogService.log('SpotiflacService search error: $e');
      return [];
    }
  }

  Future<String?> getDownloadUrl(String trackId) async {
    try {
      final response = await http.post(
        Uri.parse(_downloadApi),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'id': trackId, 'quality': 'FLAC'}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['url'];
      }
    } catch (e) {
      LogService.log('SpotiflacService getDownloadUrl error: $e');
    }
    return null;
  }

  Future<bool> downloadAndSave(SpotiflacTrack track, {Function(double)? onProgress}) async {
    try {
      final downloadUrl = await getDownloadUrl(track.id);
      if (downloadUrl == null) throw Exception('Could not resolve download URL');

      LogService.log('Downloading FLAC: ${track.title} from $downloadUrl');
      
      final client = http.Client();
      final request = http.Request('GET', Uri.parse(downloadUrl));
      final response = await client.send(request);

      if (response.statusCode != 200) throw Exception('Download failed: ${response.statusCode}');

      final contentLength = response.contentLength ?? 0;
      int downloaded = 0;
      final List<int> bytes = [];

      final tempDir = await getTemporaryDirectory();
      final tempPath = p.join(tempDir.path, 'download_${track.id}.flac');
      final tempFile = File(tempPath);
      final sink = tempFile.openWrite();

      await for (var chunk in response.stream) {
        sink.add(chunk);
        downloaded += chunk.length;
        if (contentLength > 0 && onProgress != null) {
          onProgress(downloaded / contentLength);
        }
      }
      await sink.close();
      client.close();

      // Apply metadata before moving to permanent storage
      LogService.log('Applying metadata to: $tempPath');
      
      Uint8List? coverBytes;
      if (track.coverUrl != null) {
        try {
          final coverRes = await http.get(Uri.parse(track.coverUrl!));
          if (coverRes.statusCode == 200) coverBytes = coverRes.bodyBytes;
        } catch (_) {}
      }

      await MetadataGod.writeMetadata(
        file: tempPath,
        metadata: Metadata(
          title: track.title,
          artist: track.artist,
          album: track.album,
          albumArtist: track.artist,
          picture: coverBytes != null ? Picture(data: coverBytes, mimeType: 'image/jpeg') : null,
        ),
      );

      // Promote to permanent storage
      final docDir = await getApplicationDocumentsDirectory();
      final safeArtist = track.artist.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
      final safeAlbum = track.album.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
      final fileName = '${track.title}.flac'.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
      
      final destDir = Directory(p.join(docDir.path, 'Local', safeArtist, safeAlbum));
      if (!await destDir.exists()) await destDir.create(recursive: true);
      
      final destPath = p.join(destDir.path, fileName);
      await tempFile.copy(destPath);
      await tempFile.delete();

      LogService.log('Downloaded and saved: $destPath');
      
      // Notify LibraryService to refresh
      await LibraryService.scanMusic(forceRescan: true);
      
      return true;
    } catch (e) {
      LogService.log('SpotiflacService downloadAndSave error: $e');
      return false;
    }
  }
}
