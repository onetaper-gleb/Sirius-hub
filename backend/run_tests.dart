import 'dart:io';

Future<void> main(List<String> arguments) async {
  final python = Platform.environment['BACKEND_TEST_PYTHON'] ?? 'python3';
  final result = await Process.start(
    python,
    ['-m', 'pytest', '-p', 'no:cacheprovider', 'tests', ...arguments],
    environment: {'PYTHONDONTWRITEBYTECODE': '1'},
    mode: ProcessStartMode.inheritStdio,
  );
  exit(await result.exitCode);
}
