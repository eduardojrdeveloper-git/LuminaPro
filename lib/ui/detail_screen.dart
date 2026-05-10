import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/library_service.dart';
import '../services/player_service.dart';

class DetailScreen extends StatelessWidget {
  final String title;
  final List<AudioFile> songs;
  final Uint8List? coverArt;

  DetailScreen({required this.title, required this.songs, this.coverArt});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: Colors.black,
            expandedHeight: 250.0,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(title, style: TextStyle(fontWeight: FontWeight.bold)),
              background: coverArt != null
                  ? Image.memory(coverArt!, fit: BoxFit.cover, color: Colors.black45, colorBlendMode: BlendMode.darken)
                  : Container(color: Colors.grey[900], child: Icon(Icons.library_music, size: 80, color: Colors.grey)),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final song = songs[index];
                return ListTile(
                  leading: Text('${index + 1}', style: TextStyle(color: Colors.grey, fontSize: 16)),
                  title: Text(song.title, style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
                  subtitle: Text('${song.artist} • ${song.album}', style: TextStyle(color: Colors.grey, fontSize: 13)),
                  trailing: Icon(Icons.more_horiz, color: Colors.grey),
                  onTap: () {
                    PlayerService().playQueue(songs, initialIndex: index);
                  },
                );
              },
              childCount: songs.length,
            ),
          ),
        ],
      ),
    );
  }
}
