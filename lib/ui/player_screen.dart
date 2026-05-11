import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../services/player_service.dart';
import '../services/library_service.dart';
import '../main.dart' show LuminaColors;

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
      duration: const Duration(milliseconds: 300),
      value: 1.0,
    );
    _scaleAnim = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeOut),
    );

    _ps.playingNotifier.addListener(_onPlayingChanged);
    if (_ps.playingNotifier.value) _scaleController.value = 1.0;
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
                    CupertinoIcons.music_note_2,
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
                    'Select a song from your Library',
                    style: TextStyle(
                      color: LuminaColors.labelTertiary,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Stack(
          children: [
            // ── Blurred Background ─────────────────────────────────────────
            if (song.coverArt != null)
              Positioned.fill(
                child: Image.memory(song.coverArt!, fit: BoxFit.cover),
              ),
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
                child: Container(
                  color: isDark
                      ? Colors.black.withOpacity(0.65)
                      : Colors.white.withOpacity(0.72),
                ),
              ),
            ),

            // ── Content ────────────────────────────────────────────────────
            SafeArea(
              child: Column(
                children: [
                  // Top bar: title + more menu
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                    child: Row(
                      children: [
                        const Spacer(),
                        Column(
                          children: [
                            Text(
                              'NOW PLAYING',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.2,
                                color: isDark
                                    ? Colors.white60
                                    : Colors.black45,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => _showMoreMenu(context, song),
                          child: Icon(
                            CupertinoIcons.ellipsis_circle,
                            color: isDark ? Colors.white70 : Colors.black54,
                            size: 26,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Artwork with scale + rotation
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        child: ScaleTransition(
                          scale: _scaleAnim,
                          child: RotationTransition(
                            turns: _artworkController,
                            child: song.coverArt != null
                                ? ClipOval(
                                    child: Image.memory(
                                      song.coverArt!,
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                    ),
                                  )
                                : _buildPlaceholderArt(isDark),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Song info + format badge
                  Padding(
                    padding: const EdgeInsets.fromLTRB(28, 0, 28, 0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
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
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 3),
                              Text(
                                song.artist,
                                style: const TextStyle(
                                  fontSize: 17,
                                  color: LuminaColors.accent,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (song.formatBadge.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  song.formatBadge,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: LuminaColors.labelSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        // Favorite (placeholder)
                        GestureDetector(
                          onTap: () {},
                          child: Icon(
                            CupertinoIcons.heart,
                            color: isDark ? Colors.white60 : Colors.black45,
                            size: 24,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Progress Bar — fixed seekbar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _SeekBar(playerService: _ps, isDark: isDark),
                  ),

                  const SizedBox(height: 8),

                  // Main Controls (shuffle, prev, play/pause, next, repeat)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: _Controls(playerService: _ps, isDark: isDark),
                  ),

                  const SizedBox(height: 16),

                  // Bottom Row: AirPlay + Queue
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // AirPlay (placeholder)
                        Icon(
                          Icons.airplay,
                          color: isDark ? Colors.white54 : Colors.black45,
                          size: 24,
                        ),                        // Queue
                        GestureDetector(
                          onTap: () => _showQueue(context),
                          child: Icon(
                            CupertinoIcons.list_bullet_below_rectangle,
                            color: isDark ? Colors.white54 : Colors.black45,
                            size: 24,
                          ),
                        ),
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
      width: double.infinity,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDark ? LuminaColors.bg2 : LuminaColors.lightBg2,
      ),
      child: const AspectRatio(
        aspectRatio: 1,
        child: Icon(
          CupertinoIcons.music_note,
          size: 80,
          color: LuminaColors.labelSecondary,
        ),
      ),
    );
  }

  void _showMoreMenu(BuildContext context, AudioFile song) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            color: isDark
                ? LuminaColors.bg1.withOpacity(0.95)
                : Colors.white.withOpacity(0.95),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: LuminaColors.labelTertiary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 56,
                        height: 56,
                        child: song.coverArt != null
                            ? Image.memory(song.coverArt!, fit: BoxFit.cover)
                            : Container(
                                color: LuminaColors.bg2,
                                child: const Icon(CupertinoIcons.music_note,
                                    color: LuminaColors.labelSecondary),
                              ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(song.title,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 17,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          Text(song.artist,
                              style: const TextStyle(
                                  color: LuminaColors.accent),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          if (song.formatBadge.isNotEmpty)
                            Text(song.formatBadge,
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: LuminaColors.labelSecondary)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _MoreMenuItem(
                  icon: CupertinoIcons.waveform,
                  label: 'Equalizer (PEQ)',
                  onTap: () => Navigator.pop(context),
                  isDark: isDark,
                ),
                _MoreMenuItem(
                  icon: CupertinoIcons.heart,
                  label: 'Add to Favorites',
                  onTap: () => Navigator.pop(context),
                  isDark: isDark,
                ),
                _MoreMenuItem(
                  icon: CupertinoIcons.info_circle,
                  label: 'Song Info',
                  onTap: () => Navigator.pop(context),
                  isDark: isDark,
                  isLast: true,
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showQueue(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.92,
        minChildSize: 0.3,
        builder: (_, controller) => ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              color: isDark
                  ? LuminaColors.bg1.withOpacity(0.95)
                  : Colors.white.withOpacity(0.95),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: LuminaColors.labelTertiary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Next Up',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ValueListenableBuilder<List<AudioFile>>(
                      valueListenable: _ps.queueNotifier,
                      builder: (_, queue, __) {
                        final currentIdx = _ps.currentQueueIndex;
                        return ListView.builder(
                          controller: controller,
                          itemCount: queue.length,
                          itemBuilder: (_, i) {
                            final s = queue[i];
                            final isCurrent = i == currentIdx;
                            return ListTile(
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(5),
                                child: SizedBox(
                                  width: 40,
                                  height: 40,
                                  child: s.coverArt != null
                                      ? Image.memory(s.coverArt!,
                                          fit: BoxFit.cover)
                                      : Container(
                                          color: LuminaColors.bg2,
                                          child: const Icon(
                                              CupertinoIcons.music_note,
                                              size: 16,
                                              color: LuminaColors.labelSecondary),
                                        ),
                                ),
                              ),
                              title: Text(
                                s.title,
                                style: TextStyle(
                                  fontWeight: isCurrent
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: isCurrent
                                      ? LuminaColors.accent
                                      : (isDark ? Colors.white : Colors.black),
                                  fontSize: 14,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                s.artist,
                                style: const TextStyle(
                                    color: LuminaColors.labelSecondary,
                                    fontSize: 12),
                                maxLines: 1,
                              ),
                              trailing: isCurrent
                                  ? const Icon(
                                      CupertinoIcons.waveform,
                                      color: LuminaColors.accent,
                                      size: 18,
                                    )
                                  : null,
                              onTap: () {
                                _ps.playFromQueue(i);
                                Navigator.pop(context);
                              },
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── More Menu Item ─────────────────────────────────────────────────────────────
class _MoreMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDark;
  final bool isLast;

  const _MoreMenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.isDark,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: LuminaColors.accent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: LuminaColors.accent, size: 18),
          ),
          title: Text(
            label,
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
              fontSize: 15,
            ),
          ),
          trailing: const Icon(CupertinoIcons.chevron_right,
              color: LuminaColors.labelSecondary, size: 14),
          onTap: onTap,
        ),
        if (!isLast)
          Divider(
            color: isDark ? LuminaColors.bg3 : LuminaColors.lightBg3,
            height: 1,
          ),
      ],
    );
  }
}

// ── Controls Row ──────────────────────────────────────────────────────────────
class _Controls extends StatelessWidget {
  final PlayerService playerService;
  final bool isDark;

  const _Controls({required this.playerService, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Shuffle
        ValueListenableBuilder<bool>(
          valueListenable: playerService.shuffleNotifier,
          builder: (_, shuffle, __) => GestureDetector(
            onTap: playerService.toggleShuffle,
            child: Icon(
              CupertinoIcons.shuffle,
              color: shuffle
                  ? LuminaColors.accent
                  : (isDark ? Colors.white54 : Colors.black38),
              size: 24,
            ),
          ),
        ),
        // Previous
        GestureDetector(
          onTap: playerService.skipToPrevious,
          child: Icon(
            CupertinoIcons.backward_fill,
            color: isDark ? Colors.white : Colors.black87,
            size: 36,
          ),
        ),
        // Play / Pause
        ValueListenableBuilder<bool>(
          valueListenable: playerService.playingNotifier,
          builder: (_, isPlaying, __) {
            return GestureDetector(
              onTap: playerService.playPause,
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white : Colors.black,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Icon(
                  isPlaying
                      ? CupertinoIcons.pause_fill
                      : CupertinoIcons.play_fill,
                  color: isDark ? Colors.black : Colors.white,
                  size: 32,
                ),
              ),
            );
          },
        ),
        // Next
        GestureDetector(
          onTap: playerService.skipToNext,
          child: Icon(
            CupertinoIcons.forward_fill,
            color: isDark ? Colors.white : Colors.black87,
            size: 36,
          ),
        ),
        // Repeat
        ValueListenableBuilder<RepeatMode>(
          valueListenable: playerService.repeatNotifier,
          builder: (_, repeat, __) {
            IconData icon;
            Color color;
            switch (repeat) {
              case RepeatMode.off:
                icon = CupertinoIcons.repeat;
                color = isDark ? Colors.white54 : Colors.black38;
                break;
              case RepeatMode.all:
                icon = CupertinoIcons.repeat;
                color = LuminaColors.accent;
                break;
              case RepeatMode.one:
                icon = CupertinoIcons.repeat_1;
                color = LuminaColors.accent;
                break;
            }
            return GestureDetector(
              onTap: playerService.cycleRepeat,
              child: Icon(icon, color: color, size: 24),
            );
          },
        ),
      ],
    );
  }
}

// ── Seek Bar — fixed position tracking after seek ─────────────────────────────
class _SeekBar extends StatefulWidget {
  final PlayerService playerService;
  final bool isDark;

  const _SeekBar({required this.playerService, required this.isDark});

  @override
  State<_SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends State<_SeekBar> {
  /// While the user is dragging, we freeze updates from the stream.
  double? _dragValueMs;

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return d.inHours > 0 ? '${d.inHours}:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Duration?>(
      valueListenable: widget.playerService.durationNotifier,
      builder: (_, duration, __) {
        final totalMs =
            (duration?.inMilliseconds ?? 0).toDouble().clamp(1.0, double.infinity);

        return ValueListenableBuilder<Duration>(
          valueListenable: widget.playerService.positionNotifier,
          builder: (_, position, __) {
            // Use drag value while scrubbing, otherwise use live position
            final currentMs = (_dragValueMs ??
                    position.inMilliseconds.toDouble())
                .clamp(0.0, totalMs);
            final displayPos = Duration(milliseconds: currentMs.toInt());
            final displayDur = duration ?? Duration.zero;

            return Column(
              children: [
                SliderTheme(
                  data: SliderTheme.of(context),
                  child: Slider(
                    value: currentMs,
                    min: 0,
                    max: totalMs,
                    onChangeStart: (v) {
                      // Freeze live updates while user drags
                      setState(() => _dragValueMs = v);
                    },
                    onChanged: (v) {
                      setState(() => _dragValueMs = v);
                    },
                    onChangeEnd: (v) {
                      // Seek then unfreeze
                      widget.playerService
                          .seek(Duration(milliseconds: v.toInt()));
                      setState(() => _dragValueMs = null);
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _fmt(displayPos),
                        style: TextStyle(
                          color: widget.isDark
                              ? Colors.white60
                              : Colors.black45,
                          fontSize: 12,
                          fontVariations: const [
                            FontVariation('wght', 500)
                          ],
                        ),
                      ),
                      Text(
                        '-${_fmt(displayDur - displayPos)}',
                        style: TextStyle(
                          color: widget.isDark
                              ? Colors.white60
                              : Colors.black45,
                          fontSize: 12,
                        ),
                      ),
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
}
