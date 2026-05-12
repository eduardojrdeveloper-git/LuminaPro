import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../services/library_service.dart';
import '../services/player_service.dart';
import '../main.dart' show LuminaColors;

class DetailScreen extends StatelessWidget {
  final String title;
  final List<AudioFile> songs;
  final Uint8List? coverArt;

  const DetailScreen({
    super.key,
    required this.title,
    required this.songs,
    this.coverArt,
  });

  String _fmt(Duration? d) {
    if (d == null) return '';
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalDur = songs.fold<Duration>(
      Duration.zero,
      (prev, s) => prev + (s.duration ?? Duration.zero),
    );
    final totalMin = totalDur.inMinutes;

    return CupertinoPageScaffold(
      backgroundColor: isDark ? LuminaColors.bg0 : LuminaColors.lightBg0,
      child: Material(
        type: MaterialType.transparency, // Fix yellow underlines
        child: CustomScrollView(
          slivers: [
            // ── Cupertino Nav Bar ────────────────────────────────────────────
            CupertinoSliverNavigationBar(
              largeTitle: Text(
                title,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                  decoration: TextDecoration.none,
                ),
              ),
              leading: CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => Navigator.pop(context),
                child: const Icon(CupertinoIcons.chevron_back,
                    color: LuminaColors.accent),
              ),
              backgroundColor:
                  (isDark ? LuminaColors.bg0 : LuminaColors.lightBg0)
                      .withOpacity(0.88),
              border: null,
            ),

            SliverToBoxAdapter(
              child: Column(
                children: [
                  // ── Album Artwork ──
                  Padding(
                    padding: const EdgeInsets.fromLTRB(54, 20, 54, 0),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(isDark ? 0.55 : 0.2),
                            blurRadius: 40,
                            offset: const Offset(0, 16),
                            spreadRadius: -4,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: coverArt != null && coverArt!.isNotEmpty
                              ? Image.memory(coverArt!, fit: BoxFit.cover)
                              : Container(
                                  color: isDark
                                      ? LuminaColors.bg2
                                      : LuminaColors.lightBg2,
                                  child: const Center(
                                    child: Icon(CupertinoIcons.music_albums,
                                        color: LuminaColors.labelSecondary,
                                        size: 64),
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),

                  // ── Album Info ──
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 4),
                    child: Column(
                      children: [
                        if (songs.isNotEmpty)
                          Text(
                            songs.first.artist,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 18,
                              color: LuminaColors.accent,
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        const SizedBox(height: 4),
                        Text(
                          '${songs.length} SONGS · $totalMin MINUTES',
                          style: TextStyle(
                            color: LuminaColors.labelSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Play + Shuffle Buttons ──
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: _DetailButton(
                            icon: CupertinoIcons.play_fill,
                            label: 'Play',
                            filled: true,
                            isDark: isDark,
                            onTap: () =>
                                PlayerService().playQueue(songs, initialIndex: 0),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _DetailButton(
                            icon: CupertinoIcons.shuffle,
                            label: 'Shuffle',
                            filled: false,
                            isDark: isDark,
                            onTap: () {
                              final ps = PlayerService();
                              ps.playQueue(songs, initialIndex: 0);
                              if (!ps.shuffle) ps.toggleShuffle();
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),
                  Divider(
                    color: isDark ? LuminaColors.bg3 : LuminaColors.lightBg3,
                    height: 1,
                    indent: 24,
                    endIndent: 24,
                  ),
                ],
              ),
            ),

            // ── Track List ──
            SliverPadding(
              padding: const EdgeInsets.only(top: 8),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final song = songs[index];
                    final isPlaying =
                        PlayerService().currentSong.value?.path == song.path;
                    return Column(
                      children: [
                        _TrackRow(
                          song: song,
                          index: index,
                          isPlaying: isPlaying,
                          isDark: isDark,
                          fmt: _fmt,
                          onTap: () => PlayerService()
                              .playQueue(songs, initialIndex: index),
                        ),
                        if (index < songs.length - 1)
                          Divider(
                            color: isDark
                                ? LuminaColors.bg3
                                : LuminaColors.lightBg3,
                            indent: 72,
                            height: 1,
                          ),
                      ],
                    );
                  },
                  childCount: songs.length,
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 150)),
          ],
        ),
      ),
    );
  }
}

class _TrackRow extends StatelessWidget {
  final AudioFile song;
  final int index;
  final bool isPlaying;
  final bool isDark;
  final String Function(Duration?) fmt;
  final VoidCallback onTap;

  const _TrackRow({
    required this.song,
    required this.index,
    required this.isPlaying,
    required this.isDark,
    required this.fmt,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Row(
          children: [
            SizedBox(
              width: 32,
              child: isPlaying
                  ? const Icon(CupertinoIcons.waveform,
                      color: LuminaColors.accent, size: 18)
                  : Text(
                      '${index + 1}',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: LuminaColors.labelSecondary.withOpacity(0.6),
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                        decoration: TextDecoration.none,
                      ),
                    ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    song.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: isPlaying
                          ? LuminaColors.accent
                          : (isDark ? Colors.white : Colors.black87),
                      letterSpacing: -0.3,
                      decoration: TextDecoration.none,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (song.artist.isNotEmpty)
                    Text(
                      song.artist,
                      style: TextStyle(
                        color: LuminaColors.labelSecondary,
                        fontSize: 13,
                        decoration: TextDecoration.none,
                      ),
                      maxLines: 1,
                    ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (song.duration != null)
                  Text(
                    fmt(song.duration),
                    style: TextStyle(
                      color: LuminaColors.labelTertiary,
                      fontSize: 13,
                      decoration: TextDecoration.none,
                    ),
                  ),
                const SizedBox(width: 12),
                const Icon(CupertinoIcons.ellipsis,
                    color: LuminaColors.labelSecondary, size: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool filled;
  final bool isDark;
  final VoidCallback onTap;

  const _DetailButton({
    required this.icon,
    required this.label,
    required this.filled,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: filled
              ? LuminaColors.accent
              : (isDark ? LuminaColors.bg2 : LuminaColors.lightBg2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: filled
                  ? Colors.white
                  : LuminaColors.accent,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                letterSpacing: -0.3,
                color: filled
                    ? Colors.white
                    : LuminaColors.accent,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
