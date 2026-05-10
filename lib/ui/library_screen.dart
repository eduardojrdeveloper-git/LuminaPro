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
  bool _albumsGrid = true;
  SortMode _sortMode = SortMode.title;
  late TabController _tabController;
  final TextEditingController _searchCtrl = TextEditingController();

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
                  const Icon(CupertinoIcons.checkmark, size: 16),
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
                  const Icon(CupertinoIcons.checkmark, size: 16),
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
                  const Icon(CupertinoIcons.checkmark, size: 16),
                ],
              ],
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDestructiveAction: false,
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
          SliverAppBar(
            pinned: true,
            floating: true,
            snap: true,
            expandedHeight: 100,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            surfaceTintColor: Colors.transparent,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
              title: Text(
                'Library',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: Icon(
                  _showSearch
                      ? CupertinoIcons.xmark_circle_fill
                      : CupertinoIcons.search,
                  color: LuminaColors.accent,
                ),
                onPressed: () {
                  setState(() {
                    _showSearch = !_showSearch;
                    if (!_showSearch) {
                      _searchCtrl.clear();
                    }
                  });
                },
              ),
              IconButton(
                icon: const Icon(CupertinoIcons.sort_down,
                    color: LuminaColors.accent),
                onPressed: _showSortMenu,
              ),
              IconButton(
                icon: const Icon(CupertinoIcons.refresh,
                    color: LuminaColors.accent),
                onPressed: _refreshLibrary,
              ),
            ],
            bottom: PreferredSize(
              preferredSize: Size.fromHeight(_showSearch ? 100 : 48),
              child: Column(
                children: [
                  if (_showSearch)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Container(
                        height: 40,
                        decoration: BoxDecoration(
                          color: isDark
                              ? LuminaColors.bg2
                              : LuminaColors.lightBg2,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TextField(
                          controller: _searchCtrl,
                          autofocus: true,
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black,
                            fontSize: 15,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Search songs, artists, albums…',
                            hintStyle: const TextStyle(
                              color: LuminaColors.labelSecondary,
                              fontSize: 15,
                            ),
                            prefixIcon: const Icon(
                              CupertinoIcons.search,
                              color: LuminaColors.labelSecondary,
                              size: 18,
                            ),
                            border: InputBorder.none,
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                    ),
                  TabBar(
                    controller: _tabController,
                    indicatorColor: LuminaColors.accent,
                    labelColor: LuminaColors.accent,
                    unselectedLabelColor: LuminaColors.labelSecondary,
                    indicatorWeight: 2,
                    labelStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    tabs: const [
                      Tab(text: 'Songs'),
                      Tab(text: 'Artists'),
                      Tab(text: 'Albums'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
        body: _isLoading
            ? Center(
                child: CupertinoActivityIndicator(
                  color: LuminaColors.accent,
                  radius: 14,
                ),
              )
            : TabBarView(
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
    );
  }

  String _formatDuration(Duration? d) {
    if (d == null) return '';
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return d.inHours > 0 ? '${d.inHours}:$m:$s' : '$m:$s';
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
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              width: 50,
              height: 50,
              child: song.coverArt != null
                  ? Image.memory(song.coverArt!, fit: BoxFit.cover)
                  : Container(
                      color: isDark
                          ? LuminaColors.bg2
                          : LuminaColors.lightBg2,
                      child: const Icon(
                        CupertinoIcons.music_note,
                        color: LuminaColors.labelSecondary,
                        size: 20,
                      ),
                    ),
            ),
          ),
          title: Text(
            song.title,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
              color: isPlaying
                  ? LuminaColors.accent
                  : (isDark ? Colors.white : Colors.black87),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            '${song.artist} · ${song.album}',
            style: const TextStyle(
                color: LuminaColors.labelSecondary, fontSize: 13),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (song.formatBadge.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: LuminaColors.accent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    song.format.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: LuminaColors.accent,
                    ),
                  ),
                ),
              if (song.duration != null)
                Text(
                  _formatDuration(song.duration),
                  style: const TextStyle(
                    fontSize: 12,
                    color: LuminaColors.labelSecondary,
                  ),
                ),
            ],
          ),
          onTap: () {
            PlayerService().playQueue(_displayedSongs, initialIndex: index);
          },
        );
      },
    );
  }

  Widget _buildGroupedList({
    required String Function(AudioFile) groupBy,
    required IconData icon,
  }) {
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
              const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          leading: ClipOval(
            child: SizedBox(
              width: 50,
              height: 50,
              child: cover != null
                  ? Image.memory(cover, fit: BoxFit.cover)
                  : Container(
                      color: isDark
                          ? LuminaColors.bg2
                          : LuminaColors.lightBg2,
                      child: Icon(icon,
                          color: LuminaColors.labelSecondary, size: 22),
                    ),
            ),
          ),
          title: Text(
            groupName,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          subtitle: Text(
            '${groupSongs.length} ${groupSongs.length == 1 ? 'song' : 'songs'}',
            style: const TextStyle(
                color: LuminaColors.labelSecondary, fontSize: 13),
          ),
          trailing:
              const Icon(CupertinoIcons.chevron_right, color: LuminaColors.labelSecondary, size: 16),
          onTap: () {
            Navigator.push(
              context,
              CupertinoPageRoute(
                builder: (_) => DetailScreen(
                  title: groupName,
                  songs: groupSongs,
                  coverArt: cover,
                ),
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

    return Column(
      children: [
        // Grid/List toggle
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              GestureDetector(
                onTap: () => setState(() => _albumsGrid = !_albumsGrid),
                child: Icon(
                  _albumsGrid
                      ? CupertinoIcons.list_bullet
                      : CupertinoIcons.square_grid_2x2_fill,
                  color: LuminaColors.accent,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _albumsGrid
              ? GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.82,
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
                              coverArt: cover,
                            ),
                          ),
                        );
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: SizedBox(
                                width: double.infinity,
                                child: cover != null
                                    ? Image.memory(cover,
                                        fit: BoxFit.cover)
                                    : Container(
                                        color: isDark
                                            ? LuminaColors.bg2
                                            : LuminaColors.lightBg2,
                                        child: const Icon(
                                          CupertinoIcons.music_albums_fill,
                                          color: LuminaColors.labelSecondary,
                                          size: 40,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            albumName,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            albumSongs.first.artist,
                            style: const TextStyle(
                              fontSize: 12,
                              color: LuminaColors.labelSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    );
                  },
                )
              : ListView.separated(
                  padding: EdgeInsets.zero,
                  itemCount: keys.length,
                  separatorBuilder: (_, __) => Divider(
                    color: isDark ? LuminaColors.bg3 : LuminaColors.lightBg3,
                    indent: 76,
                    height: 1,
                  ),
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
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: SizedBox(
                          width: 50,
                          height: 50,
                          child: cover != null
                              ? Image.memory(cover, fit: BoxFit.cover)
                              : Container(
                                  color: isDark
                                      ? LuminaColors.bg2
                                      : LuminaColors.lightBg2,
                                  child: const Icon(
                                    CupertinoIcons.music_albums_fill,
                                    color: LuminaColors.labelSecondary,
                                    size: 22,
                                  ),
                                ),
                        ),
                      ),
                      title: Text(albumName,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: isDark ? Colors.white : Colors.black87,
                          )),
                      subtitle: Text(
                        '${albumSongs.first.artist} · ${albumSongs.length} songs',
                        style: const TextStyle(
                            color: LuminaColors.labelSecondary, fontSize: 13),
                      ),
                      trailing: const Icon(CupertinoIcons.chevron_right,
                          color: LuminaColors.labelSecondary, size: 16),
                      onTap: () {
                        Navigator.push(
                          context,
                          CupertinoPageRoute(
                            builder: (_) => DetailScreen(
                              title: albumName,
                              songs: albumSongs,
                              coverArt: cover,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(CupertinoIcons.music_note_2,
              size: 64, color: LuminaColors.labelTertiary),
          const SizedBox(height: 16),
          const Text(
            'No Music Found',
            style: TextStyle(
              color: LuminaColors.labelSecondary,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add FLAC · WAV · MP3 files to your\nDocuments folder via the Files app.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: LuminaColors.labelTertiary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
