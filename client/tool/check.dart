#!/usr/bin/env dart

import 'dart:io';

Future<void> main(List<String> args) async {
  final environment = Platform.environment;
  final root = '${environment['TEST_SRCDIR']}/${environment['TEST_WORKSPACE']}';
  final temporary = await Directory.systemTemp.createTemp('sirius-client-');
  try {
    for (final path in [
      'lib',
      'test',
      'assets',
      'pubspec.yaml',
      'pubspec.lock',
      'analysis_options.yaml',
    ]) {
      final source = '$root/$path';
      if (FileSystemEntity.isDirectorySync(source)) {
        for (final file in Directory(
          source,
        ).listSync(recursive: true, followLinks: true).whereType<File>()) {
          final destination = File(
            '${temporary.path}/$path/${file.path.substring(source.length + 1)}',
          );
          destination.parent.createSync(recursive: true);
          file.copySync(destination.path);
        }
      } else {
        File(source).copySync('${temporary.path}/$path');
      }
    }
    final commands = [
      ['pub', 'get', '--offline'],
      args.single == 'analyze'
          ? ['analyze', '--no-pub', '--no-fatal-infos', '--no-fatal-warnings']
          : ['test', '--no-pub'],
    ];
    for (final arguments in commands) {
      final process = await Process.start(
        'flutter',
        arguments,
        workingDirectory: temporary.path,
        mode: ProcessStartMode.inheritStdio,
      );
      final result = await process.exitCode;
      if (result != 0) {
        exitCode = result;
        return;
      }
    }
  } finally {
    await temporary.delete(recursive: true);
  }
}
