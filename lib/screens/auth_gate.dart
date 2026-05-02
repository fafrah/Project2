import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/session_provider.dart';
import '../services/session_service.dart';
import '../services/user_service.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'session_screen.dart';

/// Top-level auth gate. Also listens for `vibzcheck://join/CODE`
/// deep links — if a signed-in user opens such a link (from a QR
/// scan in another app, or from a shared link), we route them
/// straight into the room.
///
/// `vibzcheck://spotify-callback?...` is handled by SpotifyAuthService
/// in the create-room flow. We ignore it here.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final _links = AppLinks();
  StreamSubscription<Uri>? _sub;
  final _sessions = SessionService();
  final _users = UserService();

  @override
  void initState() {
    super.initState();
    _bindLinks();
  }

  Future<void> _bindLinks() async {
    final initial = await _links.getInitialLink();
    if (initial != null) _handle(initial);
    _sub = _links.uriLinkStream.listen(_handle);
  }

  Future<void> _handle(Uri uri) async {
    if (uri.scheme != 'vibzcheck' || uri.host != 'join') return;
    if (uri.pathSegments.isEmpty) return;
    final code = uri.pathSegments.last.toUpperCase();
    if (!RegExp(r'^[A-Z0-9]{6}$').hasMatch(code)) return;

    final user = context.read<AuthProvider>().user;
    if (user == null) return; // Login flow will retain the link in URI history.

    try {
      final me = await _users.getUser(user.uid);
      final session = await _sessions.joinSessionByCode(
        code: code,
        uid: user.uid,
        username: me?.username ?? user.email!.split('@').first,
      );
      if (!mounted) return;
      context.read<SessionProvider>().setSession(session.id);
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SessionScreen(sessionId: session.id),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not join: $e')),
      );
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return auth.isSignedIn ? const HomeScreen() : const LoginScreen();
  }
}
