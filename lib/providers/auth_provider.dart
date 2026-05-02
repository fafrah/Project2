import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../services/auth_services.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _auth;
  StreamSubscription<User?>? _sub;
  User? _user;

  AuthProvider({AuthService? auth}) : _auth = auth ?? AuthService() {
    _user = _auth.currentUser;
    _sub = _auth.authStateChanges.listen((u) {
      _user = u;
      notifyListeners();
    });
  }

  User? get user => _user;
  bool get isSignedIn => _user != null;

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
