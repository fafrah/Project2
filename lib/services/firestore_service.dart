import 'user_service.dart';

/// Backwards-compatible facade. New code should depend on the
/// focused services (UserService, SessionService, QueueService,
/// VoteService) directly.
class FirestoreService {
  final UserService _users = UserService();

  Future<void> createUser({required String uid, required String email}) {
    return _users.createUser(uid: uid, email: email);
  }
}
