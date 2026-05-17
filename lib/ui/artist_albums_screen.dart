import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../services/library_service.dart';
import '../main.dart' show LuminaColors;
import 'detail_screen.dart';

class ArtistAlbumsScreen extends StatelessWidget {
  final String artistName;
  final List<AudioFile> allArtistSongs;

  const ArtistAlbumsScreen({
    super.key,
    required this.artistName,
    required this.allArtistSongs,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Group songs by album
    final Map<String, List<AudioFile>> grouped = {};
    for (var song in allArtistSongs) {
      grouped.putIfAbsent(song.album, () => []).add(song);
    }
    final keys = grouped.keys.toList()..sort();

    return CupertinoPageScaffold(
      backgroundColor: isDark ? LuminaColors.bg0 : LuminaColors.lightBg0,
      navigationBar: CupertinoNavigationBar(
        middle: Text(artistName, style: const TextStyle(fontWeight: FontWeight.w700)),
        previousPageTitle: 'Library',
        backgroundColor: (isDark ? LuminaColors.bg0 : LuminaColors.lightBg0).withOpacity(0.85),
      ),
      child: SafeArea(
        child: GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 130),
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
                      coverArt: cover,
                    ),
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
                          )
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: cover != null
                            ? Image.memory(cover, fit: BoxFit.cover, width: double.infinity)
                            : Container(
                                color: isDark ? LuminaColors.bg2 : LuminaColors.lightBg2,
                                child: const Center(
                                  child: Icon(
                                    CupertinoIcons.music_albums,
                                    color: LuminaColors.labelSecondary,
                                    size: 40,
                                  ),
                                ),
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
                    '${albumSongs.length} songs',
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
        ),
      ),
    );
  }
}
