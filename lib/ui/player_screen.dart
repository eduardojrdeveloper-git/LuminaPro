import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';
import '../services/player_service.dart';
import '../services/library_service.dart';
import '../main.dart' show LuminaColors, rotateArtworkNotifier, showQualityInPlayerNotifier, showLyricsInPlayerNotifier;
import 'queue_screen.dart';
import 'lyrics_screen.dart';

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
      duration: const Duration(milliseconds: 350),
      value: 1.0,
    );
    _scaleAnim = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeOutBack),
    );

    _ps.playingNotifier.addListener(_onPlayingChanged);
    if (!_ps.playingNotifier.value) _scaleController.value = 0.0;
  }

  void _onPlayingChanged() {
    if (!mounted) return;
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
                  const SizedBox(height: 8),
                  const Text(
                    'Pick a song from your Library',
                    style: TextStyle(
                      color: LuminaColors.labelTertiary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            children: [
              // ── Blurred Background ─────────────────────────────────────────
              Positioned.fill(
                child: song.coverArt != null && song.coverArt!.isNotEmpty
                    ? Image.memory(song.coverArt!, fit: BoxFit.cover)
                    : Container(
                        color: isDark ? LuminaColors.bg1 : LuminaColors.lightBg2),
              ),
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 90, sigmaY: 90),
                  child: Container(
                    color: isDark
                        ? Colors.black.withOpacity(0.6)
                        : Colors.white.withOpacity(0.70),
                  ),
                ),
              ),

              // ── Content ────────────────────────────────────────────────────
              SafeArea(
                child: Column(
                  children: [
                    // ── Top handle area ──────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.only(top: 12, bottom: 4),
                      child: Container(
                        width: 36,
                        height: 5,
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withOpacity(0.2)
                              : Colors.black.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),

                    // ── "Now Playing" label ──────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        children: [
                          const Expanded(child: SizedBox()),
                          ValueListenableBuilder<bool>(
                            valueListenable: showLyricsInPlayerNotifier,
                            builder: (context, showLyrics, _) {
                              return Text(
                                showLyrics ? song.title : 'NOW PLAYING',
                                style: TextStyle(
                                  fontSize: showLyrics ? 14 : 11,
                                  fontWeight: showLyrics ? FontWeight.w800 : FontWeight.w700,
                                  letterSpacing: showLyrics ? 0.0 : 1.2,
                                  color: isDark
                                      ? Colors.white.withOpacity(showLyrics ? 0.9 : 0.5)
                                      : Colors.black.withOpacity(showLyrics ? 0.9 : 0.4),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              );
                            },
                          ),
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: Padding(
                                padding: const EdgeInsets.only(right: 24),
                                child: GestureDetector(
                                  onTap: () => _showMoreMenu(context, song),
                                  child: Icon(
                                    CupertinoIcons.ellipsis_circle,
                                    size: 24,
                                    color: isDark
                                        ? Colors.white.withOpacity(0.7)
                                        : Colors.black.withOpacity(0.5),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ── Artwork / Lyrics Area ──────────────────────────────────────────────
                    Expanded(
                      child: ValueListenableBuilder<bool>(
                        valueListenable: showLyricsInPlayerNotifier,
                        builder: (context, showLyrics, _) {
                          if (showLyrics) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                              child: LyricsView(song: song),
                            );
                          }

                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 36),
                              child: ValueListenableBuilder<bool>(
                                valueListenable: rotateArtworkNotifier,
                                builder: (_, isRotating, __) {
                                  final Widget artworkImage =
                                      song.coverArt != null && song.coverArt!.isNotEmpty
                                          ? Image.memory(
                                              song.coverArt!,
                                              fit: BoxFit.cover,
                                              width: double.infinity,
                                              height: double.infinity,
                                            )
                                          : _buildPlaceholderArt(isDark);

                                  return AspectRatio(
                                    aspectRatio: 1,
                                    child: Stack(
                                      children: [
                                        Positioned.fill(
                                          child: ScaleTransition(
                                            scale: _scaleAnim,
                                            child: isRotating
                                                ? RotationTransition(
                                                    turns: _artworkController,
                                                    child: ClipOval(
                                                      child: artworkImage,
                                                    ),
                                                  )
                                                : Container(
                                                    decoration: BoxDecoration(
                                                      borderRadius:
                                                          BorderRadius.circular(20),
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: Colors.black
                                                              .withOpacity(0.45),
                                                          blurRadius: 50,
                                                          offset: const Offset(0, 24),
                                                          spreadRadius: -4,
                                                        ),
                                                      ],
                                                    ),
                                                    child: ClipRRect(
                                                      borderRadius:
                                                          BorderRadius.circular(20),
                                                      child: artworkImage,
                                                    ),
                                                  ),
                                          ),
                                        ),
                                      ValueListenableBuilder<bool>(
                                        valueListenable: _ps.bufferingNotifier,
                                        builder: (_, isBuffering, __) {
                                          if (!isBuffering) return const SizedBox.shrink();
                                          return Positioned.fill(
                                            child: ScaleTransition(
                                              scale: _scaleAnim,
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  color: Colors.black.withOpacity(0.4),
                                                  borderRadius: BorderRadius.circular(isRotating ? 1000 : 20),
                                                ),
                                                child: const Center(
                                                  child: CupertinoActivityIndicator(radius: 20, color: Colors.white),
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                  );
                                },
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    // ── Controls Area ────────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 30),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 28),
                          // Title + Artist
                          ValueListenableBuilder<bool>(
                            valueListenable: showLyricsInPlayerNotifier,
                            builder: (context, showLyrics, _) {
                              if (showLyrics) return const SizedBox.shrink();
                              return Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          song.title,
                                          style: TextStyle(
                                            fontSize: 22,
                                            fontWeight: FontWeight.w700,
                                            color: isDark
                                                ? Colors.white
                                                : Colors.black,
                                            letterSpacing: -0.5,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                song.artist,
                                                style: const TextStyle(
                                                  fontSize: 18,
                                                  color: LuminaColors.accent,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            ValueListenableBuilder<bool>(
                                              valueListenable: showQualityInPlayerNotifier,
                                              builder: (ctx, show, _) {
                                                if (!show || song.format.isEmpty) return const SizedBox.shrink();
                                                return Container(
                                                  margin: const EdgeInsets.only(left: 8),
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: song.formatColor.withOpacity(0.2),
                                                    border: Border.all(color: song.formatColor.withOpacity(0.5)),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Text(
                                                    song.format.toUpperCase(), 
                                                    style: TextStyle(
                                                      color: song.formatColor,
                                                      fontSize: 9,
                                                      fontWeight: FontWeight.w800,
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                          ],
                                        ),
                                        ValueListenableBuilder<bool>(
                                          valueListenable: showQualityInPlayerNotifier,
                                          builder: (ctx, show, _) {
                                            if (!show || song.formatInfoOnly.isEmpty) return const SizedBox.shrink();
                                            return Padding(
                                              padding: const EdgeInsets.only(top: 4.0),
                                              child: Text(
                                                song.formatInfoOnly,
                                                style: TextStyle(
                                                  color: (isDark ? Colors.white : Colors.black).withOpacity(0.5),
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  // Heart / Favorite
                                  ValueListenableBuilder<Set<String>>(
                                    valueListenable: _ps.favoritesNotifier,
                                    builder: (context, favs, _) {
                                      final isFav = favs.contains(song.path);
                                      return GestureDetector(
                                        onTap: () => _ps.toggleFavorite(song),
                                        child: Icon(                                      isFav ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
                                          size: 26,
                                          color: isFav 
                                              ? LuminaColors.accent 
                                              : (isDark ? Colors.white.withOpacity(0.65) : Colors.black.withOpacity(0.4)),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              );
                            },
                          ),

                          const SizedBox(height: 28),
                          _SeekBar(playerService: _ps, isDark: isDark),

                          const SizedBox(height: 20),
                          _Controls(playerService: _ps, isDark: isDark),

                          const SizedBox(height: 24),
                          _VolumeSlider(isDark: isDark, playerService: _ps),

                          const SizedBox(height: 24),
                          // Bottom Row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              GestureDetector(
                                onTap: () => _showAudioRouting(context),
                                child: Icon(
                                  CupertinoIcons.hifispeaker,
                                  color: isDark
                                      ? Colors.white.withOpacity(0.55)
                                      : Colors.black.withOpacity(0.35),
                                  size: 20,
                                ),
                              ),
                              GestureDetector(
                                onTap: () => showLyricsInPlayerNotifier.value = !showLyricsInPlayerNotifier.value,
                                child: ValueListenableBuilder<bool>(
                                  valueListenable: showLyricsInPlayerNotifier,
                                  builder: (ctx, show, _) {
                                    return Icon(
                                      CupertinoIcons.quote_bubble,
                                      color: show 
                                          ? LuminaColors.accent 
                                          : (isDark ? Colors.white.withOpacity(0.55) : Colors.black.withOpacity(0.35)),
                                      size: 20,
                                    );
                                  },
                                ),
                              ),
                              GestureDetector(
                                onTap: () => _showQueue(context),
                                child: Icon(
                                  CupertinoIcons.list_bullet,
                                  color: isDark
                                      ? Colors.white.withOpacity(0.55)
                                      : Colors.black.withOpacity(0.35),
                                  size: 20,
                                ),
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
          ),
        );
      },
    );
  }

  Widget _buildPlaceholderArt(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [LuminaColors.bg2, LuminaColors.bg3]
              : [LuminaColors.lightBg2, LuminaColors.lightBg3],
        ),
      ),
      child: const Center(
        child: Icon(CupertinoIcons.music_note,
            size: 80, color: LuminaColors.labelSecondary),
      ),
    );
  }

  void _showMoreMenu(BuildContext context, AudioFile song) {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(song.title,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        message: Text(song.artist),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              _ps.toggleFavoriteByPath(song.path);
            },
            child: ValueListenableBuilder<Set<String>>(
              valueListenable: _ps.favoritesNotifier,
              builder: (_, favs, __) => Text(favs.contains(song.path) ? 'Unlove' : 'Love'),
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              Share.share('Check out ${song.title} by ${song.artist} on Lumina Pro!');
            },
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
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => const QueueScreen(),
    );
  }

  void _showLyrics(BuildContext context, AudioFile song) {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => LyricsScreen(song: song),
    );
  }

  void _showAudioRouting(BuildContext context) {
    const MethodChannel('com.luminapro/audio').invokeMethod('showRoutePicker');
  }
}

class _Controls extends StatelessWidget {
  final PlayerService playerService;
  final bool isDark;
  const _Controls({required this.playerService, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final baseColor = isDark ? Colors.white : Colors.black;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ValueListenableBuilder<bool>(
          valueListenable: playerService.shuffleNotifier,
          builder: (_, shuffle, __) => GestureDetector(
            onTap: playerService.toggleShuffle,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(CupertinoIcons.shuffle, color: shuffle ? LuminaColors.accent : baseColor.withOpacity(0.35), size: 22),
            ),
          ),
        ),
        GestureDetector(
          onTap: playerService.skipToPrevious,
          behavior: HitTestBehavior.opaque,
          child: Padding(padding: const EdgeInsets.all(4), child: Icon(CupertinoIcons.backward_fill, size: 36, color: baseColor)),
        ),
        ValueListenableBuilder<bool>(
          valueListenable: playerService.bufferingNotifier,
          builder: (_, isBuffering, __) => GestureDetector(
            onTap: isBuffering ? null : playerService.playPause,
            behavior: HitTestBehavior.opaque,
            child: ValueListenableBuilder<bool>(
              valueListenable: playerService.playingNotifier,
              builder: (_, isPlaying, __) => AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: isBuffering
                    ? const Padding(
                        padding: EdgeInsets.all(16),
                        child: CupertinoActivityIndicator(radius: 14),
                      )
                    : Icon(
                        isPlaying ? CupertinoIcons.pause_fill : CupertinoIcons.play_fill,
                        key: ValueKey(isPlaying),
                        size: 52,
                        color: isBuffering ? baseColor.withOpacity(0.3) : baseColor,
                      ),
              ),
            ),
          ),
        ),
        GestureDetector(
          onTap: playerService.skipToNext,
          behavior: HitTestBehavior.opaque,
          child: Padding(padding: const EdgeInsets.all(4), child: Icon(CupertinoIcons.forward_fill, size: 36, color: baseColor)),
        ),
        ValueListenableBuilder<RepeatMode>(
          valueListenable: playerService.repeatNotifier,
          builder: (_, repeat, __) {
            final icon = repeat == RepeatMode.one ? CupertinoIcons.repeat_1 : CupertinoIcons.repeat;
            return GestureDetector(
              onTap: playerService.cycleRepeat,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(icon, color: repeat != RepeatMode.off ? LuminaColors.accent : baseColor.withOpacity(0.35), size: 22),
              ),
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
  bool _dragging = false;
  @override
  Widget build(BuildContext context) {
    final baseColor = widget.isDark ? Colors.white : Colors.black;
    return ValueListenableBuilder<Duration?>(
      valueListenable: widget.playerService.durationNotifier,
      builder: (_, duration, __) {
        final total = (duration?.inMilliseconds ?? 1).toDouble();
        return ValueListenableBuilder<Duration>(
          valueListenable: widget.playerService.positionNotifier,
          builder: (_, position, __) {
            final current = (_dragValue ?? position.inMilliseconds.toDouble()).clamp(0.0, total);
            final progress = total > 0 ? current / total : 0.0;
            return Column(
              children: [
                SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 4,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                    activeTrackColor: baseColor,
                    inactiveTrackColor: baseColor.withOpacity(0.2),
                    thumbColor: Colors.white,
                    trackShape: const RoundedRectSliderTrackShape(),
                  ),
                  child: Slider(
                    value: progress.clamp(0.0, 1.0),
                    min: 0.0,
                    max: 1.0,
                    onChangeStart: (_) => setState(() => _dragging = true),
                    onChanged: (v) => setState(() => _dragValue = v * total),
                    onChangeEnd: (v) {
                      widget.playerService.seek(Duration(milliseconds: (v * total).toInt()));
                      setState(() { _dragValue = null; _dragging = false; });
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_fmt(Duration(milliseconds: current.toInt())), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: baseColor.withOpacity(0.5), fontFeatures: const [FontFeature.tabularFigures()])),
                      Text('-${_fmt(Duration(milliseconds: (total - current).toInt()))}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: baseColor.withOpacity(0.5), fontFeatures: const [FontFeature.tabularFigures()])),
                    ],
                  ),
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

class _HiddenThumbShape extends SliderComponentShape {
  const _HiddenThumbShape();
  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => Size.zero;
  @override
  void paint(PaintingContext context, Offset center, {required Animation<double> activationAnimation, required Animation<double> enableAnimation, required bool isDiscrete, required TextPainter labelPainter, required RenderBox parentBox, required SliderThemeData sliderTheme, required TextDirection textDirection, required double value, required double textScaleFactor, required Size sizeWithOverflow}) {}
}

class _VolumeSlider extends StatelessWidget {
  final bool isDark;
  final PlayerService playerService;
  const _VolumeSlider({required this.isDark, required this.playerService});

  @override
  Widget build(BuildContext context) {
    final baseColor = isDark ? Colors.white : Colors.black;
    return Row(
      children: [
        Icon(CupertinoIcons.volume_mute, color: baseColor.withOpacity(0.4), size: 16),
        Expanded(
          child: ValueListenableBuilder<double>(
            valueListenable: playerService.volumeNotifier,
            builder: (context, vol, _) {
              return SliderTheme(
                data: SliderThemeData(
                  trackHeight: 4,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                  activeTrackColor: baseColor,
                  inactiveTrackColor: baseColor.withOpacity(0.15),
                  thumbColor: Colors.white,
                ),
                child: Slider(
                  value: vol,
                  onChanged: (v) => playerService.setVolume(v),
                ),
              );
            },
          ),
        ),
        Icon(CupertinoIcons.volume_up, color: baseColor.withOpacity(0.4), size: 16),
      ],
    );
  }
}
