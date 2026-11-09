import 'package:firebase_auth/firebase_auth.dart' as firebase;
import 'auth_source.dart';

class FirebaseAuthDataSource implements AuthDataSource {
  final firebase.FirebaseAuth _auth;

  FirebaseAuthDataSource({required firebase.FirebaseAuth auth}) : _auth = auth;

  Stream<AuthUser?> get authStateChanges =>
      _auth.authStateChanges().map(_mapUser);

  AuthUser? get currentUser => _mapUser(_auth.currentUser);

  @override
  bool get needsBackendInit => true;

  AuthUser? _mapUser(firebase.User? user) =>
      user == null ? null : AuthUser(uid: user.uid, email: user.email);

  Future<String?> getToken({bool forceRefresh = false}) async {
    try {
      return await _auth.currentUser?.getIdToken(forceRefresh);
    } catch (e) {
      rethrow;
    }
  }

  Future<AuthUser> signUp({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    if (credential.user == null)
      throw Exception("Ошибка создания пользователя");
    return _mapUser(credential.user)!;
  }

  Future<void> setUserDisplayName(String displayName) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await user.updateProfile(displayName: displayName);
    await user.reload();
  }

  Future<AuthUser> signIn({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    if (credential.user == null) throw Exception("Пользователь не найден");
    return _mapUser(credential.user)!;
  }

  Future<void> signOut() => _auth.signOut();
}
