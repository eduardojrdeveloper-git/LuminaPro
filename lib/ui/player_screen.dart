import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/player_service.dart';
import '../services/library_service.dart';

class PlayerScreen extends StatelessWidget {
  String _formatDuration(Duration? d) {
    if (d == null) return "0:00";
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(d.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(d.inSeconds.remainder(60));
    return "${d.inHours > 0 ? '${d.inHours}:' : ''}$twoDigitMinutes:$twoDigitSeconds";
  }

  void _showMoreMenu(BuildContext context, AudioFile song) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey, borderRadius: BorderRadius.circular(2))),
              SizedBox(height: 24),
              Row(
                children: [
                  Container(
                    width: 60, height: 60,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      image: song.coverArt != null ? DecorationImage(image: MemoryImage(song.coverArt!), fit: BoxFit.cover) : null,
                      color: Colors.grey[800],
                    ),
                    child: song.coverArt == null ? Icon(Icons.music_note, color: Colors.grey) : null,
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(song.title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18), maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text(song.artist, style: TextStyle(color: Colors.pinkAccent), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  )
                ],
              ),
              SizedBox(height: 24),
              ListTile(
                leading: Icon(Icons.equalizer),
                title: Text('Equalizer (PEQ)'),
                onTap: () {
                  Navigator.pop(context);
                  // Not perfectly architectural, but works for quick access if they implement navigation from here
                  // We'll leave it as a UI placeholder or direct them to settings tab
                },
              ),
              ListTile(
                leading: Icon(Icons.playlist_add),
                title: Text('Add to Playlist'),
                onTap: () => Navigator.pop(context),
              ),
              ListTile(
                leading: Icon(Icons.info_outline),
                title: Text('View Details'),
                onTap: () => Navigator.pop(context),
              ),
              SizedBox(height: 16),
            ],
          ),
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    final playerService = PlayerService();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ValueListenableBuilder<AudioFile?>(
      valueListenable: playerService.currentSong,
      builder: (context, song, child) {
        if (song == null) {
          return Center(child: Text("Not Playing", style: TextStyle(color: Colors.grey)));
        }

        return Stack(
          children: [
            // Blurred Background
            if (song.coverArt != null)
              Positioned.fill(
                child: Image.memory(song.coverArt!, fit: BoxFit.cover),
              ),
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
                child: Container(
                  color: isDark ? Colors.black.withOpacity(0.6) : Colors.white.withOpacity(0.7),
                ),
              ),
            ),
            
            // Content
            SafeArea(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Spacer(),
                    // Album Art
                    Hero(
                      tag: 'album_art',
                      child: Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(16),
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: isDark ? Colors.black87 : Colors.black26, 
                                  blurRadius: 30, 
                                  offset: Offset(0, 15)
                                )
                              ],
                              image: song.coverArt != null
                                  ? DecorationImage(image: MemoryImage(song.coverArt!), fit: BoxFit.cover)
                                  : null,
                              color: song.coverArt == null ? (isDark ? Colors.grey[850] : Colors.grey[300]) : null,
                            ),
                            child: song.coverArt == null ? Icon(Icons.music_note, size: 100, color: Colors.grey) : null,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 32),
                    
                    // Title and Artist
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                song.title, 
                                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87), 
                                maxLines: 1, 
                                overflow: TextOverflow.ellipsis
                              ),
                              SizedBox(height: 4),
                              Text(
                                song.artist, 
                                style: TextStyle(fontSize: 20, color: Colors.pinkAccent), 
                                maxLines: 1, 
                                overflow: TextOverflow.ellipsis
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.more_horiz, color: isDark ? Colors.white : Colors.black87),
                          onPressed: () => _showMoreMenu(context, song),
                        ),
                      ],
                    ),
                    SizedBox(height: 32),
                    
                    // Progress bar
                    StreamBuilder<Duration>(
                      stream: playerService.positionStream,
                      builder: (context, snapshot) {
                        final position = snapshot.data ?? Duration.zero;
                        return StreamBuilder<Duration?>(
                          stream: playerService.durationStream,
                          builder: (context, durationSnapshot) {
                            final duration = durationSnapshot.data ?? Duration.zero;
                            double max = duration.inMilliseconds.toDouble();
                            double val = position.inMilliseconds.toDouble();
                            if (val > max) val = max;

                            return Column(
                              children: [
                                SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    trackHeight: 4.0,
                                    thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6.0),
                                    overlayShape: RoundSliderOverlayShape(overlayRadius: 14.0),
                                  ),
                                  child: Slider(
                                    value: val,
                                    min: 0,
                                    max: max > 0 ? max : 1,
                                    onChanged: (v) {
                                      playerService.seek(Duration(milliseconds: v.toInt()));
                                    },
                                    activeColor: isDark ? Colors.white : Colors.black87,
                                    inactiveColor: isDark ? Colors.white24 : Colors.black12,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(_formatDuration(position), style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 12)),
                                      Text('-${_formatDuration(duration - position)}', style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 12)),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    ),
                    SizedBox(height: 24),
                    
                    // Controls
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        IconButton(
                          iconSize: 48,
                          icon: Icon(Icons.skip_previous, color: isDark ? Colors.white : Colors.black87),
                          onPressed: playerService.skipToPrevious,
                        ),
                        StreamBuilder<bool>(
                          stream: playerService.playingStream,
                          builder: (context, snapshot) {
                            final isPlaying = snapshot.data ?? false;
                            return Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.pinkAccent,
                                boxShadow: [
                                  BoxShadow(color: Colors.pinkAccent.withOpacity(0.4), blurRadius: 20, offset: Offset(0, 10))
                                ]
                              ),
                              child: IconButton(
                                iconSize: 64,
                                icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
                                color: Colors.white,
                                onPressed: playerService.playPause,
                              ),
                            );
                          },
                        ),
                        IconButton(
                          iconSize: 48,
                          icon: Icon(Icons.skip_next, color: isDark ? Colors.white : Colors.black87),
                          onPressed: playerService.skipToNext,
                        ),
                      ],
                    ),
                    Spacer(),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
