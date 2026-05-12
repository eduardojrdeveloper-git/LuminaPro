import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../services/player_service.dart';
import '../services/library_service.dart';
import '../main.dart' show LuminaColors;

class QueueScreen extends StatefulWidget {
  const QueueScreen({super.key});

  @override
  State<QueueScreen> createState() => _QueueScreenState();
}

class _QueueScreenState extends State<QueueScreen> {
  final PlayerService _ps = PlayerService();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return CupertinoPageScaffold(
      backgroundColor: isDark ? LuminaColors.bg0 : LuminaColors.lightBg0,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: (isDark ? LuminaColors.bg0 : LuminaColors.lightBg0).withOpacity(0.8),
        middle: const Text('Playing Next'),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.chevron_down, color: LuminaColors.accent),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      child: SafeArea(
        child: ValueListenableBuilder<List<AudioFile>>(
          valueListenable: _ps.queueNotifier,
          builder: (context, queue, _) {
            if (queue.isEmpty) {
              return Center(
                child: Text(
                  'Queue is empty',
                  style: TextStyle(color: LuminaColors.labelSecondary, fontSize: 16),
                ),
              );
            }

            return Theme(
              data: Theme.of(context).copyWith(
                canvasColor: Colors.transparent, // Prevents white background while dragging
              ),
              child: ReorderableListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 12),
                itemCount: queue.length,
                onReorder: (oldIndex, newIndex) {
                  _ps.reorderQueue(oldIndex, newIndex);
                },
                itemBuilder: (context, index) {
                  final song = queue[index];
                  final isPlaying = _ps.currentSong.value?.path == song.path;
                  
                  return Dismissible(
                    key: Key('${song.path}_$index'),
                    direction: DismissDirection.endToStart,
                    onDismissed: (_) => _ps.removeQueueItem(index),
                    background: Container(
                      color: LuminaColors.destructive,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      child: const Icon(CupertinoIcons.trash, color: Colors.white),
                    ),
                    child: Material(
                      key: ValueKey('${song.path}_$index'),
                      color: Colors.transparent,
                      child: ListTile(
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: SizedBox(
                            width: 44,
                            height: 44,
                            child: song.coverArt != null && song.coverArt!.isNotEmpty
                                ? Image.memory(song.coverArt!, fit: BoxFit.cover)
                                : Container(
                                    color: LuminaColors.bg3,
                                    child: const Icon(CupertinoIcons.music_note, color: LuminaColors.labelSecondary, size: 20),
                                  ),
                          ),
                        ),
                        title: Text(
                          song.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isPlaying ? LuminaColors.accent : (isDark ? Colors.white : Colors.black),
                            fontWeight: isPlaying ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                        subtitle: Text(
                          song.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: LuminaColors.labelSecondary, fontSize: 13),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isPlaying) const Icon(CupertinoIcons.waveform, color: LuminaColors.accent, size: 16),
                            const SizedBox(width: 12),
                            ReorderableDragStartListener(
                              index: index,
                              child: const Icon(CupertinoIcons.bars, color: LuminaColors.labelSecondary, size: 20),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
