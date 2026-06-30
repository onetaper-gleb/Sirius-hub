import 'package:firebase_auth/firebase_auth.dart' as firebase;

class FirebaseAuthDataSource {
  final firebase.FirebaseAuth _auth;

  FirebaseAuthDataSource({required firebase.FirebaseAuth auth}) : _auth = auth;

  Stream<firebase.User?> get authStateChanges => _auth.authStateChanges();

  firebase.User? get currentUser => _auth.currentUser;

  Future<String?> getToken({bool forceRefresh = false}) async {
    try {
      return await _auth.currentUser?.getIdToken(forceRefresh);
    } catch (e) {
      rethrow;
    }
  }

  Future<firebase.User> signUp({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    if (credential.user == null)
      throw Exception("Ошибка создания пользователя");
    return credential.user!;
  }

  Future<void> setUserDisplayName(String displayName) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await user.updateProfile(displayName: displayName);
    await user.reload();
  }

  Future<firebase.User> signIn({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    if (credential.user == null) throw Exception("Пользователь не найден");
    return credential.user!;
  }

  Future<void> signOut() => _auth.signOut();

  Future<void> deleteCurrentUser() async {
    await _auth.currentUser?.delete();
  }
}
