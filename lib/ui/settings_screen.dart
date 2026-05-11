import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
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
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
            ),
            backgroundColor: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.8),
            border: null,
          ),

          SliverPadding(
            padding: const EdgeInsets.only(bottom: 120),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── AUDIO ENGINE ───────────────────────────────────────────
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
                        CupertinoPageRoute(builder: (_) => const EqAdvancedScreen()),
                      ),
                      showChevron: true,
                    ),
                    const _Divider(),
                    _SettingRow(
                      isDark: isDark,
                      icon: CupertinoIcons.arrow_right_arrow_left,
                      iconColor: const Color(0xFFFF9500),
                      title: 'Crossfade',
                      trailing: SizedBox(
                        width: 120,
                        child: CupertinoSlider(
                          value: _ps.crossfadeDuration,
                          min: 0,
                          max: 12,
                          onChanged: (v) => setState(() => _ps.crossfadeDuration = v),
                        ),
                      ),
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
                          icon: CupertinoIcons.paintbrush_fill,
                          iconColor: const Color(0xFFFF2D55),
                          title: 'Appearance',
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(label, style: const TextStyle(color: LuminaColors.labelSecondary, fontSize: 14)),
                              const SizedBox(width: 4),
                              const Icon(CupertinoIcons.chevron_right, color: LuminaColors.labelSecondary, size: 14),
                            ],
                          ),
                          onTap: () => _showThemePicker(context),
                        );
                      },
                    ),
                    const _Divider(),
                    ValueListenableBuilder<bool>(
                      valueListenable: rotateArtworkNotifier,
                      builder: (_, rotate, __) {
                        return _SettingRow(
                          isDark: isDark,
                          icon: CupertinoIcons.circle_grid_hex_fill,
                          iconColor: const Color(0xFF007AFF),
                          title: 'Rotating Album Art',
                          trailing: CupertinoSwitch(
                            value: rotate,
                            activeColor: LuminaColors.accent,
                            onChanged: (v) => rotateArtworkNotifier.value = v,
                          ),
                        );
                      },
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
                      title: 'Share Feedback',
                      showChevron: true,
                      onTap: () => Share.share('Lumina Pro is the best bit-perfect audio player for iOS! Download it now.'),
                    ),
                    const _Divider(),
                    _SettingRow(
                      isDark: isDark,
                      icon: CupertinoIcons.lock_shield_fill,
                      iconColor: const Color(0xFF34C759),
                      title: 'Support & Help',
                      showChevron: true,
                      onTap: () => _showSupportDialog(context),
                    ),
                  ],
                ),

                const SizedBox(height: 24),
                // Version footer
                Center(
                  child: Text(
                    'Lumina Pro 1.0.0\nMade with ♥ for audio enthusiasts',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: LuminaColors.labelTertiary,
                      fontSize: 12,
                      height: 1.5,
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
          CupertinoActionSheetAction(onPressed: () { themeNotifier.value = ThemeMode.system; Navigator.pop(context); }, child: const Text('System Default')),
          CupertinoActionSheetAction(onPressed: () { themeNotifier.value = ThemeMode.light; Navigator.pop(context); }, child: const Text('Light')),
          CupertinoActionSheetAction(onPressed: () { themeNotifier.value = ThemeMode.dark; Navigator.pop(context); }, child: const Text('Dark')),
        ],
        cancelButton: CupertinoActionSheetAction(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      ),
    );
  }

  void _showSupportDialog(BuildContext context) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Support'),
        content: const Text('Need help or have a suggestion? Contact us at support@luminapro.com'),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.pop(ctx),
          ),
        ],
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
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 10),
      child: Text(title, style: const TextStyle(color: LuminaColors.labelSecondary, fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
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
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: isDark ? LuminaColors.bg1 : LuminaColors.lightBg1,
        borderRadius: BorderRadius.circular(12),
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
    return Divider(height: 1, indent: 56, color: isDark ? LuminaColors.bg3.withOpacity(0.5) : LuminaColors.lightBg3);
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

  const _SettingRow({required this.isDark, required this.icon, required this.iconColor, required this.title, this.subtitle, this.trailing, this.onTap, this.showChevron = false});

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 30, height: 30,
              decoration: BoxDecoration(color: iconColor, borderRadius: BorderRadius.circular(7)),
              child: Icon(icon, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 16, color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.w400)),
                  if (subtitle != null) Text(subtitle!, style: const TextStyle(fontSize: 12, color: LuminaColors.labelSecondary)),
                ],
              ),
            ),
            if (trailing != null) trailing!,
            if (showChevron) const Icon(CupertinoIcons.chevron_right, color: LuminaColors.labelSecondary, size: 14),
          ],
        ),
      ),
    );
  }
}
