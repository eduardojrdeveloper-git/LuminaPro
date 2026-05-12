import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/player_service.dart';
import '../services/library_service.dart';
import '../main.dart' show LuminaColors;

class LyricsScreen extends StatefulWidget {
  final AudioFile song;
  const LyricsScreen({super.key, required this.song});

  @override
  State<LyricsScreen> createState() => _LyricsScreenState();
}

class _LyricsLine {
  final Duration time;
  final String text;
  _LyricsLine(this.time, this.text);
}

class _LyricsScreenState extends State<LyricsScreen> {
  final PlayerService _ps = PlayerService();
  bool _isLoading = true;
  String? _error;
  
  List<_LyricsLine>? _syncedLyrics;
  String? _plainLyrics;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchLyrics();
  }

  Future<void> _fetchLyrics() async {
    try {
      final artist = Uri.encodeComponent(widget.song.artist);
      final track = Uri.encodeComponent(widget.song.title);
      final url = Uri.parse('https://lrclib.net/api/get?artist_name=$artist&track_name=$track');
      
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['syncedLyrics'] != null && data['syncedLyrics'].toString().isNotEmpty) {
          _parseSyncedLyrics(data['syncedLyrics']);
        } else if (data['plainLyrics'] != null) {
          _plainLyrics = data['plainLyrics'];
        } else {
          _error = 'No lyrics found for this track.';
        }
      } else {
        _error = 'No lyrics found for this track.';
      }
    } catch (e) {
      _error = 'Failed to load lyrics: $e';
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _parseSyncedLyrics(String lrc) {
    final lines = lrc.split('\n');
    final parsed = <_LyricsLine>[];
    final regex = RegExp(r'\[(\d{2}):(\d{2})\.(\d{2,3})\](.*)');

    for (var line in lines) {
      final match = regex.firstMatch(line);
      if (match != null) {
        final min = int.parse(match.group(1)!);
        final sec = int.parse(match.group(2)!);
        final msStr = match.group(3)!;
        final ms = msStr.length == 2 ? int.parse(msStr) * 10 : int.parse(msStr);
        
        final duration = Duration(minutes: min, seconds: sec, milliseconds: ms);
        final text = match.group(4)!.trim();
        if (text.isNotEmpty) {
          parsed.add(_LyricsLine(duration, text));
        }
      }
    }
    
    if (parsed.isNotEmpty) {
      _syncedLyrics = parsed;
    } else {
      _plainLyrics = lrc;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return CupertinoPageScaffold(
      backgroundColor: isDark ? LuminaColors.bg0 : LuminaColors.lightBg0,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: (isDark ? LuminaColors.bg0 : LuminaColors.lightBg0).withOpacity(0.8),
        middle: Text('Lyrics: ${widget.song.title}'),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.chevron_down, color: LuminaColors.accent),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      child: SafeArea(
        child: _isLoading
            ? const Center(child: CupertinoActivityIndicator())
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(_error!, style: TextStyle(color: LuminaColors.labelSecondary, fontSize: 16), textAlign: TextAlign.center),
                    ),
                  )
                : _syncedLyrics != null
                    ? _buildSyncedLyrics()
                    : _buildPlainLyrics(),
      ),
    );
  }

  Widget _buildPlainLyrics() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Text(
        _plainLyrics!,
        style: const TextStyle(fontSize: 18, height: 1.6, fontWeight: FontWeight.w500),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildSyncedLyrics() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return ValueListenableBuilder<Duration>(
      valueListenable: _ps.positionNotifier,
      builder: (context, position, _) {
        // Find current active line
        int activeIndex = -1;
        for (int i = 0; i < _syncedLyrics!.length; i++) {
          if (position >= _syncedLyrics![i].time) {
            activeIndex = i;
          } else {
            break;
          }
        }

        // Auto-scroll logic (basic approach)
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients && activeIndex > 3) {
            final targetOffset = (activeIndex - 3) * 60.0; // Approximation of item height
            _scrollController.animateTo(
              targetOffset,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 64),
          itemCount: _syncedLyrics!.length,
          itemBuilder: (context, index) {
            final line = _syncedLyrics![index];
            final isActive = index == activeIndex;
            
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 250),
                style: TextStyle(
                  fontSize: isActive ? 26 : 22,
                  fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                  color: isActive 
                      ? (isDark ? Colors.white : Colors.black) 
                      : LuminaColors.labelSecondary.withOpacity(0.5),
                  height: 1.3,
                  fontFamily: 'Inter', // Ensure modern look
                ),
                child: Text(
                  line.text,
                  textAlign: TextAlign.left,
                ),
              ),
            );
          },
        );
      },
    );
  }
}
