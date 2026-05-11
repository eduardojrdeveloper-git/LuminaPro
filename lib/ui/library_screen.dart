import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../services/library_service.dart';
import '../services/player_service.dart';
import '../main.dart' show LuminaColors;
import 'detail_screen.dart';

enum SortMode { title, artist, album }

class LibraryScreen extends StatefulWidget {
  @override
  _LibraryScreenState createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen>
    with SingleTickerProviderStateMixin {
  List<AudioFile> _allSongs = [];
  List<AudioFile> _filtered = [];
  bool _isLoading = true;
  SortMode _sortMode = SortMode.title;
  late TabController _tabController;
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() => setState(() {}));
    _refreshLibrary();
    _searchCtrl.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _refreshLibrary() async {
    setState(() => _isLoading = true);
    final songs = await LibraryService.scanMusic();
    setState(() {
      _allSongs = songs;
      _applySort();
      _isLoading = false;
    });
  }

  void _applyFilter() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filtered = List.from(_allSongs);
      } else {
        _filtered = _allSongs.where((s) {
          return s.title.toLowerCase().contains(q) ||
              s.artist.toLowerCase().contains(q) ||
              s.album.toLowerCase().contains(q);
        }).toList();
      }
      _applySort(applyToFiltered: true);
    });
  }

  void _applySort({bool applyToFiltered = false}) {
    int Function(AudioFile, AudioFile) comparator;
    switch (_sortMode) {
      case SortMode.title:
        comparator = (a, b) => a.title.compareTo(b.title);
        break;
      case SortMode.artist:
        comparator = (a, b) => a.artist.compareTo(b.artist);
        break;
      case SortMode.album:
        comparator = (a, b) => a.album.compareTo(b.album);
        break;
    }
    _allSongs.sort(comparator);
    if (!applyToFiltered) _filtered = List.from(_allSongs);
    _filtered.sort(comparator);
  }

  List<AudioFile> get _displayedSongs =>
      _searchCtrl.text.isEmpty ? _allSongs : _filtered;

  void _showSortMenu() {
    showCupertinoModalPopup(
      context: context,
      builder: (_) => CupertinoActionSheet(
        title: const Text('Sort By'),
        actions: [
          _sortAction('Title', SortMode.title),
          _sortAction('Artist', SortMode.artist),
          _sortAction('Album', SortMode.album),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  CupertinoActionSheetAction _sortAction(String label, SortMode mode) {
    final isActive = _sortMode == mode;
    return CupertinoActionSheetAction(
      onPressed: () {
        setState(() => _sortMode = mode);
        _applySort();
        Navigator.pop(context);
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isActive) ...[
            const Icon(CupertinoIcons.checkmark, size: 16,
                color: LuminaColors.accent),
            const SizedBox(width: 8),
          ],
          Text(label,
              style: TextStyle(
                  color: isActive ? LuminaColors.accent : null,
                  fontWeight:
                      isActive ? FontWeight.w600 : FontWeight.normal)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          // ── Large Title Nav Bar ──────────────────────────────────────────
          CupertinoSliverNavigationBar(
            largeTitle: Text(
              'Library',
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
            ),
            backgroundColor:
                Theme.of(context).scaffoldBackgroundColor.withOpacity(0.85),
            border: null,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: _showSortMenu,
                  child: const Icon(CupertinoIcons.sort_down,
                      color: LuminaColors.accent, size: 22),
                ),
                const SizedBox(width: 4),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: _refreshLibrary,
                  child: const Icon(CupertinoIcons.arrow_2_circlepath,
                      color: LuminaColors.accent, size: 22),
                ),
              ],
            ),
          ),
          // ── Search + Tabs ────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Column(
              children: [
                // Always-visible search bar (Apple Music style)
                Padding(
                  padding:
                      const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: CupertinoSearchTextField(
                    controller: _searchCtrl,
                    focusNode: _searchFocus,
                    placeholder: 'Artists, Songs, Lyrics, and More',
                    style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                        fontSize: 16),
                    backgroundColor: isDark
                        ? LuminaColors.bg2.withOpacity(0.9)
                        : LuminaColors.lightBg2.withOpacity(0.9),
                  ),
                ),
                // Segmented control
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: CupertinoSlidingSegmentedControl<int>(
                    groupValue: _tabController.index,
                    thumbColor: isDark ? LuminaColors.bg3 : Colors.white,
                    backgroundColor:
                        isDark ? LuminaColors.bg2 : LuminaColors.lightBg2,
                    children: {
                      0: _segLabel('Songs', _tabController.index == 0, isDark),
                      1: _segLabel(
                          'Artists', _tabController.index == 1, isDark),
                      2: _segLabel('Albums', _tabController.index == 2, isDark),
                    },
                    onValueChanged: (v) {
                      if (v != null) setState(() => _tabController.index = v);
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
        body: _isLoading
            ? const Center(child: CupertinoActivityIndicator(radius: 14))
            : Padding(
                padding: const EdgeInsets.only(bottom: 100),
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildSongsList(),
                    _buildGroupedList(
                        groupBy: (s) => s.artist,
                        icon: CupertinoIcons.person_fill),
                    _buildAlbumsView(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _segLabel(String text, bool isActive, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
          color: isActive
              ? (isDark ? Colors.white : Colors.black)
              : LuminaColors.labelSecondary,
        ),
      ),
    );
  }

  Widget _buildSongsList() {
    final songs = _displayedSongs;
    if (songs.isEmpty) return _buildEmptyState();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: songs.length + 1, // +1 for shuffle hero
      itemBuilder: (context, index) {
        // ── Shuffle Hero Button ──────────────────────────────────────────
        if (index == 0) {
          return _ShuffleHeroButton(songs: songs);
        }
        final song = songs[index - 1];
        final isPlaying =
            PlayerService().currentSong.value?.path == song.path;
        return Column(
          children: [
            _SongRow(
              song: song,
              isPlaying: isPlaying,
              isDark: isDark,
              onTap: () => PlayerService()
                  .playQueue(_displayedSongs, initialIndex: index - 1),
              onMore: () => _showSongMenu(context, song, index - 1),
            ),
            if (index < songs.length)
              Divider(
                color: isDark ? LuminaColors.bg3 : LuminaColors.lightBg3,
                indent: 76,
                height: 1,
              ),
          ],
        );
      },
    );
  }

  void _showSongMenu(BuildContext context, AudioFile song, int index) {
    showCupertinoModalPopup(
      context: context,
      builder: (_) => CupertinoActionSheet(
        title: Text(song.title,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        message: Text(song.artist),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              PlayerService()
                  .playQueue(_displayedSongs, initialIndex: index);
            },
            child: const Text('Play Now'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Add to Playlist'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Love'),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context),
            child: const Text('Delete from Library'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  Widget _buildGroupedList(
      {required String Function(AudioFile) groupBy,
      required IconData icon}) {
    final songs = _displayedSongs;
    if (songs.isEmpty) return _buildEmptyState();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final Map<String, List<AudioFile>> grouped = {};
    for (var song in songs) {
      final key = groupBy(song);
      grouped.putIfAbsent(key, () => []).add(song);
    }
    final keys = grouped.keys.toList()..sort();

    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: keys.length,
      separatorBuilder: (_, __) => Divider(
        color: isDark ? LuminaColors.bg3 : LuminaColors.lightBg3,
        indent: 76,
        height: 1,
      ),
      itemBuilder: (context, index) {
        final groupName = keys[index];
        final groupSongs = grouped[groupName]!;
        Uint8List? cover;
        for (var s in groupSongs) {
          if (s.coverArt != null) {
            cover = s.coverArt;
            break;
          }
        }

        return ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          leading: ClipOval(
            child: SizedBox(
              width: 48,
              height: 48,
              child: cover != null
                  ? Image.memory(cover, fit: BoxFit.cover)
                  : Container(
                      color:
                          isDark ? LuminaColors.bg2 : LuminaColors.lightBg2,
                      child: Icon(icon,
                          color: LuminaColors.labelSecondary, size: 22),
                    ),
            ),
          ),
          title: Text(
            groupName,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: isDark ? Colors.white : Colors.black87,
              letterSpacing: -0.2,
            ),
          ),
          subtitle: Text(
            '${groupSongs.length} songs',
            style: const TextStyle(
                color: LuminaColors.labelSecondary, fontSize: 13),
          ),
          trailing: const Icon(CupertinoIcons.chevron_right,
              color: LuminaColors.labelTertiary, size: 14),
          onTap: () {
            Navigator.push(
              context,
              CupertinoPageRoute(
                builder: (_) => DetailScreen(
                    title: groupName,
                    songs: groupSongs,
                    coverArt: cover),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAlbumsView() {
    final songs = _displayedSongs;
    if (songs.isEmpty) return _buildEmptyState();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final Map<String, List<AudioFile>> grouped = {};
    for (var song in songs) {
      grouped.putIfAbsent(song.album, () => []).add(song);
    }
    final keys = grouped.keys.toList()..sort();

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 20,
        childAspectRatio: 0.78,
      ),
      itemCount: keys.length,
      itemBuilder: (context, index) {
        final albumName = keys[index];
        final albumSongs = grouped[albumName]!;
        Uint8List? cover;
        for (var s in albumSongs) {
          if (s.coverArt != null) {
            cover = s.coverArt;
            break;
          }
        }
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              CupertinoPageRoute(
                builder: (_) => DetailScreen(
                    title: albumName,
                    songs: albumSongs,
                    coverArt: cover),
              ),
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.4 : 0.18),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: cover != null
                        ? Image.memory(cover,
                            fit: BoxFit.cover, width: double.infinity)
                        : Container(
                            color: isDark
                                ? LuminaColors.bg2
                                : LuminaColors.lightBg2,
                            child: const Center(
                                child: Icon(CupertinoIcons.music_albums,
                                    color: LuminaColors.labelSecondary,
                                    size: 40)),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                albumName,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                  letterSpacing: -0.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                albumSongs.first.artist,
                style: const TextStyle(
                    fontSize: 12, color: LuminaColors.labelSecondary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(CupertinoIcons.music_note_list,
              size: 64, color: LuminaColors.labelTertiary),
          const SizedBox(height: 16),
          const Text('No Music Found',
              style: TextStyle(
                  color: LuminaColors.labelSecondary,
                  fontSize: 17,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          const Text('Transfer songs via the Files app.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: LuminaColors.labelTertiary, fontSize: 14)),
        ],
      ),
    );
  }
}

// ── Shuffle Hero Button ───────────────────────────────────────────────────────
class _ShuffleHeroButton extends StatelessWidget {
  final List<AudioFile> songs;
  const _ShuffleHeroButton({required this.songs});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Row(
        children: [
          Expanded(
            child: _ActionButton(
              icon: CupertinoIcons.play_fill,
              label: 'Play',
              filled: true,
              isDark: isDark,
              onTap: () => PlayerService().playQueue(songs, initialIndex: 0),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _ActionButton(
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
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool filled;
  final bool isDark;
  final VoidCallback onTap;

  const _ActionButton({
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
        height: 44,
        decoration: BoxDecoration(
          color: filled
              ? LuminaColors.accent
              : (isDark ? LuminaColors.bg2 : LuminaColors.lightBg2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 15,
                color: filled
                    ? Colors.white
                    : (isDark ? Colors.white : Colors.black87)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: filled
                    ? Colors.white
                    : (isDark ? Colors.white : Colors.black87),
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Song Row ─────────────────────────────────────────────────────────────────
class _SongRow extends StatelessWidget {
  final AudioFile song;
  final bool isPlaying;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback onMore;

  const _SongRow({
    required this.song,
    required this.isPlaying,
    required this.isDark,
    required this.onTap,
    required this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Row(
          children: [
            // Artwork
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: 48,
                height: 48,
                child: song.coverArt != null
                    ? Image.memory(song.coverArt!, fit: BoxFit.cover)
                    : Container(
                        color: isDark
                            ? LuminaColors.bg2
                            : LuminaColors.lightBg2,
                        child: const Icon(CupertinoIcons.music_note,
                            color: LuminaColors.labelSecondary, size: 20),
                      ),
              ),
            ),
            const SizedBox(width: 14),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    song.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 16,
                      color: isPlaying
                          ? LuminaColors.accent
                          : (isDark ? Colors.white : Colors.black87),
                      letterSpacing: -0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    song.artist,
                    style: const TextStyle(
                        color: LuminaColors.labelSecondary, fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // More button
            GestureDetector(
              onTap: onMore,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Icon(
                  CupertinoIcons.ellipsis,
                  color: LuminaColors.labelSecondary,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
