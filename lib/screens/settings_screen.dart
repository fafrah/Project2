import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import 'profile_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFF121212),

      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "Settings",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),

      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Account",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 12),

              buildTile(
                icon: Icons.person,
                title: "Profile",
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ProfileScreen()),
                  );
                },
              ),

              buildTile(icon: Icons.lock, title: "Privacy", onTap: () {}),

              const SizedBox(height: 25),

              const Text(
                "Preferences",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 12),

              buildSwitchTile(
                icon: Icons.notifications,
                title: "Notifications",
                value: settings.notifications,
                onChanged: (value) {
                  settings.toggleNotifications(value);
                },
              ),

              buildSwitchTile(
                icon: Icons.dark_mode,
                title: "Dark Mode",
                value: settings.darkMode,
                onChanged: (value) {
                  settings.toggleDarkMode(value);
                },
              ),

              buildSwitchTile(
                icon: Icons.play_circle_fill,
                title: "Auto Play",
                value: settings.autoPlay,
                onChanged: (value) {
                  settings.toggleAutoPlay(value);
                },
              ),

              const SizedBox(height: 25),

              const Text(
                "Support",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 12),

              buildTile(icon: Icons.help, title: "Help Center", onTap: () {}),

              buildTile(icon: Icons.info, title: "About App", onTap: () {}),

              buildTile(
                icon: Icons.logout,
                title: "Logout",
                iconColor: Colors.red,
                textColor: Colors.red,
                onTap: () {},
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color iconColor = Colors.white,
    Color textColor = Colors.white,
  }) {
    return Card(
      color: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        leading: Icon(icon, color: iconColor),
        title: Text(title, style: TextStyle(color: textColor)),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          color: Colors.white54,
          size: 16,
        ),
        onTap: onTap,
      ),
    );
  }

  Widget buildSwitchTile({
    required IconData icon,
    required String title,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return Card(
      color: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: SwitchListTile(
        secondary: Icon(icon, color: Colors.white),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        activeColor: const Color(0xFF1DB954),
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}
