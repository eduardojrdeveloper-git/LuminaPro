import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'ui/library_screen.dart';
import 'ui/player_screen.dart';
import 'ui/settings_screen.dart';
import 'ui/search_screen.dart';
import 'services/player_service.dart';
import 'services/library_service.dart';

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.dark);
final ValueNotifier<bool> rotateArtworkNotifier = ValueNotifier(false);

// ── Apple Music Color System ──────────────────────────────────────────────────
class LuminaColors {
  // Apple Music Red — primary accent
  static const accent      = Color(0xFFFA233B);
  static const accentGlow  = Color(0x55FA233B);
  static const accentSoft  = Color(0x22FA233B);

  // Dark backgrounds (iOS layered grays)
  static const bg0 = Color(0xFF000000);       // deepest
  static const bg1 = Color(0xFF1C1C1E);       // elevated
  static const bg2 = Color(0xFF2C2C2E);       // card
  static const bg3 = Color(0xFF3A3A3C);       // separator

  // Light backgrounds
  static const lightBg0 = Color(0xFFF2F2F7);
  static const lightBg1 = Color(0xFFFFFFFF);
  static const lightBg2 = Color(0xFFE5E5EA);
  static const lightBg3 = Color(0xFFD1D1D6);

  static const labelPrimary   = Color(0xFFFFFFFF);
  static const labelSecondary = Color(0xFF8E8E93);
  static const labelTertiary  = Color(0xFF636366);
  static const destructive    = Color(0xFFFF3B30);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const LuminaProApp());
}

class LuminaProApp extends StatelessWidget {
  const LuminaProApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, ThemeMode mode, __) {
        return MaterialApp(
          title: 'Lumina Pro',
          debugShowCheckedModeBanner: false,
          themeMode: mode,
          theme: _buildLightTheme(),
          darkTheme: _buildDarkTheme(),
          home: const MainNavigation(),
        );
      },
    );
  }

  ThemeData _buildLightTheme() {
    final base = GoogleFonts.interTextTheme();
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: LuminaColors.lightBg0,
      primaryColor: LuminaColors.accent,
      cupertinoOverrideTheme: const CupertinoThemeData(
        primaryColor: LuminaColors.accent,
      ),
      colorScheme: const ColorScheme.light(
        primary: LuminaColors.accent,
        secondary: LuminaColors.accent,
        surface: LuminaColors.lightBg1,
        onSurface: Color(0xFF000000),
      ),
      textTheme: base.apply(
        bodyColor: const Color(0xFF000000),
        displayColor: const Color(0xFF000000),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: LuminaColors.lightBg0,
        foregroundColor: Color(0xFF000000),
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      sliderTheme: SliderThemeData(
        trackHeight: 4,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
        activeTrackColor: LuminaColors.accent,
        inactiveTrackColor: LuminaColors.lightBg3,
        thumbColor: Colors.white,
        overlayColor: LuminaColors.accentGlow,
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    final base = GoogleFonts.interTextTheme();
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: LuminaColors.bg0,
      primaryColor: LuminaColors.accent,
      cupertinoOverrideTheme: const CupertinoThemeData(
        primaryColor: LuminaColors.accent,
        brightness: Brightness.dark,
      ),
      colorScheme: const ColorScheme.dark(
        primary: LuminaColors.accent,
        secondary: LuminaColors.accent,
        surface: LuminaColors.bg1,
        onSurface: LuminaColors.labelPrimary,
      ),
      textTheme: base.apply(
        bodyColor: LuminaColors.labelPrimary,
        displayColor: LuminaColors.labelPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: LuminaColors.bg0,
        foregroundColor: LuminaColors.labelPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      sliderTheme: SliderThemeData(
        trackHeight: 4,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
        activeTrackColor: Colors.white,
        inactiveTrackColor: LuminaColors.bg3,
        thumbColor: Colors.white,
        overlayColor: Colors.white24,
      ),
    );
  }
}

// ── Main Navigation ───────────────────────────────────────────────────────────
class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation>
    with TickerProviderStateMixin {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    LibraryScreen(),
    const SearchScreen(),
    const PlayerScreen(),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: _buildBottomBar(isDark),
    );
  }

  Widget _buildBottomBar(bool isDark) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Mini Player ──────────────────────────────────────────────────────
        _MiniPlayer(onTap: () => setState(() => _currentIndex = 2)),
        // ── Frosted Tab Bar ──────────────────────────────────────────────────
        ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                color: isDark
                    ? LuminaColors.bg0.withOpacity(0.82)
                    : Colors.white.withOpacity(0.88),
                border: Border(
                  top: BorderSide(
                    color: isDark
                        ? Colors.white.withOpacity(0.08)
                        : Colors.black.withOpacity(0.1),
                    width: 0.5,
                  ),
                ),
              ),
              child: SafeArea(
                top: false,
                child: SizedBox(
                  height: 56,
                  child: Row(
                    children: [
                      _TabItem(
                        index: 0,
                        current: _currentIndex,
                        icon: CupertinoIcons.music_albums,
                        activeIcon: CupertinoIcons.music_albums_fill,
                        label: 'Library',
                        onTap: () => setState(() => _currentIndex = 0),
                        isDark: isDark,
                      ),
                      _TabItem(
                        index: 1,
                        current: _currentIndex,
                        icon: CupertinoIcons.search,
                        activeIcon: CupertinoIcons.search,
                        label: 'Search',
                        onTap: () => setState(() => _currentIndex = 1),
                        isDark: isDark,
                      ),
                      _TabItem(
                        index: 2,
                        current: _currentIndex,
                        icon: CupertinoIcons.play_circle,
                        activeIcon: CupertinoIcons.play_circle_fill,
                        label: 'Now Playing',
                        onTap: () => setState(() => _currentIndex = 2),
                        isDark: isDark,
                      ),
                      _TabItem(
                        index: 3,
                        current: _currentIndex,
                        icon: CupertinoIcons.settings,
                        activeIcon: CupertinoIcons.settings_solid,
                        label: 'Settings',
                        onTap: () => setState(() => _currentIndex = 3),
                        isDark: isDark,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Tab Item ─────────────────────────────────────────────────────────────────
class _TabItem extends StatelessWidget {
  final int index;
  final int current;
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final VoidCallback onTap;
  final bool isDark;

  const _TabItem({
    required this.index,
    required this.current,
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = index == current;
    final color = isActive
        ? LuminaColors.accent
        : (isDark ? LuminaColors.labelSecondary : const Color(0xFF8E8E93));

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                isActive ? activeIcon : icon,
                key: ValueKey(isActive),
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Mini Player ───────────────────────────────────────────────────────────────
class _MiniPlayer extends StatelessWidget {
  final VoidCallback onTap;
  const _MiniPlayer({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final playerService = PlayerService();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ValueListenableBuilder<AudioFile?>(
      valueListenable: playerService.currentSong,
      builder: (context, song, _) {
        if (song == null) return const SizedBox.shrink();

        return GestureDetector(
          onTap: onTap,
          child: Container(
            margin: const EdgeInsets.fromLTRB(8, 4, 8, 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.45 : 0.15),
                  blurRadius: 24,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark
                        ? LuminaColors.bg2.withOpacity(0.95)
                        : Colors.white.withOpacity(0.92),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withOpacity(0.07)
                          : Colors.black.withOpacity(0.06),
                      width: 0.5,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        child: Row(
                          children: [
                            // Artwork
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: SizedBox(
                                width: 44,
                                height: 44,
                                child: song.coverArt != null
                                    ? Image.memory(song.coverArt!,
                                        fit: BoxFit.cover)
                                    : Container(
                                        color: LuminaColors.bg3,
                                        child: const Icon(
                                          CupertinoIcons.music_note,
                                          color: LuminaColors.labelSecondary,
                                          size: 20,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Title / Artist
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    song.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                      color:
                                          isDark ? Colors.white : Colors.black,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  const SizedBox(height: 1),
                                  Text(
                                    song.artist,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: LuminaColors.accent,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Controls
                            ValueListenableBuilder<bool>(
                              valueListenable: playerService.playingNotifier,
                              builder: (_, isPlaying, __) => Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _MiniButton(
                                    icon: isPlaying
                                        ? CupertinoIcons.pause_fill
                                        : CupertinoIcons.play_fill,
                                    isDark: isDark,
                                    onTap: playerService.playPause,
                                  ),
                                  _MiniButton(
                                    icon: CupertinoIcons.forward_fill,
                                    isDark: isDark,
                                    onTap: playerService.skipToNext,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // ── Progress Bar ─────────────────────────────────────
                      ValueListenableBuilder<Duration?>(
                        valueListenable: playerService.durationNotifier,
                        builder: (_, duration, __) {
                          return ValueListenableBuilder<Duration>(
                            valueListenable: playerService.positionNotifier,
                            builder: (_, position, __) {
                              final total = duration?.inMilliseconds ?? 1;
                              final current = position.inMilliseconds
                                  .clamp(0, total)
                                  .toDouble();
                              final progress =
                                  total > 0 ? current / total : 0.0;
                              return SizedBox(
                                height: 2,
                                child: LinearProgressIndicator(
                                  value: progress,
                                  backgroundColor: isDark
                                      ? Colors.white.withOpacity(0.1)
                                      : Colors.black.withOpacity(0.08),
                                  valueColor: const AlwaysStoppedAnimation(
                                      LuminaColors.accent),
                                  minHeight: 2,
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MiniButton extends StatelessWidget {
  final IconData icon;
  final bool isDark;
  final VoidCallback onTap;

  const _MiniButton(
      {required this.icon, required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Icon(
          icon,
          size: 22,
          color: isDark ? Colors.white : Colors.black87,
        ),
      ),
    );
  }
}
