import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:metadata_god/metadata_god.dart';
import 'library_service.dart';
import 'log_service.dart';

class MusicBrainzService {
  static final MusicBrainzService _instance = MusicBrainzService._internal();
  factory MusicBrainzService() => _instance;
  MusicBrainzService._internal();

  final String _baseUrl = 'https://musicbrainz.org/ws/2';
  final String _userAgent = 'LuminaPro/1.1.0 ( support@luminapro.com )';

  Future<void> autoRepairLibrary(Function(String) onProgress) async {
    final allSongs = await LibraryService.scanMusic();
    
    // Filter for songs that likely need repair (Unknown Artist or Unknown Album)
    final toRepair = allSongs.where((s) {
      return s.isLocal && (
        s.artist == 'Unknown Artist' || 
        s.album == 'Unknown Album' || 
        s.artist == 'No Metadata' || 
        s.album == 'No Metadata'
      );
    }).toList();

    if (toRepair.isEmpty) {
      onProgress('No tracks found requiring repair.');
      return;
    }

    onProgress('Found ${toRepair.length} tracks to repair...');

    for (int i = 0; i < toRepair.length; i++) {
      final song = toRepair[i];
      onProgress('Repairing [${i + 1}/${toRepair.length}]: ${song.title}');

      try {
        final result = await _searchMusicBrainz(song.title, song.artist != 'Unknown Artist' ? song.artist : null);
        
        if (result != null) {
          await _applyMetadata(song.path, result);
          LogService.log('Successfully repaired metadata for: ${song.title}');
        } else {
          LogService.log('No MusicBrainz match found for: ${song.title}');
        }
      } catch (e) {
        LogService.log('Error repairing ${song.title}: $e');
      }

      // MusicBrainz API Rate Limit: 1 request per second
      await Future.delayed(const Duration(milliseconds: 1100));
    }

    // Force a library rescan to reflect changes
    await LibraryService.scanMusic(forceRescan: true);
    onProgress('Metadata repair process finished.');
  }

  Future<Map<String, dynamic>?> _searchMusicBrainz(String title, String? artist) async {
    String query = 'recording:"$title"';
    if (artist != null && artist != 'Unknown Artist' && artist != 'No Metadata') {
      query += ' AND artist:"$artist"';
    }

    final url = Uri.parse('$_baseUrl/recording?query=${Uri.encodeComponent(query)}&fmt=json');
    
    final response = await http.get(url, headers: {'User-Agent': _userAgent});

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List recordings = data['recordings'] ?? [];
      
      if (recordings.isNotEmpty) {
        final rec = recordings.first;
        final List artistCredits = rec['artist-credit'] ?? [];
        final List releases = rec['releases'] ?? [];
        
        return {
          'title': rec['title'],
          'artist': artistCredits.isNotEmpty ? artistCredits.first['name'] : 'Unknown Artist',
          'album': releases.isNotEmpty ? releases.first['title'] : 'Unknown Album',
          'genre': (rec['tags'] as List?)?.first['name'] ?? 'Music',
        };
      }
    }
    return null;
  }

  Future<void> _applyMetadata(String filePath, Map<String, dynamic> data) async {
    await MetadataGod.writeMetadata(
      file: filePath,
      metadata: Metadata(
        title: data['title'],
        artist: data['artist'],
        album: data['album'],
        albumArtist: data['artist'],
        genre: data['genre'],
      ),
    );
  }
}
