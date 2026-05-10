import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../main.dart' show LuminaColors, themeNotifier;
import '../services/player_service.dart';
import 'eq_advanced_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _ps = PlayerService();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          // Large Title AppBar
          SliverAppBar(
            pinned: true,
            expandedHeight: 100,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            surfaceTintColor: Colors.transparent,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
              title: Text(
                'Settings',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.only(bottom: 40),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── AUDIO ENGINE ───────────────────────────────────────────
                _SectionHeader('AUDIO ENGINE'),
                _GroupedSection(
                  isDark: isDark,
                  children: [
                    _SettingRow(
                      isDark: isDark,
                      icon: CupertinoIcons.waveform,
                      iconColor: const Color(0xFF5856D6),
                      title: 'Parametric EQ',
                      subtitle: 'Customize frequency response',
                      onTap: () => Navigator.push(
                        context,
                        CupertinoPageRoute(
                            builder: (_) => const EqAdvancedScreen()),
                      ),
                      showChevron: true,
                    ),
                    const _Divider(),
                    // Crossfade slider
                    StatefulBuilder(
                      builder: (ctx, setLocal) {
                        final cf = _ps.crossfadeDuration;
                        return _SettingRow(
                          isDark: isDark,
                          icon: CupertinoIcons.arrow_left_right,
                          iconColor: const Color(0xFFFF9500),
                          title: 'Crossfade',
                          subtitle: cf == 0
                              ? 'Off'
                              : '${cf.toInt()} ${cf == 1 ? 'second' : 'seconds'}',
                          trailing: SizedBox(
                            width: 130,
                            child: Slider(
                              value: cf,
                              min: 0,
                              max: 12,
                              divisions: 12,
                              activeColor: const Color(0xFFFF9500),
                              inactiveColor: isDark
                                  ? LuminaColors.bg3
                                  : LuminaColors.lightBg3,
                              onChanged: (v) {
                                setLocal(() => _ps.crossfadeDuration = v);
                                setState(() {});
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),

                // ── INTERFACE ──────────────────────────────────────────────
                _SectionHeader('INTERFACE'),
                _GroupedSection(
                  isDark: isDark,
                  children: [
                    ValueListenableBuilder<ThemeMode>(
                      valueListenable: themeNotifier,
                      builder: (_, mode, __) {
                        final label = {
                          ThemeMode.system: 'System',
                          ThemeMode.light: 'Light',
                          ThemeMode.dark: 'Dark',
                        }[mode]!;
                        return _SettingRow(
                          isDark: isDark,
                          icon: CupertinoIcons.paintpalette,
                          iconColor: const Color(0xFFFF2D55),
                          title: 'Appearance',
                          trailing: GestureDetector(
                            onTap: () => _showThemePicker(context),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  label,
                                  style: const TextStyle(
                                      color: LuminaColors.labelSecondary,
                                      fontSize: 14),
                                ),
                                const SizedBox(width: 4),
                                const Icon(CupertinoIcons.chevron_right,
                                    color: LuminaColors.labelSecondary,
                                    size: 14),
                              ],
                            ),
                          ),
                          onTap: () => _showThemePicker(context),
                        );
                      },
                    ),
                  ],
                ),

                // ── NOW PLAYING ────────────────────────────────────────────
                _SectionHeader('NOW PLAYING'),
                _GroupedSection(
                  isDark: isDark,
                  children: [
                    ValueListenableBuilder(
                      valueListenable: PlayerService().currentSong,
                      builder: (_, song, __) {
                        if (song == null) {
                          return _SettingRow(
                            isDark: isDark,
                            icon: CupertinoIcons.music_note_2,
                            iconColor: LuminaColors.accent,
                            title: 'Current Track',
                            subtitle: 'Nothing playing',
                          );
                        }
                        return _SettingRow(
                          isDark: isDark,
                          icon: CupertinoIcons.music_note_2,
                          iconColor: LuminaColors.accent,
                          title: song.title,
                          subtitle: song.formatBadge.isNotEmpty
                              ? song.formatBadge
                              : song.artist,
                        );
                      },
                    ),
                  ],
                ),

                // ── LIBRARY ────────────────────────────────────────────────
                _SectionHeader('LIBRARY'),
                _GroupedSection(
                  isDark: isDark,
                  children: [
                    _SettingRow(
                      isDark: isDark,
                      icon: CupertinoIcons.folder_fill,
                      iconColor: const Color(0xFF34C759),
                      title: 'How to Add Music',
                      subtitle: 'Transfer via Files app or iTunes',
                      onTap: () => _showHowToAddMusic(context, isDark),
                      showChevron: true,
                    ),
                    const _Divider(),
                    _SettingRow(
                      isDark: isDark,
                      icon: CupertinoIcons.doc_text,
                      iconColor: const Color(0xFF5AC8FA),
                      title: 'Supported Formats',
                      subtitle: 'FLAC · WAV · MP3 · M4A · AIFF',
                    ),
                  ],
                ),

                // ── ABOUT ──────────────────────────────────────────────────
                _SectionHeader('ABOUT'),
                _GroupedSection(
                  isDark: isDark,
                  children: [
                    _SettingRow(
                      isDark: isDark,
                      icon: CupertinoIcons.sparkles,
                      iconColor: const Color(0xFFFFCC00),
                      title: 'Lumina Pro',
                      subtitle: 'v1.0.0 · Bit-Perfect Audio Player',
                    ),
                    const _Divider(),
                    _SettingRow(
                      isDark: isDark,
                      icon: CupertinoIcons.waveform_path_ecg,
                      iconColor: const Color(0xFFFF3B30),
                      title: 'Audio Engine',
                      subtitle: 'AVAudioEngine · CoreAudio · Direct',
                    ),
                  ],
                ),

                const SizedBox(height: 24),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  void _showThemePicker(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showCupertinoModalPopup(
      context: context,
      builder: (_) => CupertinoActionSheet(
        title: const Text('Appearance'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              themeNotifier.value = ThemeMode.system;
              Navigator.pop(context);
            },
            child: const Text('System Default'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              themeNotifier.value = ThemeMode.light;
              Navigator.pop(context);
            },
            child: const Text('Light'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              themeNotifier.value = ThemeMode.dark;
              Navigator.pop(context);
            },
            child: const Text('Dark'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  void _showHowToAddMusic(BuildContext context, bool isDark) {
    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('How to Add Music'),
        content: const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text(
            '1. Connect your iPhone to your Mac or PC.\n'
            '2. Open Finder (Mac) or iTunes (PC).\n'
            '3. Go to Files → Lumina Pro.\n'
            '4. Drag FLAC / WAV / MP3 files into the folder.\n'
            '5. Pull down to refresh your Library.\n\n'
            'Alternatively, use the Files app to copy music from iCloud Drive or other sources.',
            textAlign: TextAlign.left,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}

// ── Shared Section Widgets ─────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 8),
      child: Text(
        title,
        style: const TextStyle(
          color: LuminaColors.labelSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _GroupedSection extends StatelessWidget {
  final bool isDark;
  final List<Widget> children;

  const _GroupedSection({required this.isDark, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? LuminaColors.bg1 : LuminaColors.lightBg1,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? LuminaColors.bg3.withOpacity(0.4)
              : LuminaColors.lightBg3,
          width: 0.5,
        ),
      ),
      child: Column(children: children),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Divider(
      height: 1,
      indent: 54,
      color: isDark ? LuminaColors.bg3 : LuminaColors.lightBg3,
    );
  }
}

class _SettingRow extends StatelessWidget {
  final bool isDark;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showChevron;

  const _SettingRow({
    required this.isDark,
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.showChevron = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            // Icon badge
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: iconColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: Colors.white, size: 17),
            ),
            const SizedBox(width: 12),
            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      color: isDark ? Colors.white : Colors.black,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: LuminaColors.labelSecondary,
                      ),
                    ),
                ],
              ),
            ),
            if (trailing != null) trailing!,
            if (showChevron)
              const Icon(CupertinoIcons.chevron_right,
                  color: LuminaColors.labelSecondary, size: 14),
          ],
        ),
      ),
    );
  }
}
