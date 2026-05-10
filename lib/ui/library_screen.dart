import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/library_service.dart';
import '../services/player_service.dart';

class LibraryScreen extends StatefulWidget {
  @override
  _LibraryScreenState createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> with SingleTickerProviderStateMixin {
  List<AudioFile> _songs = [];
  bool _isLoading = true;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _refreshLibrary();
  }

  Future<void> _refreshLibrary() async {
    setState(() => _isLoading = true);
    final songs = await LibraryService.scanMusic();
    setState(() {
      _songs = songs;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Text('Library', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 28)),
        actions: [
          IconButton(icon: Icon(Icons.refresh, color: Colors.pinkAccent), onPressed: _refreshLibrary)
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.pinkAccent,
          labelColor: Colors.pinkAccent,
          unselectedLabelColor: Colors.grey,
          tabs: [
            Tab(text: 'Songs'),
            Tab(text: 'Artists'),
            Tab(text: 'Albums'),
          ],
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: Colors.pinkAccent))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildSongsList(),
                _buildGroupedList(groupBy: (s) => s.artist, icon: Icons.mic_external_on),
                _buildGroupedList(groupBy: (s) => s.album, icon: Icons.album),
              ],
            ),
    );
  }

  Widget _buildSongsList() {
    if (_songs.isEmpty) return _buildEmptyState();

    return ListView.separated(
      itemCount: _songs.length,
      separatorBuilder: (_, __) => Divider(color: Colors.grey[900], indent: 70),
      itemBuilder: (context, index) {
        final song = _songs[index];
        return ListTile(
          leading: Container(
            width: 50, height: 50,
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(4),
              image: song.coverArt != null
                  ? DecorationImage(image: MemoryImage(song.coverArt!), fit: BoxFit.cover)
                  : null,
            ),
            child: song.coverArt == null ? Icon(Icons.music_note, color: Colors.grey) : null,
          ),
          title: Text(song.title, style: TextStyle(fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text('${song.artist} • ${song.album}', style: TextStyle(color: Colors.grey, fontSize: 13), maxLines: 1),
          onTap: () {
            PlayerService().playSong(song);
          },
        );
      },
    );
  }

  Widget _buildGroupedList({required String Function(AudioFile) groupBy, required IconData icon}) {
    if (_songs.isEmpty) return _buildEmptyState();

    // Group songs
    Map<String, List<AudioFile>> grouped = {};
    for (var song in _songs) {
      String key = groupBy(song);
      if (!grouped.containsKey(key)) grouped[key] = [];
      grouped[key]!.add(song);
    }

    final keys = grouped.keys.toList()..sort();

    return ListView.separated(
      itemCount: keys.length,
      separatorBuilder: (_, __) => Divider(color: Colors.grey[900], indent: 70),
      itemBuilder: (context, index) {
        String groupName = keys[index];
        List<AudioFile> groupSongs = grouped[groupName]!;
        // Try to find a cover art from the group
        Uint8List? groupCover;
        for(var s in groupSongs) {
          if(s.coverArt != null) {
            groupCover = s.coverArt;
            break;
          }
        }

        return ListTile(
          leading: Container(
            width: 50, height: 50,
            decoration: BoxDecoration(
              color: Colors.grey[900],
              shape: BoxShape.circle,
              image: groupCover != null
                  ? DecorationImage(image: MemoryImage(groupCover), fit: BoxFit.cover)
                  : null,
            ),
            child: groupCover == null ? Icon(icon, color: Colors.grey) : null,
          ),
          title: Text(groupName, style: TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text('${groupSongs.length} songs', style: TextStyle(color: Colors.grey)),
          onTap: () {
             // Future: Navigate to album/artist detail screen
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.music_off, size: 64, color: Colors.grey[800]),
        SizedBox(height: 16),
        Text('No music found', style: TextStyle(color: Colors.grey)),
        Text('Put FLAC/WAV folders in Documents via PC', style: TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }
}
