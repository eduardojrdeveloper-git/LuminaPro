import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../services/library_service.dart';
import '../services/player_service.dart';
import '../main.dart' show LuminaColors;
import 'detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  List<AudioFile> _allSongs = [];
  List<AudioFile> _results = [];
  bool _isLoading = true;
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _loadLibrary();
    _searchCtrl.addListener(_onSearch);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadLibrary() async {
    final songs = await LibraryService.scanMusic();
    setState(() {
      _allSongs = songs;
      _isLoading = false;
    });
  }

  void _onSearch() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _results = [];
      } else {
        _results = _allSongs.where((s) {
          return s.title.toLowerCase().contains(q) ||
              s.artist.toLowerCase().contains(q) ||
              s.album.toLowerCase().contains(q);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasQuery = _searchCtrl.text.isNotEmpty;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          CupertinoSliverNavigationBar(
            largeTitle: Text(
              'Search',
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
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: CupertinoSearchTextField(
                controller: _searchCtrl,
                focusNode: _focusNode,
                placeholder: 'Artists, Songs, Albums',
                autofocus: false,
                style: TextStyle(
                    color: isDark ? Colors.white : Colors.black, fontSize: 16),
                backgroundColor: isDark
                    ? LuminaColors.bg2.withOpacity(0.9)
                    : LuminaColors.lightBg2.withOpacity(0.9),
              ),
            ),
          ),
        ],
        body: _isLoading
            ? const Center(child: CupertinoActivityIndicator(radius: 14))
            : hasQuery
                ? _buildResults(isDark)
                : _buildCategories(isDark),
      ),
    );
  }

  Widget _buildResults(bool isDark) {
    if (_results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(CupertinoIcons.search,
                size: 56, color: LuminaColors.labelTertiary),
            const SizedBox(height: 16),
            Text(
              'No results for "${_searchCtrl.text}"',
              style: const TextStyle(
                  color: LuminaColors.labelSecondary,
                  fontSize: 17,
                  fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 100),
      child: ListView.separated(
        padding: EdgeInsets.zero,
        itemCount: _results.length,
        separatorBuilder: (_, __) => Divider(
          color: isDark ? LuminaColors.bg3 : LuminaColors.lightBg3,
          indent: 76,
          height: 1,
        ),
        itemBuilder: (context, index) {
          final song = _results[index];
          final isPlaying =
              PlayerService().currentSong.value?.path == song.path;
          return _SearchResultRow(
            song: song,
            isPlaying: isPlaying,
            isDark: isDark,
            onTap: () => PlayerService().playQueue(_results, initialIndex: index),
          );
        },
      ),
    );
  }

  Widget _buildCategories(bool isDark) {
    // Build unique albums/artists from library
    final artists = <String>{};
    final albums = <String, List<AudioFile>>{};
    for (final s in _allSongs) {
      artists.add(s.artist);
      albums.putIfAbsent(s.album, () => []).add(s);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CategoryHeader('Browse Categories', isDark),
          _CategoryGrid(isDark: isDark),
          if (_allSongs.isNotEmpty) ...[
            _CategoryHeader('Recently Added', isDark),
            _RecentList(
                songs: _allSongs.take(6).toList(), isDark: isDark),
          ],
        ],
      ),
    );
  }
}

class _CategoryHeader extends StatelessWidget {
  final String title;
  final bool isDark;
  const _CategoryHeader(this.title, this.isDark);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: isDark ? Colors.white : Colors.black,
          letterSpacing: -0.4,
        ),
      ),
    );
  }
}

class _CategoryGrid extends StatelessWidget {
  final bool isDark;
  const _CategoryGrid({required this.isDark});

  static const _categories = [
    ('Songs', CupertinoIcons.music_note, Color(0xFFFA233B)),
    ('Albums', CupertinoIcons.music_albums, Color(0xFFFF9500)),
    ('Artists', CupertinoIcons.person_fill, Color(0xFF5856D6)),
    ('Playlists', CupertinoIcons.music_note_list, Color(0xFF32ADE6)),
    ('Downloaded', CupertinoIcons.arrow_down_circle_fill, Color(0xFF34C759)),
    ('Recently Added', CupertinoIcons.clock_fill, Color(0xFFFF2D55)),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.count(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 2.4,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: _categories.map((cat) {
          return _CategoryCard(
            label: cat.$1,
            icon: cat.$2,
            color: cat.$3,
            isDark: isDark,
          );
        }).toList(),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isDark;

  const _CategoryCard(
      {required this.label,
      required this.icon,
      required this.color,
      required this.isDark});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {},
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          color: color.withOpacity(isDark ? 0.22 : 0.14),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                    letterSpacing: -0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
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
    return SizedBox(
      height: 180,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: songs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final song = songs[index];
          return GestureDetector(
            onTap: () => PlayerService().playQueue(songs, initialIndex: index),
            child: SizedBox(
              width: 130,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: song.coverArt != null
                          ? Image.memory(song.coverArt!,
                              fit: BoxFit.cover, width: 130)
                          : Container(
                              color: isDark
                                  ? LuminaColors.bg2
                                  : LuminaColors.lightBg2,
                              child: const Center(
                                child: Icon(CupertinoIcons.music_note,
                                    color: LuminaColors.labelSecondary,
                                    size: 32),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    song.title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    song.artist,
                    style: const TextStyle(
                        fontSize: 12, color: LuminaColors.labelSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SearchResultRow extends StatelessWidget {
  final AudioFile song;
  final bool isPlaying;
  final bool isDark;
  final VoidCallback onTap;

  const _SearchResultRow({
    required this.song,
    required this.isPlaying,
    required this.isDark,
    required this.onTap,
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
                  Text(
                    '${song.artist} · ${song.album}',
                    style: const TextStyle(
                        color: LuminaColors.labelSecondary, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(CupertinoIcons.ellipsis,
                color: LuminaColors.labelSecondary, size: 18),
          ],
        ),
      ),
    );
  }
}
