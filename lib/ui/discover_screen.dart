import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../services/spotiflac_service.dart';
import '../main.dart' show LuminaColors;

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  final _searchCtrl = TextEditingController();
  final _service = SpotiflacService();
  List<SpotiflacTrack> _results = [];
  bool _isSearching = false;
  final Map<String, double> _downloadProgress = {};

  Future<void> _onSearch() async {
    final q = _searchCtrl.text.trim();
    if (q.isEmpty) return;
    
    setState(() => _isSearching = true);
    final results = await _service.search(q);
    setState(() {
      _results = results;
      _isSearching = false;
    });
  }

  Future<void> _download(SpotiflacTrack track) async {
    setState(() => _downloadProgress[track.id] = 0.0);
    
    final success = await _service.downloadAndSave(
      track,
      onProgress: (p) => setState(() => _downloadProgress[track.id] = p),
    );

    setState(() => _downloadProgress.remove(track.id));

    if (success) {
      _showToast('Downloaded: ${track.title}');
    } else {
      _showToast('Failed to download: ${track.title}');
    }
  }

  void _showToast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return CupertinoPageScaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Discover'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.85),
        border: null,
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: CupertinoSearchTextField(
                controller: _searchCtrl,
                placeholder: 'Search Spotify or paste URL...',
                onSubmitted: (_) => _onSearch(),
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
              ),
            ),
            Expanded(
              child: _isSearching
                  ? const Center(child: CupertinoActivityIndicator())
                  : _results.isEmpty
                      ? _buildEmptyState()
                      : _buildResultsList(isDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(CupertinoIcons.globe, size: 64, color: LuminaColors.labelTertiary),
          const SizedBox(height: 16),
          const Text(
            'Search Global Music',
            style: TextStyle(color: LuminaColors.labelSecondary, fontSize: 17, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text(
            'Fetch FLACs directly from Spotify metadata.',
            textAlign: TextAlign.center,
            style: TextStyle(color: LuminaColors.labelTertiary, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsList(bool isDark) {
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 120),
      itemCount: _results.length,
      separatorBuilder: (_, __) => Divider(color: isDark ? LuminaColors.bg3 : LuminaColors.lightBg3, indent: 76, height: 1),
      itemBuilder: (context, index) {
        final track = _results[index];
        final progress = _downloadProgress[track.id];
        final isDownloading = progress != null;

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isDownloading ? null : () => _download(track),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                      width: 54,
                      height: 54,
                      child: track.coverUrl != null
                          ? Image.network(track.coverUrl!, fit: BoxFit.cover)
                          : Container(color: LuminaColors.bg3, child: const Icon(CupertinoIcons.music_note)),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          track.title,
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${track.artist} • ${track.album}',
                          style: const TextStyle(fontSize: 13, color: LuminaColors.labelSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (isDownloading)
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        value: progress > 0 ? progress : null,
                        strokeWidth: 3,
                        color: LuminaColors.accent,
                        backgroundColor: LuminaColors.bg3,
                      ),
                    )
                  else
                    const Icon(CupertinoIcons.cloud_download, color: LuminaColors.accent, size: 24),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
