import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/session.dart';
import '../services/session_service.dart';

class SessionProvider extends ChangeNotifier {
  final SessionService _sessions;

  String? _sessionId;
  Session? _session;
  StreamSubscription<Session>? _sub;

  SessionProvider({SessionService? sessions})
      : _sessions = sessions ?? SessionService();

  String? get sessionId => _sessionId;
  Session? get session => _session;
  bool get hasSession => _session != null;

  void setSession(String sessionId) {
    if (_sessionId == sessionId) return;
    _sub?.cancel();
    _sessionId = sessionId;
    _session = null;
    notifyListeners();
    _sub = _sessions.streamSession(sessionId).listen((s) {
      _session = s;
      notifyListeners();
    });
  }

  void clear() {
    _sub?.cancel();
    _sub = null;
    _sessionId = null;
    _session = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
