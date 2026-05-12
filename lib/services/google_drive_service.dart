import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:metadata_god/metadata_god.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../main.dart' show extractCloudCoversNotifier;
import 'log_service.dart';
import 'library_service.dart';

class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _client.send(request..headers.addAll(_headers));
  }
}

class GoogleDriveService {
  static final GoogleDriveService _instance = GoogleDriveService._internal();
  factory GoogleDriveService() => _instance;

  GoogleDriveService._internal();

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: '1060456152789-njpej5einmvtheuk2574ckkgd798crfl.apps.googleusercontent.com',
    scopes: [
      drive.DriveApi.driveReadonlyScope,
    ],
  );

  GoogleSignInAccount? _currentUser;
  drive.DriveApi? _driveApi;

  /// Track already-indexed driveFileIds to prevent duplicates across scans.
  final Set<String> _indexedFileIds = {};

  Future<void> signIn() async {
    try {
      _currentUser = await _googleSignIn.signIn();
      if (_currentUser != null) {
        final headers = await _currentUser!.authHeaders;
        final client = GoogleAuthClient(headers);
        _driveApi = drive.DriveApi(client);
        LogService.log('Google Drive signed in successfully: ${_currentUser!.email}');
      }
    } catch (error) {
      LogService.log('Google Drive sign in failed: $error');
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    _currentUser = null;
    _driveApi = null;
    _indexedFileIds.clear();
    LogService.log('Google Drive signed out.');
  }

  bool get isSignedIn => _currentUser != null && _driveApi != null;

  /// Fetches a small chunk of the file to extract metadata without downloading everything.
  Future<AudioFile?> fetchMetadataHeader(drive.File driveFile, String folderName) async {
    if (!isSignedIn) return null;
    try {
      final dynamic media = await _driveApi!.files.get(
        driveFile.id!,
        downloadOptions: drive.DownloadOptions.fullMedia,
      );

      final List<int> headerBytes = [];
      int totalReceived = 0;
      const int maxHeaderSize = 5 * 1024 * 1024; // 5MB to ensure full FLAC/ID3 metadata blocks are captured

      await for (var chunk in (media.stream as Stream<List<int>>)) {
        headerBytes.addAll(chunk);
        totalReceived += chunk.length;
        if (totalReceived >= maxHeaderSize) break;
      }

      final tempDir = await getTemporaryDirectory();
      final ext = driveFile.name != null ? p.extension(driveFile.name!) : '.flac';
      final tempPath = p.join(tempDir.path, 'header_${driveFile.id}$ext');
      final tempFile = File(tempPath);
      await tempFile.writeAsBytes(headerBytes);

      final metadata = await MetadataGod.readMetadata(file: tempPath);
      await tempFile.delete();

      final dynamic safeMeta = metadata;
      int? sRate;
      int? bDepth;
      int? bRate;
      try { sRate = safeMeta.sampleRate?.toInt(); } catch (_) {}
      try { bDepth = safeMeta.bitDepth?.toInt(); } catch (_) {}
      try { bRate = safeMeta.bitrate?.toInt(); } catch (_) {}

      return AudioFile(
        path: driveFile.webContentLink ?? '',
        title: (metadata.title != null && metadata.title!.trim().isNotEmpty) ? metadata.title!.trim() : (driveFile.name?.replaceAll(RegExp(r'\.(flac|wav|mp3|m4a|aiff|aif)$', caseSensitive: false), '') ?? 'Unknown'),
        artist: metadata.artist?.trim() ?? 'GDrive',
        albumArtist: metadata.albumArtist?.trim() ?? metadata.artist?.trim() ?? 'GDrive',
        album: metadata.album?.trim() ?? folderName,
        genre: metadata.genre?.trim() ?? 'Cloud',
        coverArt: extractCloudCoversNotifier.value ? metadata.picture?.data : null,
        duration: metadata.durationMs != null ? Duration(milliseconds: metadata.durationMs!.toInt()) : null,
        sampleRate: sRate,
        bitDepth: bDepth,
        bitrate: bRate,
        format: driveFile.name?.split('.').last.toUpperCase() ?? 'FLAC',
        isLocal: false,
        driveFileId: driveFile.id,
        driveStreamUrl: driveFile.webContentLink,
      );
    } catch (e) {
      LogService.log('fetchMetadataHeader error: $e');
      return null;
    }
  }

  Future<Map<String, String>> getAuthHeaders() async {
    if (_currentUser == null) return {};
    return await _currentUser!.authHeaders;
  }

  // ── Temp Cache Management ─────────────────────────────────────────────────

  /// Returns the path where a cached stream file would live.
  Future<String> _cachePathFor(String fileId, String ext) async {
    final tempDir = await getTemporaryDirectory();
    return p.join(tempDir.path, 'stream_$fileId.$ext');
  }

  /// Check if a file is already cached in the temp directory.
  Future<String?> getCachedPath(String fileId, String ext) async {
    final path = await _cachePathFor(fileId, ext);
    if (await File(path).exists()) return path;
    return null;
  }

  /// Downloads the full file from Google Drive to the temp cache directory.
  /// Returns the local temp file path for playback.
  /// If the file is already cached, returns immediately.
  Future<String?> streamToTempCache(String fileId, String fileName) async {
    if (!isSignedIn) throw Exception('Not signed in');

    final ext = fileName.split('.').last.toLowerCase();
    final existing = await getCachedPath(fileId, ext);
    if (existing != null) {
      LogService.log('Stream cache HIT: $existing');
      return existing;
    }

    try {
      LogService.log('Stream cache MISS — downloading $fileId ($fileName)...');
      final dynamic media = await _driveApi!.files.get(
        fileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      );

      final cachePath = await _cachePathFor(fileId, ext);
      final file = File(cachePath);
      final sink = file.openWrite();

      await for (var chunk in (media.stream as Stream<List<int>>)) {
        sink.add(chunk);
      }
      await sink.flush();
      await sink.close();

      LogService.log('Stream cached to: $cachePath');
      return cachePath;
    } catch (e) {
      LogService.log('streamToTempCache error: $e');
      return null;
    }
  }

  /// Copies a cached temp file to the permanent Documents directory.
  /// Returns the permanent local path, or null on failure.
  Future<String?> promoteFromCache(String fileId, String fileName) async {
    if (!isSignedIn) throw Exception('Not signed in');

    final ext = fileName.split('.').last.toLowerCase();
    final cached = await getCachedPath(fileId, ext);

    if (cached != null) {
      // File is in cache — instant copy
      try {
        final docDir = await getApplicationDocumentsDirectory();
        final destPath = p.join(docDir.path, fileName);
        await File(cached).copy(destPath);
        LogService.log('Promoted from cache: $cached → $destPath');
        return destPath;
      } catch (e) {
        LogService.log('promoteFromCache copy error: $e');
        return null;
      }
    } else {
      // File not cached — download fresh to permanent storage
      return await downloadFile(fileId, fileName);
    }
  }

  /// Deletes ALL stream_* temp cache files. Called on app close.
  Future<void> clearTempCache() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final entities = await tempDir.list().toList();
      int count = 0;
      for (var entity in entities) {
        if (entity is File && p.basename(entity.path).startsWith('stream_')) {
          await entity.delete();
          count++;
        }
      }
      LogService.log('Cleared $count temp cache files.');
    } catch (e) {
      LogService.log('clearTempCache error: $e');
    }
  }

  // ── Metadata Extraction from Cached File ──────────────────────────────────

  /// Reads full metadata (tags, cover art, duration) from a cached temp file.
  /// Returns an updated AudioFile with rich metadata, or null on failure.
  Future<AudioFile?> extractMetadataFromCachedFile(String cachedPath, AudioFile original) async {
    try {
      final metadata = await MetadataGod.readMetadata(file: cachedPath);

      final dynamic safeMeta = metadata;
      int? sRate;
      int? bDepth;
      int? bRate;
      try { sRate = safeMeta.sampleRate?.toInt(); } catch (_) {}
      try { bDepth = safeMeta.bitDepth?.toInt(); } catch (_) {}
      try { bRate = safeMeta.bitrate?.toInt(); } catch (_) {}

      return AudioFile(
        path: original.path,
        title: (metadata.title != null && metadata.title!.trim().isNotEmpty)
            ? metadata.title!.trim()
            : original.title,
        artist: (metadata.artist != null && metadata.artist!.trim().isNotEmpty)
            ? metadata.artist!.trim()
            : original.artist,
        albumArtist: (metadata.albumArtist != null && metadata.albumArtist!.trim().isNotEmpty)
            ? metadata.albumArtist!.trim()
            : (metadata.artist != null && metadata.artist!.trim().isNotEmpty)
                ? metadata.artist!.trim()
                : original.albumArtist,
        album: (metadata.album != null && metadata.album!.trim().isNotEmpty)
            ? metadata.album!.trim()
            : original.album,
        genre: (metadata.genre != null && metadata.genre!.trim().isNotEmpty)
            ? metadata.genre!.trim()
            : original.genre,
        coverArt: metadata.picture?.data ?? original.coverArt,
        duration: metadata.durationMs != null
            ? Duration(milliseconds: metadata.durationMs!.toInt())
            : original.duration,
        sampleRate: sRate ?? original.sampleRate,
        bitDepth: bDepth ?? original.bitDepth,
        bitrate: bRate ?? original.bitrate,
        format: original.format,
        isLocal: false,
        driveFileId: original.driveFileId,
        driveStreamUrl: original.driveStreamUrl,
      );
    } catch (e) {
      LogService.log('extractMetadataFromCachedFile error: $e');
      return null;
    }
  }

  // ── Fast Indexing (filename/folder based, no download) ────────────────────

  /// Creates an AudioFile from Google Drive file metadata only (no download).
  /// Uses filename parsing for title and folder name for album.
  AudioFile _audioFileFromDriveMeta(drive.File driveFile, String folderName) {
    final rawName = driveFile.name ?? 'Unknown';
    final ext = rawName.split('.').last.toUpperCase();
    // Strip extension and track number prefix (e.g. "01 - ", "01. ", "1 ")
    String title = rawName.replaceAll(RegExp(r'\.(flac|wav|mp3|m4a|aiff|aif)$', caseSensitive: false), '');
    title = title.replaceFirst(RegExp(r'^\d+[\s.\-_]+'), '').trim();
    if (title.isEmpty) title = rawName;

    return AudioFile(
      path: driveFile.webContentLink ?? '',
      title: title,
      artist: folderName,
      albumArtist: folderName,
      album: folderName,
      genre: 'Cloud',
      format: ext,
      isLocal: false,
      driveFileId: driveFile.id,
      driveStreamUrl: driveFile.webContentLink,
    );
  }

  Future<List<drive.File>> listContents({String parentId = 'root'}) async {
    if (!isSignedIn) throw Exception('Not signed in');
    try {
      final fileList = await _driveApi!.files.list(
        q: "'$parentId' in parents and trashed=false and (mimeType='application/vnd.google-apps.folder' or mimeType contains 'audio/' or name contains '.flac' or name contains '.wav' or name contains '.m4a' or name contains '.mp3')",
        spaces: 'drive',
        $fields: 'files(id, name, mimeType, webContentLink, size)',
        orderBy: 'folder, name',
      );
      return fileList.files ?? [];
    } catch (e) {
      LogService.log('Google Drive listContents error: $e');
      return [];
    }
  }

  Future<List<AudioFile>> scanFoldersForFlacs(List<String> folderIds) async {
    if (!isSignedIn) throw Exception('Not signed in');

    WakelockPlus.enable(); // Prevent device from sleeping during long scans
    
    // Clear previously indexed IDs so re-scanning replaces data
    _indexedFileIds.clear();

    final List<AudioFile> allSongs = [];
    try {
      for (final id in folderIds) {
        final songs = await _scanRecursive(id, 'Cloud Folder');
        allSongs.addAll(songs);
      }
    } finally {
      WakelockPlus.disable(); // Allow device to sleep again
    }
    
    return allSongs;
  }

  Future<List<AudioFile>> _scanRecursive(String folderId, String folderName) async {
    final List<AudioFile> driveSongs = [];
    String? pageToken;
    try {
      LibraryService.indexCurrentFileNotifier.value = 'Scanning folder: $folderName...';
      
      // 1. Get audio files in current folder (fast — no file download)
      do {
        final fileList = await _driveApi!.files.list(
          q: "'$folderId' in parents and trashed=false and (mimeType contains 'audio/' or name contains '.flac' or name contains '.wav' or name contains '.m4a' or name contains '.mp3')",
          spaces: 'drive',
          $fields: 'nextPageToken, files(id, name, size, webContentLink, mimeType)',
          pageToken: pageToken,
        );
        for (var file in fileList.files ?? []) {
          final isAudio = file.mimeType?.startsWith('audio/') == true || 
                          file.name?.toLowerCase().endsWith('.flac') == true ||
                          file.name?.toLowerCase().endsWith('.wav') == true ||
                          file.name?.toLowerCase().endsWith('.mp3') == true ||
                          file.name?.toLowerCase().endsWith('.m4a') == true;
          
          if (isAudio && file.id != null) {
            // Skip duplicates (same driveFileId seen in this scan)
            if (_indexedFileIds.contains(file.id)) continue;
            _indexedFileIds.add(file.id!);

            LibraryService.indexCurrentFileNotifier.value = 'Extracting metadata: ${file.name}';
            
            // Use fetchMetadataHeader for real metadata (Title, Artist, etc.)
            final metaSong = await fetchMetadataHeader(file, folderName);
            driveSongs.add(metaSong ?? _audioFileFromDriveMeta(file, folderName));
          }
        }
        pageToken = fileList.nextPageToken;
      } while (pageToken != null);

      // 2. Recurse into subfolders
      final contents = await listContents(parentId: folderId);
      for (var item in contents) {
        if (item.mimeType == 'application/vnd.google-apps.folder') {
          final subSongs = await _scanRecursive(item.id!, item.name ?? 'Subfolder');
          driveSongs.addAll(subSongs);
        }
      }
    } catch (e) {
      LogService.log('Google Drive recursive scan error: $e');
    }
    return driveSongs;
  }

  /// Full download to permanent storage (Documents directory).
  Future<String?> downloadFile(String fileId, String fileName) async {
    if (!isSignedIn) throw Exception('Not signed in');
    try {
      // Use dynamic to avoid type conflicts with different versions of googleapis
      final dynamic media = await _driveApi!.files.get(
        fileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      );

      final dir = await getApplicationDocumentsDirectory();
      final savePath = p.join(dir.path, fileName);
      final file = File(savePath);
      final sink = file.openWrite();
      
      // The stream is typically Stream<List<int>>
      await (media.stream as Stream<List<int>>).forEach((chunk) {
        sink.add(chunk);
      });
      await sink.close();
      
      LogService.log('Google Drive file downloaded to $savePath');
      return savePath;
    } catch (e) {
      LogService.log('Google Drive download error: $e');
      return null;
    }
  }
}
