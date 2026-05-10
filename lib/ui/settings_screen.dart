import 'package:flutter/material.dart';
import 'eq_advanced_screen.dart';
import '../main.dart'; // To access themeNotifier

class SettingsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 100.0,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            flexibleSpace: FlexibleSpaceBar(
              title: Text('Settings', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
            ),
          ),
          SliverList(
            delegate: SliverChildListDelegate([
              _buildSectionHeader('AUDIO ENGINE', context),
              _buildSettingItem(context, Icons.equalizer, 'Parametric EQ (PEQ)', () {
                Navigator.push(context, MaterialPageRoute(builder: (c) => EqAdvancedScreen()));
              }),
              _buildSectionHeader('INTERFACE', context),
              ValueListenableBuilder<ThemeMode>(
                valueListenable: themeNotifier,
                builder: (context, mode, _) {
                  String modeName = "System";
                  if (mode == ThemeMode.light) modeName = "Light";
                  if (mode == ThemeMode.dark) modeName = "Dark";
                  
                  return _buildSettingItem(
                    context, 
                    Icons.palette, 
                    'Theme', 
                    () => _showThemePicker(context),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(modeName, style: TextStyle(color: Colors.grey)),
                        Icon(Icons.chevron_right, color: Colors.grey),
                      ],
                    ),
                  );
                }
              ),
              _buildSectionHeader('ABOUT', context),
              _buildSettingItem(context, Icons.info_outline, 'Lumina Pro v1.0.0', () {}),
            ]),
          ),
        ],
      ),
    );
  }

  void _showThemePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text("System Default"),
                leading: Icon(Icons.brightness_auto),
                onTap: () { themeNotifier.value = ThemeMode.system; Navigator.pop(context); },
              ),
              ListTile(
                title: Text("Light Mode"),
                leading: Icon(Icons.light_mode),
                onTap: () { themeNotifier.value = ThemeMode.light; Navigator.pop(context); },
              ),
              ListTile(
                title: Text("Dark Mode"),
                leading: Icon(Icons.dark_mode),
                onTap: () { themeNotifier.value = ThemeMode.dark; Navigator.pop(context); },
              ),
            ],
          ),
        );
      }
    );
  }

  Widget _buildSectionHeader(String title, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, top: 24, bottom: 8),
      child: Text(title, style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildSettingItem(BuildContext context, IconData icon, String title, VoidCallback onTap, {Widget? trailing}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListTile(
      leading: Icon(icon, color: isDark ? Colors.white70 : Colors.black87),
      title: Text(title, style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
      trailing: trailing ?? Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
    );
  }
}

