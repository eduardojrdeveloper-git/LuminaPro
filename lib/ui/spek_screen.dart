import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/player_service.dart';

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
        child: Center(
          child: _isLoading
              ? const CupertinoActivityIndicator(radius: 20, color: Colors.white)
              : _error != null
                  ? Text('Failed to generate Spek: $_error', style: const TextStyle(color: Colors.red))
                  : _spekData != null
                      ? InteractiveViewer(
                          minScale: 1.0,
                          maxScale: 4.0,
                          child: Image.memory(
                            _spekData!,
                            fit: BoxFit.contain,
                            width: double.infinity,
                            height: double.infinity,
                          ),
                        )
                      : const Text('No data', style: TextStyle(color: Colors.white)),
        ),
      ),
    );
  }
}
