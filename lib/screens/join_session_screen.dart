import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/session_provider.dart';
import '../services/session_service.dart';
import '../services/user_service.dart';
import '../theme/app_theme.dart';
import '../widgets/gradient_button.dart';
import 'session_screen.dart';

class JoinSessionScreen extends StatefulWidget {
  const JoinSessionScreen({super.key});

  @override
  State<JoinSessionScreen> createState() => _JoinSessionScreenState();
}

class _JoinSessionScreenState extends State<JoinSessionScreen> {
  final codeController = TextEditingController();
  final sessions = SessionService();
  final users = UserService();
  bool loading = false;

  @override
  void dispose() {
    codeController.dispose();
    super.dispose();
  }

  Future<void> _join({String? overrideCode}) async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;
    final code =
        (overrideCode ?? codeController.text).trim().toUpperCase();
    if (code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Codes are 6 characters.')),
      );
      return;
    }
    setState(() => loading = true);
    try {
      final me = await users.getUser(user.uid);
      final session = await sessions.joinSessionByCode(
        code: code,
        uid: user.uid,
        username: me?.username ?? user.email!.split('@').first,
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
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
      );
    }
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Join room')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Enter room code',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Ask the host for the 6-character code.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: codeController,
                textCapitalization: TextCapitalization.characters,
                textAlign: TextAlign.center,
                maxLength: 6,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[A-Z0-9]')),
                  UpperCaseTextFormatter(),
                ],
                style: const TextStyle(
                  fontSize: 28,
                  letterSpacing: 8,
                  fontWeight: FontWeight.w700,
                ),
                decoration: const InputDecoration(
                  hintText: 'ABCD12',
                  counterText: '',
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              GradientButton(
                label: 'Join room',
                icon: Icons.login,
                loading: loading,
                onPressed: _join,
              ),
              const SizedBox(height: AppSpacing.md),
              OutlinedButton.icon(
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Scan QR code'),
                onPressed: loading ? null : _scan,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _scan() async {
    final code = await Navigator.push<String?>(
      context,
      MaterialPageRoute(builder: (_) => const _QrScanScreen()),
    );
    if (code == null || !mounted) return;
    codeController.text = code;
    await _join(overrideCode: code);
  }
}

class _QrScanScreen extends StatefulWidget {
  const _QrScanScreen();

  @override
  State<_QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<_QrScanScreen> {
  final _controller = MobileScannerController();
  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    for (final code in capture.barcodes) {
      final raw = code.rawValue;
      if (raw == null) continue;
      final extracted = _extractRoomCode(raw);
      if (extracted != null) {
        _handled = true;
        Navigator.pop(context, extracted);
        return;
      }
    }
  }

  /// Pulls a 6-char room code out of either a raw code or a
  /// `vibzcheck://join/ABC123` deep link.
  static String? _extractRoomCode(String raw) {
    final trimmed = raw.trim();
    final upper = trimmed.toUpperCase();
    final plain = RegExp(r'^[A-Z0-9]{6}$');
    if (plain.hasMatch(upper)) return upper;
    final uri = Uri.tryParse(trimmed);
    if (uri != null && uri.scheme == 'vibzcheck' && uri.host == 'join') {
      final last = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : '';
      if (plain.hasMatch(last.toUpperCase())) return last.toUpperCase();
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan room QR')),
      body: MobileScanner(controller: _controller, onDetect: _onDetect),
    );
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}
