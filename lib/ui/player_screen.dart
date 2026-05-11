import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../services/player_service.dart';
import '../services/library_service.dart';
import '../main.dart' show LuminaColors, rotateArtworkNotifier;

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen>
    with TickerProviderStateMixin {
  late final AnimationController _artworkController;
  late final AnimationController _scaleController;
  late final Animation<double> _scaleAnim;

  final PlayerService _ps = PlayerService();

  @override
  void initState() {
    super.initState();

    _artworkController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    )..repeat();

    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
      value: 1.0,
    );
    _scaleAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeOutBack),
    );

    _ps.playingNotifier.addListener(_onPlayingChanged);
    if (!_ps.playingNotifier.value) _scaleController.value = 0.0; // Start small if paused
  }

  void _onPlayingChanged() {
    if (_ps.playingNotifier.value) {
      _scaleController.forward();
      _artworkController.repeat();
    } else {
      _scaleController.reverse();
      _artworkController.stop();
    }
  }

  @override
  void dispose() {
    _ps.playingNotifier.removeListener(_onPlayingChanged);
    _artworkController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ValueListenableBuilder<AudioFile?>(
      valueListenable: _ps.currentSong,
      builder: (context, song, _) {
        if (song == null) {
          return Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    CupertinoIcons.music_note,
                    size: 72,
                    color: LuminaColors.labelTertiary,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Not Playing',
                    style: TextStyle(
                      color: LuminaColors.labelSecondary,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Stack(
          children: [
            // ── Background Blur ──────────────────────────────────────────
            if (song.coverArt != null)
              Positioned.fill(
                child: Image.memory(song.coverArt!, fit: BoxFit.cover),
              ),
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                child: Container(
                  color: isDark
                      ? Colors.black.withOpacity(0.55)
                      : Colors.white.withOpacity(0.65),
                ),
              ),
            ),

            // ── Content ────────────────────────────────────────────────────
            SafeArea(
              child: Column(
                children: [
                  // Grab Handle / Top Title
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Container(
                      width: 36,
                      height: 5,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.black12,
                        borderRadius: BorderRadius.circular(2.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'NOW PLAYING',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                      color: LuminaColors.labelSecondary,
                    ),
                  ),
                  
                  // Artwork Area
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 50),
                        child: ValueListenableBuilder<bool>(
                          valueListenable: rotateArtworkNotifier,
                          builder: (_, isRotating, __) {
                            final Widget artworkImage = song.coverArt != null
                                ? Image.memory(
                                    song.coverArt!,
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    height: double.infinity,
                                  )
                                : _buildPlaceholderArt(isDark);

                            return ScaleTransition(
                              scale: _scaleAnim,
                              child: isRotating
                                  ? RotationTransition(
                                      turns: _artworkController,
                                      child: ClipOval(
                                        child: AspectRatio(
                                          aspectRatio: 1,
                                          child: artworkImage,
                                        ),
                                      ),
                                    )
                                  : Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(24),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.35),
                                            blurRadius: 40,
                                            offset: const Offset(0, 20),
                                          )
                                        ],
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(24),
                                        child: AspectRatio(
                                          aspectRatio: 1,
                                          child: artworkImage,
                                        ),
                                      ),
                                    ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),

                  // Info + Controls
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    song.title,
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white : Colors.black,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    song.artist,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      color: LuminaColors.labelSecondary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            GestureDetector(
                              onTap: () => _showMoreMenu(context, song),
                              child: const Icon(CupertinoIcons.ellipsis_circle, size: 26, color: LuminaColors.accent),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 32),
                        _SeekBar(playerService: _ps, isDark: isDark),
                        
                        const SizedBox(height: 24),
                        _Controls(playerService: _ps, isDark: isDark),
                        
                        const SizedBox(height: 40),
                        // Bottom Actions
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Icon(CupertinoIcons.hifispeaker, color: LuminaColors.labelSecondary, size: 22),
                            GestureDetector(
                              onTap: () => _showQueue(context),
                              child: const Icon(CupertinoIcons.list_bullet, color: LuminaColors.labelSecondary, size: 22),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPlaceholderArt(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? LuminaColors.bg2 : LuminaColors.lightBg2,
        shape: BoxShape.circle,
      ),
      child: const Center(
        child: Icon(CupertinoIcons.music_note, size: 80, color: LuminaColors.labelSecondary),
      ),
    );
  }

  // ... (Menus stay similar but with Cupertino icons)
  void _showMoreMenu(BuildContext context, AudioFile song) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(song.title),
        message: Text(song.artist),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Add to Favorites'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Show Album'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Share Song'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  void _showQueue(BuildContext context) {
    // Keep standard implementation for now but ensure Cupertino feel
  }
}

class _Controls extends StatelessWidget {
  final PlayerService playerService;
  final bool isDark;

  const _Controls({required this.playerService, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        ValueListenableBuilder<bool>(
          valueListenable: playerService.shuffleNotifier,
          builder: (_, shuffle, __) => GestureDetector(
            onTap: playerService.toggleShuffle,
            child: Icon(CupertinoIcons.shuffle, color: shuffle ? LuminaColors.accent : LuminaColors.labelSecondary, size: 22),
          ),
        ),
        GestureDetector(
          onTap: playerService.skipToPrevious,
          child: const Icon(CupertinoIcons.backward_fill, size: 38),
        ),
        ValueListenableBuilder<bool>(
          valueListenable: playerService.playingNotifier,
          builder: (_, isPlaying, __) => GestureDetector(
            onTap: playerService.playPause,
            child: Icon(isPlaying ? CupertinoIcons.pause_fill : CupertinoIcons.play_fill, size: 48),
          ),
        ),
        GestureDetector(
          onTap: playerService.skipToNext,
          child: const Icon(CupertinoIcons.forward_fill, size: 38),
        ),
        ValueListenableBuilder<RepeatMode>(
          valueListenable: playerService.repeatNotifier,
          builder: (_, repeat, __) {
            IconData icon = CupertinoIcons.repeat;
            if (repeat == RepeatMode.one) icon = CupertinoIcons.repeat_1;
            return GestureDetector(
              onTap: playerService.cycleRepeat,
              child: Icon(icon, color: repeat != RepeatMode.off ? LuminaColors.accent : LuminaColors.labelSecondary, size: 22),
            );
          },
        ),
      ],
    );
  }
}

class _SeekBar extends StatefulWidget {
  final PlayerService playerService;
  final bool isDark;
  const _SeekBar({required this.playerService, required this.isDark});

  @override
  State<_SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends State<_SeekBar> {
  double? _dragValue;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Duration?>(
      valueListenable: widget.playerService.durationNotifier,
      builder: (_, duration, __) {
        final total = (duration?.inMilliseconds ?? 1).toDouble();
        return ValueListenableBuilder<Duration>(
          valueListenable: widget.playerService.positionNotifier,
          builder: (_, position, __) {
            final current = (_dragValue ?? position.inMilliseconds.toDouble()).clamp(0.0, total);
            return Column(
              children: [
                CupertinoSlider(
                  value: current,
                  max: total,
                  onChanged: (v) => setState(() => _dragValue = v),
                  onChangeEnd: (v) {
                    widget.playerService.seek(Duration(milliseconds: v.toInt()));
                    setState(() => _dragValue = null);
                  },
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_fmt(Duration(milliseconds: current.toInt())), style: const TextStyle(fontSize: 12, color: LuminaColors.labelSecondary)),
                    Text('-${_fmt(Duration(milliseconds: (total - current).toInt()))}', style: const TextStyle(fontSize: 12, color: LuminaColors.labelSecondary)),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
