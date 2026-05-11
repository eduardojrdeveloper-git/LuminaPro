import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import '../main.dart' show LuminaColors, themeNotifier, rotateArtworkNotifier;
import '../services/player_service.dart';
import '../services/library_service.dart';
import '../services/google_drive_service.dart';
import 'eq_advanced_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _ps = PlayerService();

  Future<void> _importEqProfile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['txt'],
    );
    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      final content = await file.readAsString();
      // Apply the EQ content via PlayerService
      await _ps.updateEQFromContent(content);
      _showToast('EQ Profile Applied: ${result.files.single.name}');
    }
  }

  void _manageFolders() {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => _FolderManagerSheet(onUpdate: () => setState(() {})),
    );
  }

  void _showToast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

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
                // ── AUDIO PATH ──────────────────────────────────────────────
                _SectionHeader('BIT-PERFECT AUDIO PATH'),
                _GroupedSection(
                  isDark: isDark,
                  children: [
                    ValueListenableBuilder<Map<String, String>>(
                      valueListenable: _ps.audioPathNotifier,
                      builder: (_, path, __) {
                        return Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              _PathRow(label: 'SOURCE', value: path['Source']!, isDark: isDark),
                              _PathRow(label: 'ENGINE', value: path['DSP']!, isDark: isDark),
                              _PathRow(label: 'OUTPUT', value: path['Output']!, isDark: isDark, isLast: true),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),

                // ── LIBRARY ────────────────────────────────────────────────
                _SectionHeader('LIBRARY MANAGEMENT'),
                _GroupedSection(
                  isDark: isDark,
                  children: [
                    _SettingRow(
                      isDark: isDark,
                      icon: CupertinoIcons.folder_fill,
                      iconColor: const Color(0xFF007AFF),
                      title: 'Music Folders',
                      subtitle: '${LibraryService.scanPaths.length} folders included',
                      onTap: _manageFolders,
                      showChevron: true,
                    ),
                    const _Divider(),
                    _SettingRow(
                      isDark: isDark,
                      icon: CupertinoIcons.cloud_fill,
                      iconColor: const Color(0xFF34A853),
                      title: 'Google Drive',
                      subtitle: 'Stream or download FLACs from cloud',
                      onTap: () {
                        showCupertinoModalPopup(
                          context: context,
                          builder: (ctx) => _GoogleDriveSheet(onUpdate: () => setState(() {})),
                        );
                      },
                      showChevron: true,
                    ),
                  ],
                ),

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
                      icon: CupertinoIcons.doc_text_fill,
                      iconColor: const Color(0xFF34C759),
                      title: 'Import EQ Profile',
                      subtitle: 'Load .txt from Equalizer APO',
                      onTap: _importEqProfile,
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
                      subtitle: 'v1.1.0 · Bit-Perfect Audio',
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
                Center(
                  child: Text(
                    'Lumina Pro 1.1.0\nMade with ♥ for audio enthusiasts',
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

class _PathRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isDark;
  final bool isLast;
  const _PathRow({required this.label, required this.value, required this.isDark, this.isLast = false});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Column(
          children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: LuminaColors.accent, shape: BoxShape.circle)),
            if (!isLast) Container(width: 2, height: 20, color: LuminaColors.accent.withOpacity(0.3)),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: LuminaColors.labelTertiary)),
              Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black)),
              if (!isLast) const SizedBox(height: 12),
            ],
          ),
        ),
      ],
    );
  }
}

class _FolderManagerSheet extends StatefulWidget {
  final VoidCallback onUpdate;
  const _FolderManagerSheet({required this.onUpdate});
  @override
  State<_FolderManagerSheet> createState() => _FolderManagerSheetState();
}

class _FolderManagerSheetState extends State<_FolderManagerSheet> {
  late List<String> _paths;
  @override
  void initState() {
    super.initState();
    _paths = List.from(LibraryService.scanPaths);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Music Folders'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Text('Add'),
          onPressed: () async {
            String? path = await FilePicker.platform.getDirectoryPath();
            if (path != null) {
              setState(() => _paths.add(path));
              await LibraryService.updateScanPaths(_paths);
              widget.onUpdate();
            }
          },
        ),
      ),
      child: SafeArea(
        child: ListView.builder(
          itemCount: _paths.length,
          itemBuilder: (context, i) => ListTile(
            title: Text(_paths[i], style: TextStyle(fontSize: 14, color: isDark ? Colors.white : Colors.black)),
            trailing: CupertinoButton(
              padding: EdgeInsets.zero,
              child: const Icon(CupertinoIcons.delete, color: LuminaColors.destructive, size: 20),
              onPressed: () async {
                setState(() => _paths.removeAt(i));
                await LibraryService.updateScanPaths(_paths);
                widget.onUpdate();
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _GoogleDriveSheet extends StatefulWidget {
  final VoidCallback onUpdate;
  const _GoogleDriveSheet({required this.onUpdate});
  @override
  State<_GoogleDriveSheet> createState() => _GoogleDriveSheetState();
}

class _GoogleDriveSheetState extends State<_GoogleDriveSheet> {
  final GoogleDriveService _driveService = GoogleDriveService();
  bool _isLoading = false;
  
  // Navigation stack: List of {id, name}
  final List<Map<String, String>> _navStack = [{'id': 'root', 'name': 'My Drive'}];
  List<dynamic> _currentFolders = [];
  final Set<String> _selectedFolderIds = {};

  @override
  void initState() {
    super.initState();
    if (_driveService.isSignedIn) _fetchCurrentLevel();
  }

  Future<void> _fetchCurrentLevel() async {
    setState(() => _isLoading = true);
    try {
      final folders = await _driveService.listFolders(parentId: _navStack.last['id']!);
      setState(() => _currentFolders = folders);
    } catch (e) {
      _showToast('Error loading folders: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSignIn() async {
    setState(() => _isLoading = true);
    try {
      await _driveService.signIn();
      await _fetchCurrentLevel();
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _pushFolder(String id, String name) {
    setState(() => _navStack.add({'id': id, 'name': name}));
    _fetchCurrentLevel();
  }

  void _popFolder() {
    if (_navStack.length > 1) {
      setState(() => _navStack.removeLast());
      _fetchCurrentLevel();
    }
  }

  Future<void> _startScan() async {
    if (_selectedFolderIds.isEmpty) {
      _showToast('Select at least one folder');
      return;
    }
    setState(() => _isLoading = true);
    try {
      final songs = await _driveService.scanFoldersForFlacs(_selectedFolderIds.toList());
      LibraryService.addDriveSongs(songs);
      _showToast('Successfully indexed ${songs.length} cloud files');
      widget.onUpdate();
      Navigator.pop(context);
    } catch (e) {
      _showToast('Scan failed: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentDir = _navStack.last;

    return CupertinoPageScaffold(
      backgroundColor: isDark ? LuminaColors.bg1 : LuminaColors.lightBg1,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: (isDark ? LuminaColors.bg1 : LuminaColors.lightBg1).withOpacity(0.8),
        middle: Text(currentDir['name']!, style: TextStyle(color: isDark ? Colors.white : Colors.black)),
        leading: _navStack.length > 1 
            ? CupertinoButton(
                padding: EdgeInsets.zero,
                child: const Icon(CupertinoIcons.back),
                onPressed: _popFolder,
              )
            : null,
        trailing: _driveService.isSignedIn 
            ? CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _startScan,
                child: Text('Add (${_selectedFolderIds.length})', 
                    style: const TextStyle(fontWeight: FontWeight.w600, color: LuminaColors.accent)),
              )
            : null,
      ),
      child: SafeArea(
        child: _isLoading
            ? const Center(child: CupertinoActivityIndicator())
            : !_driveService.isSignedIn
                ? _buildLoginView(isDark)
                : _buildFolderList(isDark),
      ),
    );
  }

  Widget _buildLoginView(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(CupertinoIcons.cloud_fill, size: 80, color: Color(0xFF34A853)),
          const SizedBox(height: 24),
          const Text('Google Drive', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text('Select folders from your cloud storage to stream or download FLAC files directly to your library.',
                textAlign: TextAlign.center,
                style: TextStyle(color: LuminaColors.labelSecondary, fontSize: 14)),
          ),
          const SizedBox(height: 32),
          CupertinoButton.filled(
            borderRadius: BorderRadius.circular(25),
            onPressed: _handleSignIn,
            child: const Text('Sign in with Google', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildFolderList(bool isDark) {
    if (_currentFolders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(CupertinoIcons.folder_badge_minus, size: 48, color: LuminaColors.labelTertiary),
            const SizedBox(height: 12),
            Text('Empty folder', style: TextStyle(color: LuminaColors.labelSecondary)),
          ],
        ),
      );
    }

    return Column(
      children: [
        if (_navStack.length == 1)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                const Icon(CupertinoIcons.info_circle, size: 16, color: LuminaColors.accent),
                const SizedBox(width: 8),
                Expanded(child: Text('Tap folder to open, check circle to select for scanning.', 
                    style: TextStyle(fontSize: 12, color: LuminaColors.labelSecondary))),
              ],
            ),
          ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 12),
            itemCount: _currentFolders.length,
            separatorBuilder: (_, __) => Divider(height: 1, indent: 60, color: isDark ? LuminaColors.bg3 : LuminaColors.lightBg3),
            itemBuilder: (context, i) {
              final folder = _currentFolders[i];
              final isSelected = _selectedFolderIds.contains(folder.id);
              
              return Material(
                color: Colors.transparent,
                child: ListTile(
                  onTap: () => _pushFolder(folder.id!, folder.name ?? 'Unknown'),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: const Icon(CupertinoIcons.folder_fill, color: Color(0xFF007AFF), size: 28),
                  title: Text(folder.name ?? 'Unknown', style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.w500)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () {
                          setState(() {
                            if (isSelected) _selectedFolderIds.remove(folder.id);
                            else _selectedFolderIds.add(folder.id!);
                          });
                        },
                        child: Icon(
                          isSelected ? CupertinoIcons.check_mark_circled_solid : CupertinoIcons.circle,
                          color: isSelected ? LuminaColors.accent : LuminaColors.labelTertiary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(CupertinoIcons.chevron_right, size: 14, color: LuminaColors.labelTertiary),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showToast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }
}
