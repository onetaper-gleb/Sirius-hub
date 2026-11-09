import 'package:client/core/api_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('configuration accepts the legacy backend and HTTPS JWT', () {
    ApiConfig.validate(
      debug: false,
      backend: 'firebase',
      url: 'http://legacy.test:56284',
    );
    ApiConfig.validate(
      debug: false,
      backend: 'jwt',
      url: 'https://api.example.test',
    );
  });
  test(
    'configuration rejects unknown auth modes and insecure JWT releases',
    () {
      expect(
        () => ApiConfig.validate(
          debug: false,
          backend: 'unknown',
          url: 'https://example.test',
        ),
        throwsArgumentError,
      );
      for (final url in [
        'http://api.example.test',
        'http://localhost:8000',
        'api.example.test',
        'file:///tmp/api',
        '',
        'https://',
        'https://api.example.test?debug=true',
        'https://api.example.test#section',
        'https://user:password@api.example.test',
        'https://api.example.test/prefix',
      ]) {
        expect(
          () => ApiConfig.validate(debug: false, backend: 'jwt', url: url),
          throwsArgumentError,
        );
      }
      expect(
        () => ApiConfig.validate(
          debug: true,
          backend: 'jwt',
          url: 'http://api.example.test',
        ),
        throwsArgumentError,
      );
      ApiConfig.validate(
        debug: true,
        backend: 'jwt',
        url: 'http://10.0.2.2:8000',
      );
    },
  );
}
