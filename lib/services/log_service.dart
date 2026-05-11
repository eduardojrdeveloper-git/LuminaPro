import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class LogService {
  static File? _logFile;
  static final List<String> _buffer = [];

  static Future<void> initialize() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      _logFile = File('${dir.path}/app_debug.log');
      
      // Clear old log if too big (> 5MB)
      if (await _logFile!.exists() && await _logFile!.length() > 5 * 1024 * 1024) {
        await _logFile!.delete();
      }

      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        log('CRASH: ${details.exception}\n${details.stack}');
      };

      PlatformDispatcher.instance.onError = (error, stack) {
        log('ASYNC_CRASH: $error\n$stack');
        return true;
      };

      log('--- APP START: ${DateTime.now()} ---');
    } catch (e) {
      debugPrint('LogService: Failed to init: $e');
    }
  }

  static void log(String message) {
    final timestamp = DateTime.now().toIso8601String();
    final entry = '[$timestamp] $message';
    
    // Always print to console
    debugPrint(entry);

    if (_logFile == null) {
      _buffer.add(entry);
      return;
    }

    _flushBuffer();
    _writeEntry(entry);
  }

  static void _writeEntry(String entry) {
    _logFile?.writeAsStringSync('$entry\n', mode: FileMode.append, flush: true);
  }

  static void _flushBuffer() {
    if (_buffer.isEmpty) return;
    for (final e in _buffer) _writeEntry(e);
    _buffer.clear();
  }

  static Future<String> getLogs() async {
    if (_logFile == null || !await _logFile!.exists()) return 'No logs found.';
    return await _logFile!.readAsString();
  }
}
