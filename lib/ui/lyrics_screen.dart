import 'dart:convert';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import '../services/player_service.dart';
import '../services/library_service.dart';
import '../main.dart' show LuminaColors;

class _LyricsLine {
  final Duration time;
  final String text;
  _LyricsLine(this.time, this.text);
}

class LyricsView extends StatefulWidget {
  final AudioFile song;
  const LyricsView({super.key, required this.song});

  @override
  State<LyricsView> createState() => _LyricsViewState();
}

class _LyricsViewState extends State<LyricsView> {
  final PlayerService _ps = PlayerService();
  bool _isLoading = true;
  String? _error;
  
  List<_LyricsLine>? _syncedLyrics;
  String? _plainLyrics;
  List<dynamic> _availableSources = [];
  int _currentSourceIndex = -1;
  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener = ItemPositionsListener.create();

  @override
  void initState() {
    super.initState();
    _fetchSourcesAndLyrics();
  }

  @override
  void didUpdateWidget(LyricsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.song.path != widget.song.path) {
      setState(() {
        _isLoading = true;
        _syncedLyrics = null;
        _plainLyrics = null;
        _error = null;
      });
      _fetchSourcesAndLyrics();
    }
  }

  Future<void> _fetchSourcesAndLyrics() async {
    try {
      final artist = Uri.encodeComponent(widget.song.artist);
      final track = Uri.encodeComponent(widget.song.title);
      final url = Uri.parse('https://lrclib.net/api/search?artist_name=$artist&track_name=$track');
      
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> results = json.decode(response.body);
        if (results.isNotEmpty) {
          _availableSources = results;
          
          // Check for saved source ID
          final prefs = await SharedPreferences.getInstance();
          final savedId = prefs.getString('lyrics_source_${widget.song.path}');
          
          int index = 0;
          if (savedId != null) {
            final foundIndex = results.indexWhere((r) => r['id'].toString() == savedId);
            if (foundIndex != -1) index = foundIndex;
          }
          
          _currentSourceIndex = index;
          _loadSource(results[index]);
        } else {
          _error = 'No lyrics found for this track.';
        }
      } else {
        _error = 'Failed to search lyrics.';
      }
    } catch (e) {
      _error = 'Error: $e';
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _loadSource(dynamic source) {
    if (source['syncedLyrics'] != null && source['syncedLyrics'].toString().isNotEmpty) {
      _parseSyncedLyrics(source['syncedLyrics']);
      _plainLyrics = null;
    } else if (source['plainLyrics'] != null) {
      _plainLyrics = source['plainLyrics'];
      _syncedLyrics = null;
    } else {
      _error = 'Selected source has no lyrics.';
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
    _syncedLyrics = parsed.isNotEmpty ? parsed : null;
    if (_syncedLyrics == null) _plainLyrics = lrc;
  }

  void _showSourceSelector() {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('Select Lyrics Source'),
        actions: List.generate(_availableSources.length, (i) {
          final s = _availableSources[i];
          final isSynced = s['syncedLyrics'] != null;
          return CupertinoActionSheetAction(
            onPressed: () async {
              Navigator.pop(ctx);
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('lyrics_source_${widget.song.path}', s['id'].toString());
              setState(() {
                _currentSourceIndex = i;
                _loadSource(s);
              });
            },
            child: Text(
              '${s['trackName']} (${isSynced ? 'Synced' : 'Plain'})',
              style: TextStyle(color: i == _currentSourceIndex ? LuminaColors.accent : null),
            ),
          );
        }),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CupertinoActivityIndicator());
    if (_error != null) return Center(child: Text(_error!, style: const TextStyle(color: LuminaColors.labelSecondary)));

    return Stack(
      children: [
        if (_syncedLyrics != null) _buildSyncedLyrics() else if (_plainLyrics != null) _buildPlainLyrics(),
        Positioned(
          top: 0,
          right: 0,
          child: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: _showSourceSelector,
            child: const Icon(CupertinoIcons.layers_alt, color: Colors.white54, size: 20),
          ),
        ),
      ],
    );
  }

  Widget _buildPlainLyrics() {
    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Text(
        _plainLyrics!,
        style: const TextStyle(fontSize: 22, height: 1.6, fontWeight: FontWeight.w600, color: Colors.white70),
        textAlign: TextAlign.left,
      ),
    );
  }

  Widget _buildSyncedLyrics() {
    return ValueListenableBuilder<Duration>(
      valueListenable: _ps.positionNotifier,
      builder: (context, position, _) {
        int activeIndex = -1;
        for (int i = 0; i < _syncedLyrics!.length; i++) {
          if (position >= _syncedLyrics![i].time) {
            activeIndex = i;
          } else {
            break;
          }
        }

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_itemScrollController.isAttached && activeIndex != -1) {
            _itemScrollController.scrollTo(
              index: activeIndex,
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
              alignment: 0.5, // This perfectly centers the item vertically regardless of dynamic heights
            );
          }
        });

        return ScrollablePositionedList.builder(
          itemScrollController: _itemScrollController,
          itemPositionsListener: _itemPositionsListener,
          padding: EdgeInsets.symmetric(vertical: MediaQuery.of(context).size.height / 2.5),
          itemCount: _syncedLyrics!.length,
          itemBuilder: (context, index) {
            final line = _syncedLyrics![index];
            final isActive = index == activeIndex;
            final isNear = (index - (activeIndex)).abs() <= 2;
            
            double opacity = 0.2;
            double blurSigma = 3.0; // Blur for distant lines
            
            if (isActive) {
              opacity = 1.0;
              blurSigma = 0.0;
            } else if (isNear) {
              opacity = 0.6;
              blurSigma = 1.5; // Slight blur for near lines
            }

            return Center(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 400),
                opacity: opacity,
                child: AnimatedPadding(
                  duration: const Duration(milliseconds: 400),
                  padding: EdgeInsets.symmetric(vertical: isActive ? 24.0 : 12.0),
                  child: ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        line.text,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: isActive ? 38 : 26,
                          fontWeight: isActive ? FontWeight.w900 : FontWeight.w700,
                          color: Colors.white,
                          height: 1.2,
                          shadows: isActive ? [
                            Shadow(color: LuminaColors.accent.withOpacity(0.8), blurRadius: 20),
                            Shadow(color: Colors.black.withOpacity(0.5), blurRadius: 10, offset: const Offset(0, 4))
                          ] : null,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// Keep the original screen for modal access if needed
class LyricsScreen extends StatelessWidget {
  final AudioFile song;
  const LyricsScreen({super.key, required this.song});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: Colors.black,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: Colors.black.withOpacity(0.8),
        middle: Text('Lyrics', style: const TextStyle(color: Colors.white)),
        leading: CupertinoButton(padding: EdgeInsets.zero, child: const Icon(CupertinoIcons.chevron_down), onPressed: () => Navigator.pop(context)),
      ),
      child: SafeArea(child: LyricsView(song: song)),
    );
  }
}
