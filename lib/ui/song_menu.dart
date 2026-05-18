import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../services/library_service.dart';
import '../services/player_service.dart';
import '../services/google_drive_service.dart';
import '../main.dart' show LuminaColors;

void showSongMenuGlobal(BuildContext context, AudioFile song, int index, List<AudioFile> currentList) {
  final ps = PlayerService();
  showCupertinoModalPopup(
    context: context,
    builder: (_) => CupertinoActionSheet(
      title: Text(song.title, style: const TextStyle(fontWeight: FontWeight.w600)),
      message: Text(song.albumArtist),
      actions: [
        CupertinoActionSheetAction(onPressed: () { Navigator.pop(context); ps.playQueue(currentList, initialIndex: index); }, child: Text(song.isLocal ? 'Play Now' : 'Stream Now')),
        CupertinoActionSheetAction(
          onPressed: () {
            Navigator.pop(context);
            ps.addToQueue(song);
          },
          child: const Text('Add to Queue'),
        ),
        if (!song.isLocal && song.driveFileId != null)
          CupertinoActionSheetAction(
            onPressed: () async {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Downloading ${song.title}...')));
              final path = await GoogleDriveService().promoteFromCache(song);
              if (path != null) {
                LibraryService.removeDriveSong(song.driveFileId!);
                ps.promoteSongToLocal(song.driveFileId!, path);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Downloaded: ${song.title} to local storage.')));
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
