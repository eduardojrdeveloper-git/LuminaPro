import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/player_service.dart';
import '../services/library_service.dart';
import '../main.dart' show LuminaColors;

class SpekScreen extends StatefulWidget {
  final AudioFile song;
  const SpekScreen({super.key, required this.song});

  @override
  State<SpekScreen> createState() => _SpekScreenState();
}

class _SpekScreenState extends State<SpekScreen> {
  Uint8List? _spekData;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeRight,
      DeviceOrientation.landscapeLeft,
    ]);
    _generateSpek();
  }

  Future<void> _generateSpek() async {
    try {
      final data = await PlayerService().generateSpek(widget.song.path);
      if (mounted) {
        setState(() {
          _spekData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: Colors.black,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: Colors.black.withOpacity(0.5),
        middle: Text('Spek: ${widget.song.title}', style: const TextStyle(color: Colors.white)),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      child: SafeArea(
        child: _isLoading
            ? const Center(child: CupertinoActivityIndicator(radius: 20, color: Colors.white))
            : _error != null
                ? Center(child: Text('Failed to generate Spek: $_error', style: const TextStyle(color: Colors.red)))
                : _spekData != null
                    ? _buildSpekView()
                    : const Center(child: Text('No data', style: TextStyle(color: Colors.white))),
      ),
    );
  }

  Widget _buildSpekView() {
    return Container(
      color: const Color(0xFF1B1B1B), // Dark background typical of Spek
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 40, bottom: 30, top: 20, right: 10),
            child: InteractiveViewer(
              minScale: 1.0,
              maxScale: 4.0,
              child: Container(
                width: double.infinity,
                height: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white24, width: 1),
                ),
                child: Image.memory(
                  _spekData!,
                  fit: BoxFit.fill,
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: CustomPaint(
              painter: SpekOverlayPainter(song: widget.song),
            ),
          ),
        ],
      ),
    );
  }
}

class SpekOverlayPainter extends CustomPainter {
  final AudioFile song;

  SpekOverlayPainter({required this.song});

  @override
  void paint(Canvas canvas, Size size) {
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    // 1. Draw top metadata text
    final String filename = '${song.title}.${song.format.toLowerCase()}';
    final int sr = song.sampleRate ?? 44100;
    final int bits = song.bitDepth ?? 16;
    final int kbps = song.bitrate ?? ((sr * bits * 2) / 1000).round();
    final String info = '$filename  $sr Hz, $bits bit, 2 channels, $kbps kbps';

    textPainter.text = TextSpan(
      text: info,
      style: const TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'monospace'),
    );
    textPainter.layout();
    textPainter.paint(canvas, const Offset(45, 5));

    // Axis settings (accounting for the padding offsets)
    const double leftPad = 40;
    const double bottomPad = 30;
    const double topPad = 20;
    const double rightPad = 10;
    
    final double graphHeight = size.height - topPad - bottomPad;
    final double graphWidth = size.width - leftPad - rightPad;

    // 2. Draw Y-axis (Frequency in kHz)
    final double maxFreqKHz = (sr / 2) / 1000.0;
    final int ySteps = maxFreqKHz > 20 ? 11 : 6;
    
    for (int i = 0; i <= ySteps; i++) {
      final double freq = (maxFreqKHz / ySteps) * i;
      final double yPos = topPad + graphHeight - (i / ySteps) * graphHeight;
      
      textPainter.text = TextSpan(
        text: freq.toInt().toString(),
        style: const TextStyle(color: Colors.white70, fontSize: 10, fontFamily: 'monospace'),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(leftPad - textPainter.width - 5, yPos - textPainter.height / 2));
      
      // Draw tick
      canvas.drawLine(
        Offset(leftPad - 3, yPos), 
        Offset(leftPad, yPos), 
        Paint()..color = Colors.white54..strokeWidth = 1,
      );
    }
    
    // Y-axis label "kHz"
    textPainter.text = const TextSpan(
      text: 'kHz',
      style: TextStyle(color: Colors.white70, fontSize: 10, fontFamily: 'monospace'),
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(leftPad - textPainter.width - 5, topPad - 15));

    // 3. Draw X-axis (Time)
    final int durSecs = song.duration?.inSeconds ?? 0;
    if (durSecs > 0) {
      final int xSteps = 5;
      for (int i = 0; i <= xSteps; i++) {
        final int secs = (durSecs / xSteps * i).round();
        final String m = (secs ~/ 60).toString().padLeft(2, '0');
        final String s = (secs % 60).toString().padLeft(2, '0');
        
        final double xPos = leftPad + (i / xSteps) * graphWidth;
        
        textPainter.text = TextSpan(
          text: '$m:$s',
          style: const TextStyle(color: Colors.white70, fontSize: 10, fontFamily: 'monospace'),
        );
        textPainter.layout();
        textPainter.paint(canvas, Offset(xPos - textPainter.width / 2, size.height - bottomPad + 5));
        
        // Draw tick
        canvas.drawLine(
          Offset(xPos, size.height - bottomPad), 
          Offset(xPos, size.height - bottomPad + 3), 
          Paint()..color = Colors.white54..strokeWidth = 1,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
