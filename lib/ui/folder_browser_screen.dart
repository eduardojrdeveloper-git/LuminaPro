import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../services/library_service.dart';
import '../services/player_service.dart';
import '../main.dart' show LuminaColors;
import 'library_screen.dart' show showSongMenuGlobal; // I will need to expose _showSongMenu

class FolderBrowserScreen extends StatefulWidget {
  final List<AudioFile> songs;
  
  const FolderBrowserScreen({super.key, required this.songs});

  @override
  State<FolderBrowserScreen> createState() => _FolderBrowserScreenState();
}

class _FolderBrowserScreenState extends State<FolderBrowserScreen> {
  final List<String> _navStack = [];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return CupertinoPageScaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      navigationBar: CupertinoNavigationBar(
        middle: Text(_navStack.isEmpty ? 'Music Folders' : _navStack.last),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.85),
        leading: CupertinoNavigationBarBackButton(
          color: LuminaColors.accent,
          onPressed: () {
            if (_navStack.isNotEmpty) {
              setState(() => _navStack.removeLast());
            } else {
              Navigator.pop(context);
            }
          },
        ),
      ),
      child: SafeArea(
        child: _buildBrowser(isDark),
      ),
    );
  }

  Widget _buildBrowser(bool isDark) {
    if (_navStack.isEmpty) {
      // Level 0: Local vs GDrive
      return ListView(
        children: [
          _FolderRow(
            title: 'Local',
            icon: CupertinoIcons.device_phone_portrait,
            isDark: isDark,
            onTap: () => setState(() => _navStack.add('Local')),
          ),
          Divider(color: isDark ? LuminaColors.bg3 : LuminaColors.lightBg3, indent: 64, height: 1),
          _FolderRow(
            title: 'GDrive',
            icon: CupertinoIcons.cloud,
            isDark: isDark,
            onTap: () => setState(() => _navStack.add('GDrive')),
          ),
        ],
      );
    }

    final isLocal = _navStack[0] == 'Local';
    var filteredSongs = widget.songs.where((s) => s.isLocal == isLocal).toList();

    if (_navStack.length == 1) {
      // Level 1: Group by Album Artist
      final Map<String, List<AudioFile>> grouped = {};
      for (var s in filteredSongs) {
        var aa = (s.albumArtist.trim().isNotEmpty && s.albumArtist != 'Unknown Artist' && s.albumArtist != 'GDrive' && s.albumArtist != 'Cloud') ? s.albumArtist : 'No Metadata';
        grouped.putIfAbsent(aa, () => []).add(s);
      }
      final keys = grouped.keys.toList()..sort();
      return ListView.separated(
        itemCount: keys.length,
        separatorBuilder: (_, __) => Divider(color: isDark ? LuminaColors.bg3 : LuminaColors.lightBg3, indent: 64, height: 1),
        itemBuilder: (context, i) {
          final aa = keys[i];
          return _FolderRow(
            title: aa,
            subtitle: '${grouped[aa]!.length} songs',
            icon: CupertinoIcons.person_2_fill,
            isDark: isDark,
            onTap: () => setState(() => _navStack.add(aa)),
          );
        },
      );
    }

    // Filter by Album Artist
    final targetAA = _navStack[1];
    filteredSongs = filteredSongs.where((s) {
      var aa = (s.albumArtist.trim().isNotEmpty && s.albumArtist != 'Unknown Artist' && s.albumArtist != 'GDrive' && s.albumArtist != 'Cloud') ? s.albumArtist : 'No Metadata';
      return aa == targetAA;
    }).toList();

    if (_navStack.length == 2) {
      // Level 2: Group by Album
      final Map<String, List<AudioFile>> grouped = {};
      for (var s in filteredSongs) {
        var al = (s.album.trim().isNotEmpty && s.album != 'Unknown Album' && s.album != 'GDrive' && s.album != 'Cloud') ? s.album : 'No Metadata';
        grouped.putIfAbsent(al, () => []).add(s);
      }
      final keys = grouped.keys.toList()..sort();
      return ListView.separated(
        itemCount: keys.length,
        separatorBuilder: (_, __) => Divider(color: isDark ? LuminaColors.bg3 : LuminaColors.lightBg3, indent: 64, height: 1),
        itemBuilder: (context, i) {
          final al = keys[i];
          return _FolderRow(
            title: al,
            subtitle: '${grouped[al]!.length} songs',
            icon: CupertinoIcons.music_albums,
            isDark: isDark,
            onTap: () => setState(() => _navStack.add(al)),
          );
        },
      );
    }

    // Filter by Album
    final targetAl = _navStack[2];
    filteredSongs = filteredSongs.where((s) {
      var al = (s.album.trim().isNotEmpty && s.album != 'Unknown Album' && s.album != 'GDrive' && s.album != 'Cloud') ? s.album : 'No Metadata';
      return al == targetAl;
    }).toList();

    // Level 3: Songs List
    final ps = PlayerService();
    return ListView.builder(
      itemCount: filteredSongs.length,
      itemBuilder: (context, index) {
        final song = filteredSongs[index];
        return ValueListenableBuilder<AudioFile?>(
          valueListenable: ps.currentSong,
          builder: (ctx, currentSong, _) {
            final isPlaying = currentSong?.path == song.path;
            return Column(
              children: [
                _StandaloneSongRow(
                  song: song,
                  isPlaying: isPlaying,
                  isDark: isDark,
                  onTap: () => ps.playQueue(filteredSongs, initialIndex: index),
                  onMore: () => showSongMenuGlobal(context, song, index, filteredSongs),
                ),
                if (index < filteredSongs.length - 1)
                  Divider(color: isDark ? LuminaColors.bg3 : LuminaColors.lightBg3, indent: 76, height: 1),
              ],
            );
          },
        );
      },
    );
  }
}

class _FolderRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final bool isDark;
  final VoidCallback onTap;

  const _FolderRow({
    required this.title,
    this.subtitle,
    required this.icon,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: isDark ? LuminaColors.bg3 : LuminaColors.lightBg3,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: LuminaColors.accent),
        ),
        title: Text(title, style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.w600)),
        subtitle: subtitle != null ? Text(subtitle!, style: TextStyle(color: LuminaColors.labelSecondary, fontSize: 13)) : null,
        trailing: const Icon(CupertinoIcons.chevron_forward, color: LuminaColors.labelSecondary, size: 18),
        onTap: onTap,
      ),
    );
  }
}

class _StandaloneSongRow extends StatelessWidget {
  final AudioFile song;
  final bool isPlaying;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback onMore;

  const _StandaloneSongRow({
    required this.song,
    required this.isPlaying,
    required this.isDark,
    required this.onTap,
    required this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isDark ? LuminaColors.bg3 : LuminaColors.lightBg3,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: song.coverArt != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.memory(song.coverArt!, fit: BoxFit.cover),
                      )
                    : const Icon(CupertinoIcons.music_note, color: LuminaColors.labelSecondary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: isPlaying ? FontWeight.bold : FontWeight.w500,
                        color: isPlaying ? LuminaColors.accent : (isDark ? Colors.white : Colors.black),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      song.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14, color: LuminaColors.labelSecondary),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(CupertinoIcons.ellipsis, color: LuminaColors.labelSecondary),
                onPressed: onMore,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
