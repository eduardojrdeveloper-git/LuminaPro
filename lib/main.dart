import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'ui/library_screen.dart';
import 'ui/player_screen.dart';
import 'ui/settings_screen.dart';
import 'ui/discover_screen.dart';
import 'services/player_service.dart';
import 'services/library_service.dart';
import 'services/google_drive_service.dart';
import 'services/log_service.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.system);
final ValueNotifier<bool> rotateArtworkNotifier = ValueNotifier(true);
final ValueNotifier<bool> showQualityInLibraryNotifier = ValueNotifier(true);
final ValueNotifier<bool> showQualityInPlayerNotifier = ValueNotifier(true);
final ValueNotifier<bool> extractCloudCoversNotifier = ValueNotifier(true);
final ValueNotifier<bool> keepScreenOnNotifier = ValueNotifier(false);
final ValueNotifier<bool> persistentLyricsModeNotifier = ValueNotifier(false);
final ValueNotifier<bool> showLyricsInPlayerNotifier = ValueNotifier(false);
final ValueNotifier<bool> isExtractingCoversNotifier = ValueNotifier(false);
final ValueNotifier<String> extractingCoverFileNotifier = ValueNotifier('');

// ── Apple Music Color System ──────────────────────────────────────────────────
class LuminaColors {
  static const accent      = Color(0xFFFA233B);
  static const accentGlow  = Color(0x55FA233B);
  static const accentSoft  = Color(0x22FA233B);

  static const bg0 = Color(0xFF000000);
  static const bg1 = Color(0xFF1C1C1E);
  static const bg2 = Color(0xFF2C2C2E);
  static const bg3 = Color(0xFF3A3A3C);
  static const lead = Color(0xFF3A3A3C);

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
  await LogService.initialize();
  await LibraryService.initialize();
  // Clear any leftover temp cache from a previous session/crash
  GoogleDriveService().clearTempCache();
  // Attempt to restore GDrive session silently
  await GoogleDriveService().signInSilently();
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
      cupertinoOverrideTheme: const CupertinoThemeData(primaryColor: LuminaColors.accent),
      colorScheme: const ColorScheme.light(
        primary: LuminaColors.accent,
        secondary: LuminaColors.accent,
        surface: LuminaColors.lightBg1,
        onSurface: Color(0xFF000000),
      ),
      textTheme: base.apply(bodyColor: const Color(0xFF000000), displayColor: const Color(0xFF000000)),
      appBarTheme: const AppBarTheme(backgroundColor: LuminaColors.lightBg0, foregroundColor: Color(0xFF000000), elevation: 0),
      sliderTheme: SliderThemeData(
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
      cupertinoOverrideTheme: const CupertinoThemeData(primaryColor: LuminaColors.accent, brightness: Brightness.dark),
      colorScheme: const ColorScheme.dark(
        primary: LuminaColors.accent,
        secondary: LuminaColors.accent,
        surface: LuminaColors.bg1,
        onSurface: LuminaColors.labelPrimary,
      ),
      textTheme: base.apply(bodyColor: LuminaColors.labelPrimary, displayColor: LuminaColors.labelPrimary),
      appBarTheme: const AppBarTheme(backgroundColor: LuminaColors.bg0, foregroundColor: LuminaColors.labelPrimary, elevation: 0),
      sliderTheme: SliderThemeData(
        activeTrackColor: Colors.white,
        inactiveTrackColor: LuminaColors.bg3,
        thumbColor: Colors.white,
        overlayColor: Colors.white24,
      ),
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});
  @override
  State<MainNavigation> createState() => MainNavigationState();
}

class MainNavigationState extends State<MainNavigation> with WidgetsBindingObserver {
  int _currentIndex = 0;
  int _previousIndex = 0;
  final _ps = PlayerService();

  late final List<Widget> _screens = [
    const LibraryScreen(key: ValueKey(0)),
    const DiscoverScreen(key: ValueKey(1)),
    const PlayerScreen(key: ValueKey(2)),
    const SettingsScreen(key: ValueKey(3)),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Listen for screen on toggle
    keepScreenOnNotifier.addListener(_updateWakelock);
    _updateWakelock();
  }

  void _updateWakelock() {
    WakelockPlus.toggle(enable: keepScreenOnNotifier.value);
    LogService.log('Wakelock ${keepScreenOnNotifier.value ? 'enabled' : 'disabled'}');
  }

  @override
  void dispose() {
    keepScreenOnNotifier.removeListener(_updateWakelock);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void setIndex(int index) {
    if (index == _currentIndex) return;
    setState(() {
      _previousIndex = _currentIndex;
      _currentIndex = index;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Keep temp caches to allow resumes or fast replays later
  }

  void _onHorizontalSwipe(DragEndDetails details) {
    if (details.primaryVelocity == null) return;
    if (details.primaryVelocity! < -300) {
      // Swipe left -> go to next tab
      if (_currentIndex < _screens.length - 1) {
        setIndex(_currentIndex + 1);
      }
    } else if (details.primaryVelocity! > 300) {
      // Swipe right -> go to previous tab
      if (_currentIndex > 0) {
        setIndex(_currentIndex - 1);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          GestureDetector(
            onHorizontalDragEnd: _onHorizontalSwipe,
            behavior: HitTestBehavior.opaque,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeOutCubic,
              layoutBuilder: (Widget? currentChild, List<Widget> previousChildren) {
                return Stack(
                  alignment: Alignment.topCenter,
                  children: <Widget>[
                    ...previousChildren,
                    if (currentChild != null) currentChild,
                  ],
                );
              },
              transitionBuilder: (Widget child, Animation<double> animation) {
                final childIndex = (child.key as ValueKey<int>).value;
                final isMovingRight = _currentIndex > _previousIndex;
                final isIncoming = childIndex == _currentIndex;
                
                final offset = isIncoming 
                    ? Offset(isMovingRight ? 1.0 : -1.0, 0.0) 
                    : Offset(isMovingRight ? -1.0 : 1.0, 0.0);

                return SlideTransition(
                  position: Tween<Offset>(begin: offset, end: Offset.zero).animate(animation),
                  child: child,
                );
              },
              child: _screens[_currentIndex],
            ),
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutQuart,
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildBottomOverlay(isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomOverlay(bool isDark) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Mini Player ───────────────────────────────
        ValueListenableBuilder<AudioFile?>(
          valueListenable: _ps.currentSong,
          builder: (context, song, _) {
            final showMini = song != null;
            if (!showMini) return const SizedBox.shrink();
            return _MiniPlayer(onTap: () => setIndex(2));
          },
        ),
        
        ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
            child: Container(
              decoration: BoxDecoration(
                color: isDark
                    ? LuminaColors.bg0.withOpacity(0.6)
                    : Colors.white.withOpacity(0.7),
                border: Border(
                  top: BorderSide(
                    color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.08),
                    width: 0.5,
                  ),
                ),
              ),
              child: SafeArea(
                top: false,
                child: SizedBox(
                  height: 54,
                  child: Row(
                    children: [
                      _TabItem(index: 0, current: _currentIndex, icon: CupertinoIcons.music_albums, activeIcon: CupertinoIcons.music_albums_fill, label: 'Library', onTap: () => setIndex(0), isDark: isDark),
                      _TabItem(index: 1, current: _currentIndex, icon: CupertinoIcons.globe, activeIcon: CupertinoIcons.globe, label: 'Discover', onTap: () => setIndex(1), isDark: isDark),
                      _TabItem(index: 2, current: _currentIndex, icon: CupertinoIcons.play_circle, activeIcon: CupertinoIcons.play_circle_fill, label: 'Playing', onTap: () => setIndex(2), isDark: isDark),
                      _TabItem(index: 3, current: _currentIndex, icon: CupertinoIcons.settings, activeIcon: CupertinoIcons.settings_solid, label: 'Settings', onTap: () => setIndex(3), isDark: isDark),
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

  const _TabItem({required this.index, required this.current, required this.icon, required this.activeIcon, required this.label, required this.onTap, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final isActive = index == current;
    final color = isActive ? LuminaColors.accent : (isDark ? LuminaColors.labelSecondary : const Color(0xFF8E8E93));
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isActive ? activeIcon : icon, color: color, size: 24),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: isActive ? FontWeight.w600 : FontWeight.normal)),
          ],
        ),
      ),
    );
  }
}

class _MiniPlayer extends StatefulWidget {
  final VoidCallback onTap;
  const _MiniPlayer({required this.onTap});

  @override
  State<_MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends State<_MiniPlayer> {
  final _ps = PlayerService();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Indexing Status Overlay ──────────────────────────────────────────
        _buildIndexingStatus(isDark),
        
        ValueListenableBuilder<AudioFile?>(
          valueListenable: _ps.currentSong,
          builder: (context, song, _) {
            if (song == null) return const SizedBox.shrink();
            return GestureDetector(
              onTap: widget.onTap,
              child: Container(
                margin: const EdgeInsets.fromLTRB(10, 0, 10, 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.35 : 0.1), blurRadius: 16, offset: const Offset(0, 4))],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark ? LuminaColors.lead.withOpacity(0.7) : Colors.white.withOpacity(0.8),
                        border: Border.all(color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.06), width: 0.5),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: SizedBox(
                                width: 40, height: 40,
                                child: song.coverArt != null && song.coverArt!.isNotEmpty ? Image.memory(song.coverArt!, fit: BoxFit.cover) : Container(color: LuminaColors.bg3, child: const Icon(CupertinoIcons.music_note, color: LuminaColors.labelSecondary, size: 20)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: isDark ? Colors.white : Colors.black)),
                                  Text(song.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: LuminaColors.accent)),
                                ],
                              ),
                            ),
                            ValueListenableBuilder<bool>(
                              valueListenable: _ps.playingNotifier,
                              builder: (_, isPlaying, __) => Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _MiniButton(icon: isPlaying ? CupertinoIcons.pause_fill : CupertinoIcons.play_fill, isDark: isDark, onTap: _ps.playPause),
                                  _MiniButton(icon: CupertinoIcons.forward_fill, isDark: isDark, onTap: _ps.skipToNext),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildIndexingStatus(bool isDark) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ValueListenableBuilder<bool>(
          valueListenable: LibraryService.isIndexingNotifier,
          builder: (context, isIndexing, _) {
            if (!isIndexing) return const SizedBox.shrink();
            return _ProgressBadge(
              label: 'Indexing Library',
              isDark: isDark,
              detailNotifier: LibraryService.indexCurrentFileNotifier,
              progressNotifier: LibraryService.indexProgressNotifier,
              icon: CupertinoIcons.refresh_thick,
            );
          },
        ),
        ValueListenableBuilder<bool>(
          valueListenable: isExtractingCoversNotifier,
          builder: (context, isExtracting, _) {
            if (!isExtracting) return const SizedBox.shrink();
            return _ProgressBadge(
              label: 'Extracting Covers',
              isDark: isDark,
              detailNotifier: extractingCoverFileNotifier,
              icon: CupertinoIcons.photo,
            );
          },
        ),
      ],
    );
  }
}

class _ProgressBadge extends StatelessWidget {
  final String label;
  final bool isDark;
  final ValueNotifier<String> detailNotifier;
  final ValueNotifier<double>? progressNotifier;
  final IconData icon;

  const _ProgressBadge({
    required this.label,
    required this.isDark,
    required this.detailNotifier,
    this.progressNotifier,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? LuminaColors.bg1.withOpacity(0.8) : Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: progressNotifier != null 
              ? ValueListenableBuilder<double>(
                  valueListenable: progressNotifier!,
                  builder: (_, p, __) => CircularProgressIndicator(
                    value: p > 0 ? p : null,
                    strokeWidth: 2,
                    color: LuminaColors.accent,
                  ),
                )
              : const CupertinoActivityIndicator(radius: 8),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: LuminaColors.accent)),
                ValueListenableBuilder<String>(
                  valueListenable: detailNotifier,
                  builder: (_, detail, __) => Text(
                    detail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10, color: isDark ? Colors.white70 : Colors.black54),
                  ),
                ),
              ],
            ),
          ),
          Icon(icon, size: 14, color: LuminaColors.accent.withOpacity(0.5)),
        ],
      ),
    );
  }
}

class _MiniButton extends StatelessWidget {
  final IconData icon;
  final bool isDark;
  final VoidCallback onTap;
  const _MiniButton({required this.icon, required this.isDark, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), child: Icon(icon, size: 22, color: isDark ? Colors.white : Colors.black87)),
    );
  }
}
