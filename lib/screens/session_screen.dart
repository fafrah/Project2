import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/queue_item.dart';
import '../models/session.dart';
import '../models/track.dart';
import '../providers/auth_provider.dart';
import '../providers/session_provider.dart';
import '../services/playback_service.dart';
import '../services/queue_service.dart';
import '../services/session_service.dart';
import '../services/spotify_service.dart';
import '../services/vote_service.dart';
import '../theme/app_theme.dart';
import '../widgets/gradient_button.dart';
import 'search_screen.dart';
import 'session_chat_tab.dart';

class SessionScreen extends StatefulWidget {
  final String sessionId;
  const SessionScreen({super.key, required this.sessionId});

  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen>
    with SingleTickerProviderStateMixin {
  final sessions = SessionService();
  final queue = QueueService();
  final votes = VoteService();
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    context.read<SessionProvider>().setSession(widget.sessionId);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _leave() async {
    final uid = context.read<AuthProvider>().user?.uid;
    if (uid != null) {
      await sessions.leaveSession(sessionId: widget.sessionId, uid: uid);
    }
    if (!mounted) return;
    context.read<SessionProvider>().clear();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Session>(
      stream: sessions.streamSession(widget.sessionId),
      builder: (context, snap) {
        final session = snap.data;
        return Scaffold(
          appBar: AppBar(
            title: Text(session?.name ?? 'Loading…'),
            actions: [
              IconButton(
                icon: const Icon(Icons.exit_to_app),
                tooltip: 'Leave room',
                onPressed: _leave,
              ),
            ],
            bottom: TabBar(
              controller: _tabs,
              indicatorColor: AppColors.primaryAlt,
              labelColor: AppColors.textPrimary,
              unselectedLabelColor: AppColors.textMuted,
              tabs: const [
                Tab(icon: Icon(Icons.queue_music), text: 'Queue'),
                Tab(icon: Icon(Icons.chat_bubble_outline), text: 'Chat'),
                Tab(icon: Icon(Icons.auto_awesome), text: 'Vibe'),
              ],
            ),
          ),
          floatingActionButton: _tabs.index == 0
              ? FloatingActionButton.extended(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  icon: const Icon(Icons.add),
                  label: const Text('Add song'),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          SearchScreen(sessionId: widget.sessionId),
                    ),
                  ),
                )
              : null,
          body: session == null
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    _NowPlayingHeader(session: session),
                    Expanded(
                      child: TabBarView(
                        controller: _tabs,
                        children: [
                          _QueueTab(
                            sessionId: widget.sessionId,
                            queue: queue,
                            votes: votes,
                          ),
                          SessionChatTab(sessionId: widget.sessionId),
                          _VibeTab(sessionId: widget.sessionId),
                        ],
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }
}

class _NowPlayingHeader extends StatefulWidget {
  final Session session;
  const _NowPlayingHeader({required this.session});

  @override
  State<_NowPlayingHeader> createState() => _NowPlayingHeaderState();
}

class _NowPlayingHeaderState extends State<_NowPlayingHeader> {
  final playback = PlaybackService();
  Timer? _ticker;
  bool _autoAdvancing = false;

  @override
  void initState() {
    super.initState();
    _restartTicker();
  }

  @override
  void didUpdateWidget(covariant _NowPlayingHeader old) {
    super.didUpdateWidget(old);
    // New session snapshot — restart the ticker so a track change
    // resets the local clock-driven progress immediately.
    _restartTicker();
  }

  void _restartTicker() {
    _ticker?.cancel();
    if (widget.session.currentTrack == null) return;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
      _maybeAutoAdvance();
    });
  }

  Future<void> _maybeAutoAdvance() async {
    final user = context.read<AuthProvider>().user;
    final track = widget.session.currentTrack;
    if (track == null || _autoAdvancing) return;
    final isHost = user?.uid == widget.session.hostUid;
    if (!isHost) return;
    if (!track.isFinished) return;
    _autoAdvancing = true;
    try {
      await playback.playNext(sessionId: widget.session.id);
    } catch (_) {
      // Swallow — next tick will retry.
    } finally {
      _autoAdvancing = false;
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final track = session.currentTrack;
    final seed = track?.trackId ?? session.id;
    final user = context.watch<AuthProvider>().user;
    final isHost = user?.uid == session.hostUid;

    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        0,
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        gradient: MoodColor.gradientForSeed(seed),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [
          BoxShadow(
            color: MoodColor.forSeed(seed).withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Artwork(track: track, seed: seed),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: _TrackInfo(session: session, track: track)),
              const SizedBox(width: AppSpacing.sm),
              _CodeChip(code: session.joinCode),
            ],
          ),
          if (track != null) ...[
            const SizedBox(height: AppSpacing.md),
            _ProgressBar(track: track),
            const SizedBox(height: AppSpacing.sm),
            _PlaybackControls(
              isHost: isHost,
              hasTrack: true,
              onSkip: _skip,
              onStop: _stop,
            ),
          ] else if (isHost) ...[
            const SizedBox(height: AppSpacing.md),
            _PlaybackControls(
              isHost: true,
              hasTrack: false,
              onPlay: _playNext,
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _playNext() async {
    try {
      final id = await playback.playNext(sessionId: widget.session.id);
      if (id == null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Queue is empty.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not play next: $e')),
      );
    }
  }

  Future<void> _skip() => _playNext();

  Future<void> _stop() async {
    try {
      await playback.stop(sessionId: widget.session.id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not stop: $e')),
      );
    }
  }
}

class _Artwork extends StatelessWidget {
  final NowPlaying? track;
  final String seed;
  const _Artwork({required this.track, required this.seed});

  @override
  Widget build(BuildContext context) {
    final art = track?.albumArt;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: art != null && art.isNotEmpty
          ? Image.network(
              art,
              width: 72,
              height: 72,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _ArtworkFallback(seed: seed),
            )
          : _ArtworkFallback(seed: seed),
    );
  }
}

class _ArtworkFallback extends StatelessWidget {
  final String seed;
  const _ArtworkFallback({required this.seed});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: const Icon(Icons.music_note, color: Colors.white, size: 32),
    );
  }
}

class _TrackInfo extends StatelessWidget {
  final Session session;
  final NowPlaying? track;
  const _TrackInfo({required this.session, required this.track});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          track == null ? 'NOTHING PLAYING' : 'NOW PLAYING',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.85),
            fontSize: 11,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          track?.trackName.isNotEmpty == true
              ? track!.trackName
              : track == null
                  ? 'Queue up a song to get started'
                  : 'Untitled track',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (track != null && track!.artist.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            track!.artist,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 13,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        const SizedBox(height: 6),
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: SessionService().streamMembers(session.id),
          builder: (context, snap) {
            final count = snap.data?.length ?? session.memberCount;
            return Row(
              children: [
                const Icon(Icons.people, color: Colors.white, size: 14),
                const SizedBox(width: 4),
                Text(
                  '$count listening',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final NowPlaying track;
  const _ProgressBar({required this.track});

  @override
  Widget build(BuildContext context) {
    final elapsed = track.elapsedMs();
    final progress = track.durationMs == 0
        ? 0.0
        : (elapsed / track.durationMs).clamp(0.0, 1.0);
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 4,
            backgroundColor: Colors.white.withValues(alpha: 0.25),
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _format(elapsed),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 11,
              ),
            ),
            Text(
              _format(track.durationMs),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _format(int ms) {
    final s = (ms / 1000).round();
    final m = s ~/ 60;
    final sec = s % 60;
    return '$m:${sec.toString().padLeft(2, '0')}';
  }
}

class _PlaybackControls extends StatelessWidget {
  final bool isHost;
  final bool hasTrack;
  final VoidCallback? onPlay;
  final VoidCallback? onSkip;
  final VoidCallback? onStop;

  const _PlaybackControls({
    required this.isHost,
    required this.hasTrack,
    this.onPlay,
    this.onSkip,
    this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    if (!isHost) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.headphones, size: 14, color: Colors.white),
                SizedBox(width: 6),
                Text(
                  'Host controls playback',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (hasTrack) ...[
          _CtrlButton(
            icon: Icons.stop_rounded,
            label: 'Stop',
            onPressed: onStop,
          ),
          const SizedBox(width: AppSpacing.sm),
          _CtrlButton(
            icon: Icons.skip_next_rounded,
            label: 'Skip',
            primary: true,
            onPressed: onSkip,
          ),
        ] else
          _CtrlButton(
            icon: Icons.play_arrow_rounded,
            label: 'Play next',
            primary: true,
            onPressed: onPlay,
          ),
      ],
    );
  }
}

class _CtrlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool primary;
  final VoidCallback? onPressed;

  const _CtrlButton({
    required this.icon,
    required this.label,
    this.primary = false,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: primary
          ? Colors.white
          : Colors.white.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 8,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: primary ? AppColors.primary : Colors.white,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: primary ? AppColors.primary : Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CodeChip extends StatelessWidget {
  final String code;
  const _CodeChip({required this.code});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.pill),
      onTap: () => _showInviteSheet(context, code),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Row(
          children: [
            const Icon(Icons.qr_code, size: 14, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              code,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showInviteSheet(BuildContext context, String code) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (_) => _InviteSheet(code: code),
    );
  }
}

class _InviteSheet extends StatelessWidget {
  final String code;
  const _InviteSheet({required this.code});

  @override
  Widget build(BuildContext context) {
    final deepLink = 'vibzcheck://join/$code';
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Invite friends',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.xs),
          const Text(
            'Scan the QR or share the code.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.lg),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: QrImageView(
              data: deepLink,
              size: 220,
              backgroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          InkWell(
            onTap: () async {
              await Clipboard.setData(ClipboardData(text: code));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Copied code "$code"')),
              );
            },
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    code,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 4,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  const Icon(Icons.content_copy, size: 18,
                      color: AppColors.textSecondary),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }
}

class _QueueTab extends StatelessWidget {
  final String sessionId;
  final QueueService queue;
  final VoteService votes;
  const _QueueTab({
    required this.sessionId,
    required this.queue,
    required this.votes,
  });

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AuthProvider>().user?.uid;
    return StreamBuilder<List<QueueItem>>(
      stream: queue.streamQueue(sessionId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snap.data ?? const <QueueItem>[];
        if (items.isEmpty) return const _EmptyQueue();
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            96,
          ),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
          itemBuilder: (context, i) => _QueueRow(
            item: items[i],
            rank: i + 1,
            currentUid: uid,
            sessionId: sessionId,
            votes: votes,
          ),
        );
      },
    );
  }
}

class _QueueRow extends StatelessWidget {
  final QueueItem item;
  final int rank;
  final String? currentUid;
  final String sessionId;
  final VoteService votes;

  const _QueueRow({
    required this.item,
    required this.rank,
    required this.currentUid,
    required this.sessionId,
    required this.votes,
  });

  @override
  Widget build(BuildContext context) {
    final mood = MoodColor.forSeed(item.trackId);

    Stream<int?> myVote() => currentUid == null
        ? const Stream.empty()
        : votes.streamMyVote(
            sessionId: sessionId,
            queueItemId: item.id,
            uid: currentUid!,
          );

    Future<void> cast(int target) async {
      if (currentUid == null) return;
      // Toggle: tapping same direction again clears the vote.
      final stream = await myVote().first;
      final next = stream == target ? 0 : target;
      await votes.castVote(
        sessionId: sessionId,
        queueItemId: item.id,
        uid: currentUid!,
        value: next,
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: MoodColor.gradientForSeed(item.trackId),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Text(
              '$rank',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.trackName,
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
                  item.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                if (item.tags.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 4,
                    children: item.tags
                        .take(3)
                        .map(
                          (t) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: mood.withValues(alpha: 0.18),
                              borderRadius:
                                  BorderRadius.circular(AppRadius.pill),
                            ),
                            child: Text(
                              t,
                              style: TextStyle(
                                color: mood,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
          StreamBuilder<int?>(
            stream: myVote(),
            builder: (context, voteSnap) {
              final myVal = voteSnap.data ?? 0;
              return Column(
                children: [
                  _VoteBtn(
                    icon: Icons.keyboard_arrow_up_rounded,
                    active: myVal == 1,
                    activeColor: AppColors.upvote,
                    onTap: () => cast(1),
                  ),
                  Text(
                    '${item.voteScore}',
                    style: TextStyle(
                      color: item.voteScore > 0
                          ? AppColors.upvote
                          : item.voteScore < 0
                              ? AppColors.downvote
                              : AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  _VoteBtn(
                    icon: Icons.keyboard_arrow_down_rounded,
                    active: myVal == -1,
                    activeColor: AppColors.downvote,
                    onTap: () => cast(-1),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _VoteBtn extends StatelessWidget {
  final IconData icon;
  final bool active;
  final Color activeColor;
  final VoidCallback onTap;
  const _VoteBtn({
    required this.icon,
    required this.active,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Container(
        width: 36,
        height: 28,
        alignment: Alignment.center,
        child: Icon(
          icon,
          size: 26,
          color: active ? activeColor : AppColors.textMuted,
        ),
      ),
    );
  }
}

class _EmptyQueue extends StatelessWidget {
  const _EmptyQueue();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: AppColors.gradient,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.queue_music, color: Colors.white, size: 40),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Queue is empty',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.xs),
            const Text(
              'Tap "Add song" to get the vibe started.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _VibeTab extends StatefulWidget {
  final String sessionId;
  const _VibeTab({required this.sessionId});

  @override
  State<_VibeTab> createState() => _VibeTabState();
}

class _VibeTabState extends State<_VibeTab> {
  final spotify = SpotifyService();
  final queue = QueueService();

  bool _loading = false;
  String? _error;
  List<Track> _recs = const [];

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await spotify.recommend(sessionId: widget.sessionId);
      if (!mounted) return;
      setState(() {
        _recs = results;
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
    if (s.contains('failed-precondition')) {
      return 'Add a few real Spotify tracks first — recommendations come from the room\'s shared taste.';
    }
    if (s.contains('SPOTIFY_CLIENT_ID') || s.contains('not-found')) {
      return 'Spotify is not configured yet — set the Cloud Function secrets.';
    }
    if (s.contains('unauthenticated')) return 'Please sign in again.';
    return 'Could not load recommendations.';
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
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Recommendations',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.xs),
          const Text(
            "Tuned to your room's shared taste.",
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(child: _list()),
          const SizedBox(height: AppSpacing.md),
          GradientButton(
            label: _recs.isEmpty
                ? 'Get recommendations'
                : 'Refresh recommendations',
            icon: Icons.auto_awesome,
            loading: _loading,
            onPressed: _refresh,
          ),
        ],
      ),
    );
  }

  Widget _list() {
    if (_error != null) {
      return _VibeMessage(icon: Icons.info_outline, text: _error!);
    }
    if (_recs.isEmpty && !_loading) {
      return _VibeMessage(
        icon: Icons.auto_awesome,
        text:
            "Tap below to surface tracks tuned to your room's averaged energy, valence, and tempo.",
      );
    }
    if (_recs.isEmpty && _loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView.separated(
      itemCount: _recs.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, i) {
        final t = _recs[i];
        return _RecTile(track: t, onAdd: () => _add(t));
      },
    );
  }
}

class _VibeMessage extends StatelessWidget {
  final IconData icon;
  final String text;
  const _VibeMessage({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
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

class _RecTile extends StatelessWidget {
  final Track track;
  final VoidCallback onAdd;
  const _RecTile({required this.track, required this.onAdd});

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
                    errorBuilder: (_, _, _) => Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: MoodColor.gradientForSeed(track.id),
                      ),
                      child: const Icon(
                        Icons.music_note,
                        color: Colors.white,
                      ),
                    ),
                  )
                : Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: MoodColor.gradientForSeed(track.id),
                    ),
                    child: const Icon(
                      Icons.music_note,
                      color: Colors.white,
                    ),
                  ),
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
