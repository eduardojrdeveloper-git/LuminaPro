import 'package:flutter/material.dart';

class LibraryScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 120.0,
          backgroundColor: Colors.black,
          flexibleSpace: FlexibleSpaceBar(
            titlePadding: EdgeInsets.only(left: 20, bottom: 16),
            title: Text('Library', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 28)),
          ),
        ),
        SliverList(
          delegate: SliverChildListDelegate([
            _buildLibraryItem(Icons.music_note, 'Playlists'),
            _buildLibraryItem(Icons.mic_external_on, 'Artists'),
            _buildLibraryItem(Icons.album, 'Albums'),
            _buildLibraryItem(Icons.file_download, 'Downloaded'),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Text('Recently Added', style: Theme.of(context).textTheme.titleLarge),
            ),
            _buildRecentlyAddedGrid(),
          ]),
        ),
      ],
    );
  }

  Widget _buildLibraryItem(IconData icon, String title) {
    return Column(
      children: [
        ListTile(
          leading: Icon(icon, color: Colors.pinkAccent),
          title: Text(title, style: TextStyle(fontSize: 20)),
          trailing: Icon(Icons.chevron_right, color: Colors.grey),
          onTap: () {},
        ),
        Divider(color: Colors.grey[900], indent: 60),
      ],
    );
  }

  Widget _buildRecentlyAddedGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      padding: EdgeInsets.symmetric(horizontal: 20),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 20,
        crossAxisSpacing: 20,
        childAspectRatio: 0.8,
      ),
      itemCount: 4,
      itemBuilder: (context, index) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(8),
                  image: DecorationImage(
                    image: NetworkImage('https://via.placeholder.com/200'),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            SizedBox(height: 8),
            Text('Album Name', style: TextStyle(fontWeight: FontWeight.bold)),
            Text('Artist Name', style: TextStyle(color: Colors.grey)),
          ],
        );
      },
    );
  }
}
