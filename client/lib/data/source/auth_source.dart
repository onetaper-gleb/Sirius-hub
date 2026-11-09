class AuthUser {
  const AuthUser({required this.uid, this.email});

  final String uid;
  final String? email;
}

abstract class AuthDataSource {
  Stream<AuthUser?> get authStateChanges;
  AuthUser? get currentUser;
  bool get needsBackendInit;
  Future<String?> getToken({bool forceRefresh = false});
  Future<AuthUser> signUp({required String email, required String password});
  Future<AuthUser> signIn({required String email, required String password});
  Future<void> setUserDisplayName(String displayName);
  Future<void> signOut();
}
