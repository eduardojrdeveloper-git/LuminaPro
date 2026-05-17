import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter/return_code.dart';
import 'package:fftea/fftea.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'log_service.dart';

class AudioQualityService {
  static final AudioQualityService _instance = AudioQualityService._internal();
  factory AudioQualityService() => _instance;
  AudioQualityService._internal();

  /// Analyzes a FLAC file to detect if it's a "fake" (upscaled lossy file).
  /// Returns a Map with the result.
  Future<Map<String, dynamic>> analyzeFlac(String filePath) async {
    try {
      LogService.log('Quality Check: Analyzing $filePath');
      
      final tempDir = await getTemporaryDirectory();
      final pcmPath = p.join(tempDir.path, 'quality_check.raw');
      
      // 1. Extract 10 seconds of PCM (mono, f32le, 44100Hz) from the middle (seek to 30s)
      final ffmpegCmd = '-ss 30 -t 10 -i "$filePath" -f f32le -ac 1 -ar 44100 -y "$pcmPath"';
      final session = await FFmpegKit.execute(ffmpegCmd);
      final returnCode = await session.getReturnCode();

      if (!ReturnCode.isSuccess(returnCode)) {
        throw Exception('FFmpeg failed to decode audio');
      }

      final file = File(pcmPath);
      final bytes = await file.readAsBytes();
      await file.delete();

      if (bytes.length < 4096 * 4) {
        throw Exception('Insufficient audio data extracted');
      }

      // 2. Convert bytes to float list
      final floatData = Float32List.view(bytes.buffer);
      
      // 3. Perform FFT analysis
      const int fftSize = 4096;
      final stft = STFT(fftSize, Window.hanning(fftSize));
      
      double highFreqEnergy = 0;
      double midFreqEnergy = 0;
      int frameCount = 0;

      stft.run(floatData, (chunk) {
        final magnitudes = chunk.magnitudes();
        
        // At 44100Hz, bins are ~10.77Hz wide.
        // Mid range: 5kHz - 15kHz -> bins ~465 to 1392
        // High range: 20kHz - 22.05kHz -> bins ~1857 to 2048
        
        double midSum = 0;
        for (int i = 465; i < 1392; i++) {
          midSum += magnitudes[i];
        }
        
        double highSum = 0;
        for (int i = 1857; i < magnitudes.length; i++) {
          highSum += magnitudes[i];
        }

        midFreqEnergy += midSum / (1392 - 465);
        highFreqEnergy += highSum / (magnitudes.length - 1857);
        frameCount++;
      });

      if (frameCount == 0) throw Exception('No frames processed');

      final avgMid = midFreqEnergy / frameCount;
      final avgHigh = highFreqEnergy / frameCount;

      // Convert to dB (approximate)
      final midDb = 20 * log(avgMid.clamp(1e-9, 1.0)) / ln10;
      final highDb = 20 * log(avgHigh.clamp(1e-9, 1.0)) / ln10;

      // Heuristic: If energy above 20kHz is extremely low compared to mid range, it's a fake.
      // MP3 320kbps typically has a steep drop around 20kHz.
      final diff = midDb - highDb;
      final bool isFake = diff > 45 || highDb < -75;

      LogService.log('Quality Result: Mid=${midDb.toStringAsFixed(1)}dB, High=${highDb.toStringAsFixed(1)}dB, Diff=${diff.toStringAsFixed(1)}dB');

      return {
        'isFake': isFake,
        'midDb': midDb,
        'highDb': highDb,
        'verdict': isFake ? 'Suspicious (Likely Upscaled)' : 'Genuine Lossless',
        'confidence': (diff.abs() / 10).clamp(0.0, 1.0),
      };

    } catch (e) {
      LogService.log('AudioQualityService error: $e');
      return {'error': e.toString()};
    }
  }
}
