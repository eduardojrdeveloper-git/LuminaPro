import 'package:flutter/material.dart';
import 'ui/library_screen.dart';
import 'ui/player_screen.dart';
import 'ui/settings_screen.dart';
import 'services/player_service.dart';
import 'services/library_service.dart';

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.system);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(LuminaProApp());
}

class LuminaProApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, ThemeMode currentMode, __) {
        return MaterialApp(
          title: 'Lumina Pro',
          debugShowCheckedModeBanner: false,
          themeMode: currentMode,
          theme: ThemeData(
            brightness: Brightness.light,
            scaffoldBackgroundColor: Colors.white,
            primaryColor: Colors.pinkAccent,
            colorScheme: ColorScheme.light(
              primary: Colors.pinkAccent,
              secondary: Colors.pinkAccent,
              surface: Colors.grey[100]!,
            ),
            appBarTheme: AppBarTheme(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              elevation: 0,
            ),
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            scaffoldBackgroundColor: Colors.black,
            primaryColor: Colors.pinkAccent,
            colorScheme: ColorScheme.dark(
              primary: Colors.pinkAccent,
              secondary: Colors.pinkAccent,
              surface: Color(0xFF1C1C1E),
            ),
          ),
          home: MainNavigation(),
        );
      },
    );
  }
}

class MainNavigation extends StatefulWidget {
  @override
  _MainNavigationState createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  final List<Widget> _screens = [
    LibraryScreen(),
    PlayerScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final playerService = PlayerService();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Mini Player
          ValueListenableBuilder<AudioFile?>(
            valueListenable: playerService.currentSong,
            builder: (context, song, _) {
              if (song == null || _currentIndex == 1) return SizedBox.shrink(); // Hide if no song or if on Player tab
              
              return GestureDetector(
                onTap: () => setState(() => _currentIndex = 1),
                child: Container(
                  color: isDark ? Colors.grey[900] : Colors.grey[200],
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          color: Colors.grey,
                          image: song.coverArt != null
                              ? DecorationImage(image: MemoryImage(song.coverArt!), fit: BoxFit.cover)
                              : null,
                        ),
                        child: song.coverArt == null ? Icon(Icons.music_note, color: Colors.white) : null,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.bold)),
                            Text(song.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: Colors.pinkAccent)),
                          ],
                        ),
                      ),
                      StreamBuilder<bool>(
                        stream: playerService.playingStream,
                        builder: (context, snapshot) {
                          final isPlaying = snapshot.data ?? false;
                          return IconButton(
                            icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
                            onPressed: playerService.playPause,
                          );
                        },
                      ),
                      IconButton(
                        icon: Icon(Icons.skip_next),
                        onPressed: playerService.skipToNext,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          BottomNavigationBar(
            currentIndex: _currentIndex,
            backgroundColor: isDark ? Color(0xFF1C1C1E) : Colors.white,
            selectedItemColor: Colors.pinkAccent,
            unselectedItemColor: Colors.grey,
            onTap: (index) => setState(() => _currentIndex = index),
            items: [
              BottomNavigationBarItem(icon: Icon(Icons.library_music), label: 'Library'),
              BottomNavigationBarItem(icon: Icon(Icons.play_circle_fill), label: 'Playing'),
              BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
            ],
          ),
        ],
      ),
    );
  }
}

