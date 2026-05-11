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

  Future<List<drive.File>> listFolders() async {
    if (!isSignedIn) throw Exception('Not signed in');
    try {
      final fileList = await _driveApi!.files.list(
        q: "mimeType='application/vnd.google-apps.folder' and trashed=false",
        spaces: 'drive',
        $fields: 'files(id, name)',
      );
      return fileList.files ?? [];
    } catch (e) {
      LogService.log('Google Drive listFolders error: $e');
      return [];
    }
  }

  Future<List<AudioFile>> scanFolderForFlacs(String folderId, String folderName) async {
    if (!isSignedIn) throw Exception('Not signed in');
    final List<AudioFile> driveSongs = [];
    String? pageToken;
    try {
      do {
        final fileList = await _driveApi!.files.list(
          q: "'$folderId' in parents and mimeType='audio/flac' and trashed=false",
          spaces: 'drive',
          $fields: 'nextPageToken, files(id, name, size, webContentLink)',
          pageToken: pageToken,
        );

        final files = fileList.files ?? [];
        for (var file in files) {
          driveSongs.add(
            AudioFile(
              path: file.webContentLink ?? '',
              title: file.name?.replaceAll('.flac', '') ?? 'Unknown',
              artist: 'Unknown Artist',
              albumArtist: 'Unknown Artist',
              album: folderName,
              genre: 'Google Drive',
              format: 'FLAC',
              isLocal: false,
              driveFileId: file.id,
              driveStreamUrl: file.webContentLink,
            ),
          );
        }
        pageToken = fileList.nextPageToken;
      } while (pageToken != null);
    } catch (e) {
      LogService.log('Google Drive scan error: $e');
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
