import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/track.dart';
import '../providers/auth_provider.dart';
import '../services/queue_service.dart';
import '../services/spotify_service.dart';
import '../theme/app_theme.dart';

class SearchScreen extends StatefulWidget {
  final String sessionId;
  const SearchScreen({super.key, required this.sessionId});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final queue = QueueService();
  final spotify = SpotifyService();
  final controller = TextEditingController();

  Timer? _debounce;
  String _query = '';
  bool _loading = false;
  String? _error;
  List<Track> _results = const [];

  @override
  void dispose() {
    _debounce?.cancel();
    controller.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    setState(() => _query = v);
    _debounce?.cancel();
    if (v.trim().isEmpty) {
      setState(() {
        _results = const [];
        _error = null;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), _runSearch);
  }

  Future<void> _runSearch() async {
    final q = _query.trim();
    if (q.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await spotify.search(q);
      if (!mounted || _query.trim() != q) return;
      setState(() {
        _results = results;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _friendly(e);
      });
    }
  }

  String _friendly(Object e) {
    final s = e.toString();
    if (s.contains('unauthenticated')) return 'Please sign in again.';
    if (s.contains('SPOTIFY_CLIENT_ID') || s.contains('not-found')) {
      return 'Spotify is not configured yet — set the Cloud Function secrets.';
    }
    return 'Search failed. Try again.';
  }

  Future<void> _add(Track t) async {
    final uid = context.read<AuthProvider>().user?.uid;
    if (uid == null) return;
    await queue.addToQueue(
      sessionId: widget.sessionId,
      track: t,
      addedBy: uid,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Added "${t.name}" to the queue')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add a song')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: TextField(
                controller: controller,
                autofocus: true,
                onChanged: _onChanged,
                onSubmitted: (_) => _runSearch(),
                decoration: InputDecoration(
                  hintText: 'Search Spotify',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _loading
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : null,
                ),
              ),
            ),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_error != null) {
      return _Message(icon: Icons.error_outline, text: _error!);
    }
    if (_query.trim().isEmpty) {
      return const _Message(
        icon: Icons.search,
        text: 'Search for tracks or artists to add to the queue.',
      );
    }
    if (_results.isEmpty && !_loading) {
      return _Message(
        icon: Icons.music_off,
        text: 'No results for "$_query".',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.md,
      ),
      itemCount: _results.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, i) {
        final t = _results[i];
        return _TrackTile(track: t, onAdd: () => _add(t));
      },
    );
  }
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Message({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.textMuted, size: 48),
            const SizedBox(height: AppSpacing.sm),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrackTile extends StatelessWidget {
  final Track track;
  final VoidCallback onAdd;
  const _TrackTile({required this.track, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: track.albumArt != null
                ? Image.network(
                    track.albumArt!,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _Fallback(seed: track.id),
                  )
                : _Fallback(seed: track.id),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  track.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  track.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle, color: AppColors.primary),
            iconSize: 32,
            onPressed: onAdd,
          ),
        ],
      ),
    );
  }
}

class _Fallback extends StatelessWidget {
  final String seed;
  const _Fallback({required this.seed});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        gradient: MoodColor.gradientForSeed(seed),
      ),
      child: const Icon(Icons.music_note, color: Colors.white, size: 24),
    );
  }
}
