import 'package:flutter/material.dart';
import 'eq_advanced_screen.dart';

class SettingsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 100.0,
            backgroundColor: Colors.black,
            flexibleSpace: FlexibleSpaceBar(
              title: Text('Settings', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          SliverList(
            delegate: SliverChildListDelegate([
              _buildSectionHeader('AUDIO ENGINE'),
              _buildSettingItem(Icons.equalizer, 'Parametric EQ (PEQ)', () {
                Navigator.push(context, MaterialPageRoute(builder: (c) => EqAdvancedScreen()));
              }),
              _buildSectionHeader('INTERFACE'),
              _buildSettingItem(Icons.palette, 'Theme', () {}),
              _buildSectionHeader('ABOUT'),
              _buildSettingItem(Icons.info_outline, 'Lumina Pro v1.0.0', () {}),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, top: 24, bottom: 8),
      child: Text(title, style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildSettingItem(IconData icon, String title, VoidCallback onTap, {Widget? trailing}) {
    return ListTile(
      leading: Icon(icon, color: Colors.white70),
      title: Text(title),
      trailing: trailing ?? Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
    );
  }
}
