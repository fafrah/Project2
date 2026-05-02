import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/session_provider.dart';
import '../services/session_service.dart';
import '../services/spotify_auth_service.dart';
import '../services/user_service.dart';
import '../theme/app_theme.dart';
import '../widgets/gradient_button.dart';
import 'session_screen.dart';

class CreateSessionScreen extends StatefulWidget {
  const CreateSessionScreen({super.key});

  @override
  State<CreateSessionScreen> createState() => _CreateSessionScreenState();
}

class _CreateSessionScreenState extends State<CreateSessionScreen> {
  final nameController = TextEditingController(text: 'Friday Night Vibes');
  final sessions = SessionService();
  final users = UserService();
  final spotifyAuth = SpotifyAuthService();
  bool loading = false;
  bool connecting = false;

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  Future<void> _connectSpotify() async {
    setState(() => connecting = true);
    try {
      final result = await spotifyAuth.connect();
      if (!mounted) return;
      if (!result.ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Spotify connect failed: ${result.reason}'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not start Spotify auth: $e')),
      );
    }
    if (mounted) setState(() => connecting = false);
  }

  Future<void> _create() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;
    if (nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Give the room a name.')),
      );
      return;
    }
    setState(() => loading = true);
    try {
      final me = await users.getUser(user.uid);
      final session = await sessions.createSession(
        hostUid: user.uid,
        hostUsername: me?.username ?? user.email!.split('@').first,
        name: nameController.text.trim(),
      );
      if (!mounted) return;
      context.read<SessionProvider>().setSession(session.id);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => SessionScreen(sessionId: session.id),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not create room: $e')),
      );
    }
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    return Scaffold(
      appBar: AppBar(title: const Text('Create room')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Name your room',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Pick a vibe — anything goes.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: nameController,
                textCapitalization: TextCapitalization.words,
                maxLength: 40,
                decoration: const InputDecoration(
                  labelText: 'Room name',
                  prefixIcon: Icon(Icons.music_note),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (user != null)
                StreamBuilder<bool>(
                  stream: spotifyAuth.connectedStream(user.uid),
                  builder: (context, snap) {
                    final connected = snap.data ?? false;
                    return _SpotifyConnectCard(
                      connected: connected,
                      busy: connecting,
                      onConnect: _connectSpotify,
                    );
                  },
                ),
              const SizedBox(height: AppSpacing.lg),
              GradientButton(
                label: 'Create room',
                icon: Icons.add,
                loading: loading,
                onPressed: _create,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SpotifyConnectCard extends StatelessWidget {
  final bool connected;
  final bool busy;
  final VoidCallback onConnect;
  const _SpotifyConnectCard({
    required this.connected,
    required this.busy,
    required this.onConnect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: connected ? const Color(0xFF1DB954) : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF1DB954),
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: const Icon(Icons.music_note, color: Colors.white),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  connected ? 'Spotify connected' : 'Connect Spotify',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  connected
                      ? 'Top-voted tracks will play on your Spotify.'
                      : 'Required to play full tracks. Premium account.',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (!connected)
            TextButton(
              onPressed: busy ? null : onConnect,
              child: busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Connect'),
            )
          else
            const Icon(Icons.check_circle, color: Color(0xFF1DB954)),
        ],
      ),
    );
  }
}
