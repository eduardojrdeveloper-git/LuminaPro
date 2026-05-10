import 'package:flutter/material.dart';
import '../services/library_service.dart';

class LibraryScreen extends StatefulWidget {
  @override
  _LibraryScreenState createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  List<AudioFile> _songs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
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
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 120.0,
            backgroundColor: Colors.black,
            actions: [
              IconButton(icon: Icon(Icons.refresh), onPressed: _refreshLibrary)
            ],
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: EdgeInsets.only(left: 20, bottom: 16),
              title: Text('Library', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 28)),
            ),
          ),
          if (_isLoading)
            SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: Colors.pinkAccent)))
          else if (_songs.isEmpty)
            SliverFillRemaining(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.music_off, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No music found in Documents', style: TextStyle(color: Colors.grey)),
                  Text('Upload FLAC/WAV via 3uTools', style: TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final song = _songs[index];
                  return Column(
                    children: [
                      ListTile(
                        leading: Container(
                          width: 50, height: 50,
                          decoration: BoxDecoration(
                            color: Colors.grey[900],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Icon(Icons.music_note, color: Colors.pinkAccent),
                        ),
                        title: Text(song.title, style: TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text('${song.artist} • ${song.album}', style: TextStyle(color: Colors.grey, fontSize: 13)),
                        onTap: () {
                          // TODO: Implement playback logic with just_audio
                        },
                      ),
                      Divider(color: Colors.grey[900], indent: 70),
                    ],
                  );
                },
                childCount: _songs.length,
              ),
            ),
        ],
      ),
    );
  }
}
