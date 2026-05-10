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

  @override
  Widget build(BuildContext context) {
    final playerService = PlayerService();

    return ValueListenableBuilder<AudioFile?>(
      valueListenable: playerService.currentSong,
      builder: (context, song, child) {
        if (song == null) {
          return Center(child: Text("Not Playing", style: TextStyle(color: Colors.grey)));
        }

        return Container(
          padding: EdgeInsets.symmetric(horizontal: 30),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.grey[900]!, Colors.black],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Spacer(),
              AspectRatio(
                aspectRatio: 1,
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(color: Colors.black54, blurRadius: 20, offset: Offset(0, 10))
                    ],
                    image: song.coverArt != null
                        ? DecorationImage(image: MemoryImage(song.coverArt!), fit: BoxFit.cover)
                        : null,
                    color: song.coverArt == null ? Colors.grey[850] : null,
                  ),
                  child: song.coverArt == null ? Icon(Icons.music_note, size: 100, color: Colors.grey) : null,
                ),
              ),
              SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(song.title, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text(song.artist, style: TextStyle(fontSize: 20, color: Colors.pinkAccent), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  Icon(Icons.more_horiz, color: Colors.white),
                ],
              ),
              SizedBox(height: 30),
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
                          Slider(
                            value: val,
                            min: 0,
                            max: max > 0 ? max : 1,
                            onChanged: (v) {
                              playerService.seek(Duration(milliseconds: v.toInt()));
                            },
                            activeColor: Colors.white,
                            inactiveColor: Colors.white24,
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(_formatDuration(position), style: TextStyle(color: Colors.white54, fontSize: 12)),
                              Text('-${_formatDuration(duration - position)}', style: TextStyle(color: Colors.white54, fontSize: 12)),
                            ],
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
              SizedBox(height: 30),
              // Controls
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    iconSize: 48,
                    icon: Icon(Icons.skip_previous, color: Colors.white),
                    onPressed: playerService.skipToPrevious,
                  ),
                  StreamBuilder<bool>(
                    stream: playerService.playingStream,
                    builder: (context, snapshot) {
                      final isPlaying = snapshot.data ?? false;
                      return IconButton(
                        iconSize: 72,
                        icon: Icon(isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill),
                        color: Colors.white,
                        onPressed: playerService.playPause,
                      );
                    },
                  ),
                  IconButton(
                    iconSize: 48,
                    icon: Icon(Icons.skip_next, color: Colors.white),
                    onPressed: playerService.skipToNext,
                  ),
                ],
              ),
              Spacer(),
              SizedBox(height: 40),
            ],
          ),
        );
      },
    );
  }
}
