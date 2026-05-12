import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../services/library_service.dart';
import '../services/player_service.dart';
import '../services/google_drive_service.dart';
import '../main.dart' show LuminaColors, MainNavigation, MainNavigationState, showQualityInLibraryNotifier;
import 'detail_screen.dart';

enum SortMode { title, artist, album }

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});
  
  @override
  LibraryScreenState createState() => LibraryScreenState();
}

class LibraryScreenState extends State<LibraryScreen>
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
    // 6 tabs: Categories, Songs, Artists, Albums, Genres, Loved
    _tabController = TabController(length: 6, vsync: this);
    _tabController.addListener(() => setState(() {}));
    _refreshLibrary();
    _searchCtrl.addListener(_applyFilter);
    
    // Auto-refresh when cloud indexing finishes
    LibraryService.libraryUpdateNotifier.addListener(_refreshLibrary);
  }

  @override
  void dispose() {
    LibraryService.libraryUpdateNotifier.removeListener(_refreshLibrary);
    _tabController.dispose();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _refreshLibrary() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    final songs = await LibraryService.scanMusic();
    if (!mounted) return;
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
    if (!applyToFiltered) {
      _allSongs.sort(comparator);
      _filtered = List.from(_allSongs);
    }
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

  void switchTab(int index) {
    if (index >= 0 && index < _tabController.length) {
      _tabController.index = index; // Listener already calls setState
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
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
            SliverPersistentHeader(
              pinned: true,
              delegate: _SearchHeaderDelegate(
                isDark: isDark,
                searchCtrl: _searchCtrl,
                searchFocus: _searchFocus,
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: CupertinoSlidingSegmentedControl<int>(
                    groupValue: _tabController.index,
                    thumbColor: isDark ? LuminaColors.bg3 : Colors.white,
                    backgroundColor: isDark ? LuminaColors.bg2 : LuminaColors.lightBg2,
                    children: {
                      0: _segLabel('Library', _tabController.index == 0, isDark),
                      1: _segLabel('Songs', _tabController.index == 1, isDark),
                      2: _segLabel('Artists', _tabController.index == 2, isDark),
                      3: _segLabel('Albums', _tabController.index == 3, isDark),
                      4: _segLabel('Genres', _tabController.index == 4, isDark),
                      5: _segLabel('Loved', _tabController.index == 5, isDark),
                    },
                    onValueChanged: (v) {
                      if (v != null) setState(() => _tabController.index = v);
                    },
                  ),
                ),
              ),
            ),
          ],
          body: _isLoading
              ? const Center(child: CupertinoActivityIndicator(radius: 14))
              : NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    if (notification is ScrollStartNotification) _searchFocus.unfocus();
                    return false;
                  },
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildCategories(isDark),
                      _buildSongsList(filterLoved: false),
                      _buildGroupedList(groupBy: (s) => s.albumArtist, icon: CupertinoIcons.person_fill),
                      _buildAlbumsView(),
                      _buildGroupedList(groupBy: (s) => s.genre, icon: CupertinoIcons.music_mic),
                      _buildSongsList(filterLoved: true),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _segLabel(String text, bool isActive, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
          color: isActive ? (isDark ? Colors.white : Colors.black) : LuminaColors.labelSecondary,
        ),
      ),
    );
  }

  Widget _buildCategories(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 130),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_allSongs.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.fromLTRB(0, 12, 0, 12),
              child: Text('Recently Added',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.4)),
            ),
            _RecentList(songs: _allSongs.take(6).toList(), isDark: isDark),
            const SizedBox(height: 12),
          ],
          const Text('Library',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4)),
          const SizedBox(height: 8),
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 2.4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _CategoryCard(
                  label: 'Songs',
                  icon: CupertinoIcons.music_note,
                  gradient: [const Color(0xFFFA233B), const Color(0xFFFF5263)],
                  onTap: () => switchTab(1)),
              _CategoryCard(
                  label: 'Albums',
                  icon: CupertinoIcons.music_albums,
                  gradient: [const Color(0xFFFF9500), const Color(0xFFFFCC00)],
                  onTap: () => switchTab(3)),
              _CategoryCard(
                  label: 'Artists',
                  icon: CupertinoIcons.person_fill,
                  gradient: [const Color(0xFF5856D6), const Color(0xFF8989EB)],
                  onTap: () => switchTab(2)),
              _CategoryCard(
                  label: 'Genres',
                  icon: CupertinoIcons.music_mic,
                  gradient: [const Color(0xFF4CD964), const Color(0xFF5AC8FA)],
                  onTap: () => switchTab(4)),
            ],
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(0, 16, 0, 8),
            child: Text('All Songs',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4)),
          ),
          _buildInlineSongsList(),
        ],
      ),
    );
  }

  Widget _buildInlineSongsList() {
    final ps = PlayerService();
    final songs = _allSongs;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: songs.length,
      itemBuilder: (context, index) {
        final song = songs[index];
        return ValueListenableBuilder<AudioFile?>(
          valueListenable: ps.currentSong,
          builder: (ctx, currentSong, _) {
            final isPlaying = currentSong?.path == song.path;
            return Column(
              children: [
                _SongRow(
                  song: song,
                  isPlaying: isPlaying,
                  isDark: isDark,
                  onTap: () => ps.playQueue(songs, initialIndex: index),
                  onMore: () => _showSongMenu(context, song, index, songs),
                ),
                if (index < songs.length - 1)
                  Divider(
                      color: isDark ? LuminaColors.bg3 : LuminaColors.lightBg3,
                      indent: 76,
                      height: 1),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildSongsList({required bool filterLoved}) {
    final ps = PlayerService();
    return ValueListenableBuilder<Set<String>>(
      valueListenable: ps.favoritesNotifier,
      builder: (context, favs, _) {
        final rawSongs = _displayedSongs;
        final songs = filterLoved 
            ? rawSongs.where((s) => favs.contains(s.path)).toList() 
            : rawSongs;

        if (songs.isEmpty) return _buildEmptyState(isLoved: filterLoved);
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 130),
          itemCount: songs.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) return _ShuffleHeroButton(songs: songs);
            final song = songs[index - 1];
            return ValueListenableBuilder<AudioFile?>(
              valueListenable: ps.currentSong,
              builder: (ctx, currentSong, _) {
                final isPlaying = currentSong?.path == song.path;
                return Column(
                  children: [
                    _SongRow(
                      song: song,
                      isPlaying: isPlaying,
                      isDark: isDark,
                      onTap: () => ps.playQueue(songs, initialIndex: index - 1),
                      onMore: () => _showSongMenu(context, song, index - 1, songs),
                    ),
                    if (index < songs.length)
                      Divider(color: isDark ? LuminaColors.bg3 : LuminaColors.lightBg3, indent: 76, height: 1),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  void _showSongMenu(BuildContext context, AudioFile song, int index, List<AudioFile> currentList) {
    final ps = PlayerService();
    showCupertinoModalPopup(
      context: context,
      builder: (_) => CupertinoActionSheet(
        title: Text(song.title, style: const TextStyle(fontWeight: FontWeight.w600)),
        message: Text(song.albumArtist),
        actions: [
          CupertinoActionSheetAction(onPressed: () { Navigator.pop(context); ps.playQueue(currentList, initialIndex: index); }, child: Text(song.isLocal ? 'Play Now' : 'Stream Now')),
          if (!song.isLocal && song.driveFileId != null)
            CupertinoActionSheetAction(
              onPressed: () async {
                Navigator.pop(context);
                final ext = song.format.isNotEmpty ? song.format.toLowerCase() : 'flac';
                final fileName = '${song.title}.$ext';
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Downloading ${song.title}...')));
                final path = await GoogleDriveService().promoteFromCache(song.driveFileId!, fileName);
                if (path != null) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Downloaded: $fileName to local storage.')));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Download failed.')));
                }
              },
              child: const Text('Download'),
            ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              ps.toggleFavorite(song);
            },
            child: ValueListenableBuilder<Set<String>>(
              valueListenable: ps.favoritesNotifier,
              builder: (_, favs, __) => Text(favs.contains(song.path) ? 'Unlove' : 'Love'),
            ),
          ),
          CupertinoActionSheetAction(onPressed: () => Navigator.pop(context), child: const Text('Add to Playlist')),
          CupertinoActionSheetAction(isDestructiveAction: true, onPressed: () => Navigator.pop(context), child: const Text('Delete from Library')),
        ],
        cancelButton: CupertinoActionSheetAction(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      ),
    );
  }

  Widget _buildGroupedList({required String Function(AudioFile) groupBy, required IconData icon}) {
    final songs = _displayedSongs;
    if (songs.isEmpty) return _buildEmptyState();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Map<String, List<AudioFile>> grouped = {};
    for (var song in songs) { final key = groupBy(song); grouped.putIfAbsent(key, () => []).add(song); }
    final keys = grouped.keys.toList()..sort();
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 130),
      itemCount: keys.length,
      separatorBuilder: (_, __) => Divider(color: isDark ? LuminaColors.bg3 : LuminaColors.lightBg3, indent: 76, height: 1),
      itemBuilder: (context, index) {
        final groupName = keys[index];
        final groupSongs = grouped[groupName]!;
        Uint8List? cover;
        for (var s in groupSongs) { if (s.coverArt != null) { cover = s.coverArt; break; } }
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          leading: ClipOval(child: SizedBox(width: 48, height: 48, child: cover != null ? Image.memory(cover, fit: BoxFit.cover) : Container(color: isDark ? LuminaColors.bg2 : LuminaColors.lightBg2, child: Icon(icon, color: LuminaColors.labelSecondary, size: 22)))),
          title: Text(groupName, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: isDark ? Colors.white : Colors.black87, letterSpacing: -0.2)),
          subtitle: Text('${groupSongs.length} songs', style: const TextStyle(color: LuminaColors.labelSecondary, fontSize: 13)),
          trailing: const Icon(CupertinoIcons.chevron_right, color: LuminaColors.labelTertiary, size: 14),
          onTap: () { Navigator.push(context, CupertinoPageRoute(builder: (_) => DetailScreen(title: groupName, songs: groupSongs, coverArt: cover))); },
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 130),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 16, mainAxisSpacing: 20, childAspectRatio: 0.78),
      itemCount: keys.length,
      itemBuilder: (context, index) {
        final albumName = keys[index];
        final albumSongs = grouped[albumName]!;
        Uint8List? cover;
        for (var s in albumSongs) { if (s.coverArt != null) { cover = s.coverArt; break; } }
        return GestureDetector(
          onTap: () { Navigator.push(context, CupertinoPageRoute(builder: (_) => DetailScreen(title: albumName, songs: albumSongs, coverArt: cover))); },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.4 : 0.18), blurRadius: 16, offset: const Offset(0, 6))]), child: ClipRRect(borderRadius: BorderRadius.circular(10), child: cover != null ? Image.memory(cover, fit: BoxFit.cover, width: double.infinity) : Container(color: isDark ? LuminaColors.bg2 : LuminaColors.lightBg2, child: const Center(child: Icon(CupertinoIcons.music_albums, color: LuminaColors.labelSecondary, size: 40)))))),
              const SizedBox(height: 8),
              Text(albumName, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87, letterSpacing: -0.2), maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(albumSongs.first.albumArtist, style: const TextStyle(fontSize: 12, color: LuminaColors.labelSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState({bool isLoved = false}) {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(isLoved ? CupertinoIcons.heart_fill : CupertinoIcons.music_note_list, size: 64, color: LuminaColors.labelTertiary), const SizedBox(height: 16), Text(isLoved ? 'No Loved Songs' : 'No Music Found', style: const TextStyle(color: LuminaColors.labelSecondary, fontSize: 17, fontWeight: FontWeight.w600)), const SizedBox(height: 8), Text(isLoved ? 'Songs you mark with a heart will appear here.' : 'Transfer songs via the Files app.', textAlign: TextAlign.center, style: const TextStyle(color: LuminaColors.labelTertiary, fontSize: 14))]));
  }
}

class _SearchHeaderDelegate extends SliverPersistentHeaderDelegate {
  final bool isDark;
  final TextEditingController searchCtrl;
  final FocusNode searchFocus;

  _SearchHeaderDelegate({
    required this.isDark,
    required this.searchCtrl,
    required this.searchFocus,
  });

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.95),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: CupertinoSearchTextField(
          controller: searchCtrl,
          focusNode: searchFocus,
          placeholder: 'Artists, Songs, Lyrics, and More',
          style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 16),
          backgroundColor: isDark
              ? LuminaColors.bg2.withOpacity(0.9)
              : LuminaColors.lightBg2.withOpacity(0.9),
        ),
      ),
    );
  }

  @override
  double get maxExtent => 64;
  @override
  double get minExtent => 64;
  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) => true;
}

class _CategoryCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final List<Color> gradient;
  final VoidCallback onTap;
  const _CategoryCard({required this.label, required this.icon, required this.gradient, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(gradient: LinearGradient(colors: gradient, begin: Alignment.topLeft, end: Alignment.bottomRight)),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [Icon(icon, color: Colors.white, size: 24), const SizedBox(width: 12), Expanded(child: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: -0.3), maxLines: 1, overflow: TextOverflow.ellipsis))]),
        ),
      ),
    );
  }
}

class _RecentList extends StatelessWidget {
  final List<AudioFile> songs;
  final bool isDark;
  const _RecentList({required this.songs, required this.isDark});
  @override
  Widget build(BuildContext context) {
    return SizedBox(height: 180, child: ListView.separated(padding: EdgeInsets.zero, scrollDirection: Axis.horizontal, itemCount: songs.length, separatorBuilder: (_, __) => const SizedBox(width: 14), itemBuilder: (context, index) { final song = songs[index]; return GestureDetector(onTap: () => PlayerService().playQueue(songs, initialIndex: index), child: SizedBox(width: 130, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.4 : 0.15), blurRadius: 12, offset: const Offset(0, 4))]), child: ClipRRect(borderRadius: BorderRadius.circular(10), child: song.coverArt != null ? Image.memory(song.coverArt!, fit: BoxFit.cover, width: 130) : Container(color: isDark ? LuminaColors.bg2 : LuminaColors.lightBg2, child: const Center(child: Icon(CupertinoIcons.music_note, color: LuminaColors.labelSecondary, size: 32)))))), const SizedBox(height: 6), Text(song.title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis), Text(song.albumArtist, style: const TextStyle(fontSize: 12, color: LuminaColors.labelSecondary), maxLines: 1, overflow: TextOverflow.ellipsis)]))); }));
  }
}

class _ShuffleHeroButton extends StatelessWidget {
  final List<AudioFile> songs;
  const _ShuffleHeroButton({required this.songs});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(padding: const EdgeInsets.fromLTRB(20, 12, 20, 8), child: Row(children: [Expanded(child: _ActionButton(icon: CupertinoIcons.play_fill, label: 'Play', filled: true, isDark: isDark, onTap: () => PlayerService().playQueue(songs, initialIndex: 0))), const SizedBox(width: 12), Expanded(child: _ActionButton(icon: CupertinoIcons.shuffle, label: 'Shuffle', filled: false, isDark: isDark, onTap: () { final ps = PlayerService(); ps.playQueue(songs, initialIndex: 0); if (!ps.shuffle) ps.toggleShuffle(); } ))]));
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool filled;
  final bool isDark;
  final VoidCallback onTap;
  const _ActionButton({required this.icon, required this.label, required this.filled, required this.isDark, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(onTap: onTap, child: Container(height: 44, decoration: BoxDecoration(color: filled ? LuminaColors.accent : (isDark ? LuminaColors.bg2 : LuminaColors.lightBg2), borderRadius: BorderRadius.circular(12)), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, size: 15, color: filled ? Colors.white : (isDark ? Colors.white : Colors.black87)), const SizedBox(width: 6), Text(label, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: filled ? Colors.white : (isDark ? Colors.white : Colors.black87), letterSpacing: -0.3))])));
  }
}

class _SongRow extends StatelessWidget {
  final AudioFile song;
  final bool isPlaying;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback onMore;
  const _SongRow({required this.song, required this.isPlaying, required this.isDark, required this.onTap, required this.onMore});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
        onTap: onTap,
        onLongPress: !song.isLocal && song.driveFileId != null ? () => _triggerDownload(context) : null,
        behavior: HitTestBehavior.opaque,
        child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(children: [
              ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(
                      width: 48,
                      height: 48,
                      child: song.coverArt != null
                          ? Image.memory(song.coverArt!, fit: BoxFit.cover)
                          : Container(
                              color: isDark ? LuminaColors.bg2 : LuminaColors.lightBg2,
                              child: const Icon(CupertinoIcons.music_note,
                                  color: LuminaColors.labelSecondary, size: 20)))),
              const SizedBox(width: 14),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(song.title,
                              style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 16,
                                  color: isPlaying
                                      ? LuminaColors.accent
                                      : (isDark ? Colors.white : Colors.black87),
                                  letterSpacing: -0.2),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                        // Buffering indicator for cloud songs
                        if (!song.isLocal)
                          ValueListenableBuilder<bool>(
                            valueListenable: PlayerService().bufferingNotifier,
                            builder: (_, buffering, __) {
                              if (buffering && isPlaying) {
                                return const Padding(
                                  padding: EdgeInsets.only(left: 6),
                                  child: CupertinoActivityIndicator(radius: 7),
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        ValueListenableBuilder<bool>(
                          valueListenable: showQualityInLibraryNotifier,
                          builder: (ctx, show, _) {
                            return Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: song.isLocal ? (isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7)) : const Color(0xFF34A853).withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    song.isLocal ? 'Local' : 'GDrive',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: song.isLocal ? LuminaColors.labelSecondary : const Color(0xFF34A853),
                                    ),
                                  ),
                                ),
                                if (show && song.formatBadge.isNotEmpty) ...[
                                  const SizedBox(width: 4),
                                  Text(
                                    song.formatBadge,
                                    style: const TextStyle(fontSize: 10, color: LuminaColors.labelTertiary, fontWeight: FontWeight.w400),
                                  ),
                                ],
                              ],
                            );
                          },
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(song.albumArtist,
                              style: const TextStyle(
                                  color: LuminaColors.labelSecondary, fontSize: 14),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    )
                  ])),
              GestureDetector(
                  onTap: onMore,
                  behavior: HitTestBehavior.opaque,
                  child: const Padding(
                      padding: EdgeInsets.only(left: 12),
                      child: Icon(CupertinoIcons.ellipsis,
                          color: LuminaColors.labelSecondary, size: 20)))
            ])));
  }

  void _triggerDownload(BuildContext context) async {
    if (song.driveFileId == null) return;
    final ext = song.format.isNotEmpty ? song.format.toLowerCase() : 'flac';
    final fileName = '${song.title}.$ext';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Downloading: ${song.title}...')));
    final path = await GoogleDriveService().promoteFromCache(song.driveFileId!, fileName);
    if (path != null) {
      LibraryService.removeDriveSong(song.driveFileId!);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Downloaded: ${song.title} to local.')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Download failed.')));
    }
  }
}
