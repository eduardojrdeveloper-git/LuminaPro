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
  bool _showSearch = false;
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
          CupertinoActionSheetAction(
            onPressed: () {
              setState(() => _sortMode = SortMode.title);
              _applySort();
              Navigator.pop(context);
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Title'),
                if (_sortMode == SortMode.title) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.check, size: 16),
                ],
              ],
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              setState(() => _sortMode = SortMode.artist);
              _applySort();
              Navigator.pop(context);
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Artist'),
                if (_sortMode == SortMode.artist) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.check, size: 16),
                ],
              ],
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              setState(() => _sortMode = SortMode.album);
              _applySort();
              Navigator.pop(context);
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Album'),
                if (_sortMode == SortMode.album) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.check, size: 16),
                ],
              ],
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
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
          CupertinoSliverNavigationBar(
            largeTitle: Text(
              'Library',
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black,
                fontFamily: '.SF Pro Display',
              ),
            ),
            backgroundColor: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.8),
            border: null,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _showSearch = true;
                      _searchFocus.requestFocus();
                    });
                  },
                  child: const Icon(CupertinoIcons.search, color: LuminaColors.accent),
                ),
                const SizedBox(width: 16),
                GestureDetector(
                  onTap: _showSortMenu,
                  child: const Icon(CupertinoIcons.sort_down, color: LuminaColors.accent),
                ),
                const SizedBox(width: 16),
                GestureDetector(
                  onTap: _refreshLibrary,
                  child: const Icon(CupertinoIcons.arrow_2_circlepath, color: LuminaColors.accent),
                ),
              ],
            ),
          ),
          SliverToBoxAdapter(
            child: Column(
              children: [
                // ── Animated Search Bar ────────────────────────────────────
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  height: _showSearch ? 52 : 0,
                  child: _showSearch
                      ? Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: CupertinoSearchTextField(
                                  controller: _searchCtrl,
                                  focusNode: _searchFocus,
                                  placeholder: 'Search music...',
                                  style: TextStyle(color: isDark ? Colors.white : Colors.black),
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _showSearch = false;
                                    _searchCtrl.clear();
                                    _searchFocus.unfocus();
                                  });
                                },
                                child: const Text(
                                  'Cancel',
                                  style: TextStyle(color: LuminaColors.accent),
                                ),
                              ),
                            ],
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                // ── Tabs ───────────────────────────────────────────────────
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  width: double.infinity,
                  child: CupertinoSlidingSegmentedControl<int>(
                    groupValue: _tabController.index,
                    children: const {
                      0: Text('Songs', style: TextStyle(fontSize: 13)),
                      1: Text('Artists', style: TextStyle(fontSize: 13)),
                      2: Text('Albums', style: TextStyle(fontSize: 13)),
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
                padding: const EdgeInsets.only(bottom: 100), // Avoid MiniPlayer
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildSongsList(),
                    _buildGroupedList(groupBy: (s) => s.artist, icon: CupertinoIcons.person_fill),
                    _buildAlbumsView(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildSongsList() {
    final songs = _displayedSongs;
    if (songs.isEmpty) return _buildEmptyState();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: songs.length,
      separatorBuilder: (_, __) => Divider(
        color: isDark ? LuminaColors.bg3 : LuminaColors.lightBg3,
        indent: 76,
        height: 1,
      ),
      itemBuilder: (context, index) {
        final song = songs[index];
        final isPlaying = PlayerService().currentSong.value?.path == song.path;
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 48,
              height: 48,
              child: song.coverArt != null
                  ? Image.memory(song.coverArt!, fit: BoxFit.cover)
                  : Container(
                      color: isDark ? LuminaColors.bg2 : LuminaColors.lightBg2,
                      child: const Icon(CupertinoIcons.music_note, color: LuminaColors.labelSecondary, size: 20),
                    ),
            ),
          ),
          title: Text(
            song.title,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: isPlaying ? LuminaColors.accent : (isDark ? Colors.white : Colors.black87),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            '${song.artist} · ${song.album}',
            style: const TextStyle(color: LuminaColors.labelSecondary, fontSize: 13),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () => PlayerService().playQueue(_displayedSongs, initialIndex: index),
        );
      },
    );
  }

  Widget _buildGroupedList({required String Function(AudioFile) groupBy, required IconData icon}) {
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
        for (var s in groupSongs) { if (s.coverArt != null) { cover = s.coverArt; break; } }

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          leading: ClipOval(
            child: SizedBox(
              width: 48,
              height: 48,
              child: cover != null
                  ? Image.memory(cover, fit: BoxFit.cover)
                  : Container(
                      color: isDark ? LuminaColors.bg2 : LuminaColors.lightBg2,
                      child: Icon(icon, color: LuminaColors.labelSecondary, size: 22),
                    ),
            ),
          ),
          title: Text(
            groupName,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          subtitle: Text(
            '${groupSongs.length} songs',
            style: const TextStyle(color: LuminaColors.labelSecondary, fontSize: 13),
          ),
          trailing: const Icon(CupertinoIcons.chevron_right, color: LuminaColors.labelSecondary, size: 14),
          onTap: () {
            Navigator.push(context, CupertinoPageRoute(builder: (_) => DetailScreen(title: groupName, songs: groupSongs, coverArt: cover)));
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
    for (var song in songs) { grouped.putIfAbsent(song.album, () => []).add(song); }
    final keys = grouped.keys.toList()..sort();

    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 20,
        childAspectRatio: 0.8,
      ),
      itemCount: keys.length,
      itemBuilder: (context, index) {
        final albumName = keys[index];
        final albumSongs = grouped[albumName]!;
        Uint8List? cover;
        for (var s in albumSongs) { if (s.coverArt != null) { cover = s.coverArt; break; } }
        return GestureDetector(
          onTap: () {
            Navigator.push(context, CupertinoPageRoute(builder: (_) => DetailScreen(title: albumName, songs: albumSongs, coverArt: cover)));
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: cover != null
                      ? Image.memory(cover, fit: BoxFit.cover, width: double.infinity)
                      : Container(
                          color: isDark ? LuminaColors.bg2 : LuminaColors.lightBg2,
                          child: const Center(child: Icon(CupertinoIcons.music_albums, color: LuminaColors.labelSecondary, size: 40)),
                        ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                albumName,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                albumSongs.first.artist,
                style: const TextStyle(fontSize: 12, color: LuminaColors.labelSecondary),
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
          const Icon(CupertinoIcons.music_note_list, size: 64, color: LuminaColors.labelTertiary),
          const SizedBox(height: 16),
          const Text('No Music Found', style: TextStyle(color: LuminaColors.labelSecondary, fontSize: 17, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          const Text('Transfer songs via the Files app.', textAlign: TextAlign.center, style: TextStyle(color: LuminaColors.labelTertiary, fontSize: 14)),
        ],
      ),
    );
  }
}
