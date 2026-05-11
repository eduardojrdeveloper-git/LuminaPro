import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../main.dart' show LuminaColors, themeNotifier, rotateArtworkNotifier;
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

    return CupertinoPageScaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      child: CustomScrollView(
        slivers: [
          CupertinoSliverNavigationBar(
            largeTitle: Text(
              'Settings',
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
            ),
            backgroundColor:
                Theme.of(context).scaffoldBackgroundColor.withOpacity(0.85),
            border: null,
          ),

          SliverPadding(
            padding: const EdgeInsets.only(bottom: 120),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── PLAYBACK ────────────────────────────────────────────────
                _SectionHeader('PLAYBACK'),
                _GroupedSection(
                  isDark: isDark,
                  children: [
                    // Crossfade
                    StatefulBuilder(builder: (context, setRowState) {
                      return _SettingRow(
                        isDark: isDark,
                        icon: CupertinoIcons.arrow_right_arrow_left,
                        iconColor: const Color(0xFFFF9500),
                        title: 'Crossfade',
                        subtitle:
                            '${_ps.crossfadeDuration.toStringAsFixed(1)}s',
                        trailing: SizedBox(
                          width: 130,
                          child: CupertinoSlider(
                            value: _ps.crossfadeDuration,
                            min: 0,
                            max: 12,
                            activeColor: LuminaColors.accent,
                            onChanged: (v) => setRowState(
                                () => _ps.crossfadeDuration = v),
                          ),
                        ),
                      );
                    }),
                    const _Divider(),
                    // Gapless
                    _SettingRow(
                      isDark: isDark,
                      icon: CupertinoIcons.waveform_path,
                      iconColor: const Color(0xFF34C759),
                      title: 'Gapless Playback',
                      trailing: CupertinoSwitch(
                        value: true,
                        activeColor: LuminaColors.accent,
                        onChanged: (_) {},
                      ),
                    ),
                    const _Divider(),
                    // High Quality
                    _SettingRow(
                      isDark: isDark,
                      icon: CupertinoIcons.antenna_radiowaves_left_right,
                      iconColor: const Color(0xFF007AFF),
                      title: 'High Quality Streaming',
                      trailing: CupertinoSwitch(
                        value: true,
                        activeColor: LuminaColors.accent,
                        onChanged: (_) {},
                      ),
                    ),
                  ],
                ),

                // ── AUDIO ENGINE ─────────────────────────────────────────────
                _SectionHeader('AUDIO ENGINE'),
                _GroupedSection(
                  isDark: isDark,
                  children: [
                    _SettingRow(
                      isDark: isDark,
                      icon: CupertinoIcons.waveform_path_ecg,
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
                    _SettingRow(
                      isDark: isDark,
                      icon: CupertinoIcons.waveform,
                      iconColor: const Color(0xFFFF2D55),
                      title: 'Sound Check',
                      subtitle: 'Normalize song volume',
                      trailing: CupertinoSwitch(
                        value: false,
                        activeColor: LuminaColors.accent,
                        onChanged: (_) {},
                      ),
                    ),
                  ],
                ),

                // ── INTERFACE ─────────────────────────────────────────────────
                _SectionHeader('INTERFACE'),
                _GroupedSection(
                  isDark: isDark,
                  children: [
                    // Appearance
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
                          icon: CupertinoIcons.paintbrush_fill,
                          iconColor: const Color(0xFFFF2D55),
                          title: 'Appearance',
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(label,
                                  style: const TextStyle(
                                      color: LuminaColors.labelSecondary,
                                      fontSize: 14)),
                              const SizedBox(width: 4),
                              const Icon(CupertinoIcons.chevron_right,
                                  color: LuminaColors.labelSecondary,
                                  size: 14),
                            ],
                          ),
                          onTap: () => _showThemePicker(context),
                        );
                      },
                    ),
                    const _Divider(),
                    // Rotating Album Art
                    ValueListenableBuilder<bool>(
                      valueListenable: rotateArtworkNotifier,
                      builder: (_, rotate, __) {
                        return _SettingRow(
                          isDark: isDark,
                          icon: CupertinoIcons.circle_grid_hex_fill,
                          iconColor: const Color(0xFF007AFF),
                          title: 'Rotating Album Art',
                          subtitle: 'Vinyl disc style in Now Playing',
                          trailing: CupertinoSwitch(
                            value: rotate,
                            activeColor: LuminaColors.accent,
                            onChanged: (v) =>
                                rotateArtworkNotifier.value = v,
                          ),
                        );
                      },
                    ),
                  ],
                ),

                // ── ABOUT ────────────────────────────────────────────────────
                _SectionHeader('ABOUT'),
                _GroupedSection(
                  isDark: isDark,
                  children: [
                    _SettingRow(
                      isDark: isDark,
                      icon: CupertinoIcons.info_circle_fill,
                      iconColor: const Color(0xFFFFCC00),
                      title: 'Lumina Pro',
                      subtitle: 'v1.0.0 · Bit-Perfect Audio',
                    ),
                    const _Divider(),
                    _SettingRow(
                      isDark: isDark,
                      icon: CupertinoIcons.heart_fill,
                      iconColor: const Color(0xFFFF3B30),
                      title: 'Rate on App Store',
                      showChevron: true,
                      onTap: () {},
                    ),
                    const _Divider(),
                    _SettingRow(
                      isDark: isDark,
                      icon: CupertinoIcons.lock_shield_fill,
                      iconColor: const Color(0xFF34C759),
                      title: 'Privacy Policy',
                      showChevron: true,
                      onTap: () {},
                    ),
                  ],
                ),

                const SizedBox(height: 24),
                // Version footer
                Center(
                  child: Text(
                    'Lumina Pro 1.0.0\nMade with ♥ for audio enthusiasts',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: LuminaColors.labelTertiary,
                      fontSize: 12,
                      height: 1.6,
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  void _showThemePicker(BuildContext context) {
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
}

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
          fontWeight: FontWeight.w500,
          letterSpacing: 0.4,
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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.05)
              : Colors.black.withOpacity(0.04),
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
      indent: 56,
      color: isDark
          ? Colors.white.withOpacity(0.07)
          : Colors.black.withOpacity(0.07),
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
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Icon container — standard iOS size 30×30
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: iconColor,
                borderRadius: BorderRadius.circular(7),
              ),
              child: Icon(icon, color: Colors.white, size: 17),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      color: isDark ? Colors.white : Colors.black,
                      fontWeight: FontWeight.w400,
                      letterSpacing: -0.2,
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
            if (showChevron && trailing == null)
              const Icon(CupertinoIcons.chevron_right,
                  color: LuminaColors.labelTertiary, size: 14),
          ],
        ),
      ),
    );
  }
}
