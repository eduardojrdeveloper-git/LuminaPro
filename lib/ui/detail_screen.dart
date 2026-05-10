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

    return Scaffold(
      backgroundColor:
          isDark ? LuminaColors.bg0 : LuminaColors.lightBg0,
      body: CustomScrollView(
        slivers: [
          // ── Hero Header ──────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 320,
            pinned: true,
            backgroundColor: isDark ? LuminaColors.bg0 : LuminaColors.lightBg0,
            surfaceTintColor: Colors.transparent,
            leading: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black45,
                  shape: BoxShape.circle,
                ),
                child: const Icon(CupertinoIcons.back,
                    color: Colors.white, size: 20),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Background art with parallax
                  if (coverArt != null)
                    Image.memory(coverArt!, fit: BoxFit.cover)
                  else
                    Container(
                      color: isDark ? LuminaColors.bg1 : LuminaColors.lightBg2,
                      child: const Icon(
                        CupertinoIcons.music_albums_fill,
                        size: 80,
                        color: LuminaColors.labelTertiary,
                      ),
                    ),
                  // Gradient overlay
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.7),
                        ],
                        stops: const [0.5, 1.0],
                      ),
                    ),
                  ),
                  // Title text at bottom of header
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 80,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                        ),
                        if (songs.isNotEmpty)
                          Text(
                            songs.first.artist,
                            style: const TextStyle(
                              color: LuminaColors.accent,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        const SizedBox(height: 4),
                        Text(
                          '${songs.length} songs · $totalMin min',
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Play All + Shuffle buttons
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 20,
                    child: Row(
                      children: [
                        Expanded(
                          child: _HeaderButton(
                            icon: CupertinoIcons.play_fill,
                            label: 'Play',
                            onTap: () => PlayerService()
                                .playQueue(songs, initialIndex: 0),
                            isDark: isDark,
                            filled: true,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _HeaderButton(
                            icon: CupertinoIcons.shuffle,
                            label: 'Shuffle',
                            onTap: () {
                              final ps = PlayerService();
                              ps.playQueue(songs, initialIndex: 0);
                              if (!ps.shuffle) ps.toggleShuffle();
                            },
                            isDark: isDark,
                            filled: false,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Track List ───────────────────────────────────────────────────
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final song = songs[index];
                final isPlaying =
                    PlayerService().currentSong.value?.path == song.path;
                return Column(
                  children: [
                    ListTile(
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      leading: SizedBox(
                        width: 32,
                        child: isPlaying
                            ? const Icon(CupertinoIcons.waveform,
                                color: LuminaColors.accent, size: 18)
                            : Text(
                                '${index + 1}',
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                  color: LuminaColors.labelSecondary,
                                  fontSize: 15,
                                ),
                              ),
                      ),
                      title: Text(
                        song.title,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: isPlaying
                              ? LuminaColors.accent
                              : (isDark ? Colors.white : Colors.black87),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        song.album != title
                            ? '${song.album} · ${song.artist}'
                            : song.artist,
                        style: const TextStyle(
                          color: LuminaColors.labelSecondary,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (song.duration != null)
                            Text(
                              _fmt(song.duration),
                              style: const TextStyle(
                                color: LuminaColors.labelSecondary,
                                fontSize: 13,
                              ),
                            ),
                          const SizedBox(width: 8),
                          const Icon(CupertinoIcons.ellipsis,
                              color: LuminaColors.labelSecondary, size: 16),
                        ],
                      ),
                      onTap: () {
                        PlayerService().playQueue(songs, initialIndex: index);
                      },
                    ),
                    if (index < songs.length - 1)
                      Divider(
                        color: isDark
                            ? LuminaColors.bg3
                            : LuminaColors.lightBg3,
                        indent: 52,
                        height: 1,
                      ),
                  ],
                );
              },
              childCount: songs.length,
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDark;
  final bool filled;

  const _HeaderButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.isDark,
    required this.filled,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: filled
                  ? LuminaColors.accent
                  : Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 16),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
