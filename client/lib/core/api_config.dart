abstract final class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://104.143.201.57',
  );
  static const String authBackend = String.fromEnvironment(
    'AUTH_BACKEND',
    defaultValue: 'firebase',
  );

  static void validate({
    required bool debug,
    String backend = authBackend,
    String url = baseUrl,
  }) {
    if (backend != 'firebase' && backend != 'jwt') {
      throw ArgumentError('AUTH_BACKEND must be firebase or jwt');
    }
    final uri = Uri.parse(url);
    final local = [
      'localhost',
      '127.0.0.1',
      '10.0.2.2',
      '::1',
    ].contains(uri.host);
    if (!uri.hasAuthority ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.path.isNotEmpty && uri.path != '/') ||
        !['https', 'http'].contains(uri.scheme) ||
        (backend == 'jwt' && uri.scheme != 'https' && !(debug && local))) {
      throw ArgumentError(
        'JWT requires an HTTPS API_BASE_URL (local HTTP is allowed in debug builds)',
      );
    }
  }
}
