import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/googleapis_auth.dart' as auth;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
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
    LogService.log('Google Drive signed out.');
  }

  bool get isSignedIn => _currentUser != null && _driveApi != null;

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
    final List<AudioFile> allSongs = [];
    for (final id in folderIds) {
      final songs = await _scanRecursive(id, 'Cloud Folder');
      allSongs.addAll(songs);
    }
    return allSongs;
  }

  Future<List<AudioFile>> _scanRecursive(String folderId, String folderName) async {
    final List<AudioFile> driveSongs = [];
    String? pageToken;
    try {
      // 1. Get audio files in current folder
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
                          file.name?.toLowerCase().endsWith('.wav') == true;
          
          if (isAudio) {
            driveSongs.add(AudioFile(
              path: file.webContentLink ?? '',
              title: file.name?.replaceAll(RegExp(r'\.(flac|wav|mp3|m4a)$', caseSensitive: false), '') ?? 'Unknown',
              artist: 'Cloud',
              albumArtist: 'Cloud',
              album: folderName,
              genre: 'Cloud',
              format: file.name?.split('.').last.toUpperCase() ?? 'FLAC',
              isLocal: false,
              driveFileId: file.id,
              driveStreamUrl: file.webContentLink,
            ));
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
