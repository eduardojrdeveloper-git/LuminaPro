import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'ui/library_screen.dart';
import 'ui/player_screen.dart';
import 'ui/settings_screen.dart';
import 'services/player_service.dart';
import 'services/library_service.dart';

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.dark);
final ValueNotifier<bool> rotateArtworkNotifier = ValueNotifier(false);

// ── Apple HIG Color System ────────────────────────────────────────────────────
class LuminaColors {
  // iOS Blue accent
  static const accent = Color(0xFF007AFF);
  static const accentGlow = Color(0x44007AFF);

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
        _MiniPlayer(onTap: () => setState(() => _currentIndex = 1)),
        // ── Frosted Tab Bar ──────────────────────────────────────────────────
        ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                color: isDark
                    ? LuminaColors.bg0.withOpacity(0.8)
                    : Colors.white.withOpacity(0.85),
                border: Border(
                  top: BorderSide(
                    color: isDark
                        ? LuminaColors.bg3.withOpacity(0.5)
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
                        icon: CupertinoIcons.play_circle,
                        activeIcon: CupertinoIcons.play_circle_fill,
                        label: 'Now Playing',
                        onTap: () => setState(() => _currentIndex = 1),
                        isDark: isDark,
                      ),
                      _TabItem(
                        index: 2,
                        current: _currentIndex,
                        icon: CupertinoIcons.settings,
                        activeIcon: CupertinoIcons.settings_solid,
                        label: 'Settings',
                        onTap: () => setState(() => _currentIndex = 2),
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
        : (isDark ? LuminaColors.labelSecondary : LuminaColors.labelTertiary);

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isActive ? activeIcon : icon, color: color, size: 24),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight:
                    isActive ? FontWeight.w600 : FontWeight.normal,
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
          child: ClipRRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark
                      ? LuminaColors.bg1.withOpacity(0.92)
                      : Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark
                        ? LuminaColors.bg3.withOpacity(0.5)
                        : Colors.black.withOpacity(0.08),
                    width: 0.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.4 : 0.12),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Artwork
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 44,
                        height: 44,
                        child: song.coverArt != null
                            ? Image.memory(song.coverArt!, fit: BoxFit.cover)
                            : Container(
                                color: LuminaColors.bg2,
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
                              fontSize: 14,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                          Text(
                            song.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: LuminaColors.accent,
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Icon(
          icon,
          size: 22,
          color: isDark ? Colors.white : Colors.black,
        ),
      ),
    );
  }
}
