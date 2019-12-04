// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'package:file/file.dart';
import 'package:path/path.dart' as p;
import 'common.dart';

class DriveExamplesCommand extends PluginCommand {
  DriveExamplesCommand(
    Directory packagesDir,
    FileSystem fileSystem, {
    ProcessRunner processRunner = const ProcessRunner(),
  }) : super(packagesDir, fileSystem, processRunner: processRunner) {
    argParser.addFlag('macos',
        help: 'Runs the macOS implementation of the examples');
  }

  @override
  final String name = 'drive-examples';

  @override
  final String description = 'Runs driver tests for plugin example apps.\n\n'
      'For each *_test.dart in test_driver/ it drives an application with a '
      'corresponding name in the test/ or test_driver/ directories.\n\n'
      'For example, test_driver/app_test.dart would match test/app.dart.\n\n'
      'This command requires "flutter" to be in your path.';

  @override
  Future<Null> run() async {
    checkSharding();
    final List<String> failingTests = <String>[];
    final bool isMacos = argResults['macos'];
    await for (Directory example in getExamples()) {
      final String packageName =
          p.relative(example.path, from: packagesDir.path);
      // If macos is specified, filter out plugins that don't have a macos implementation yet.
      if (isMacos) {
        final Directory macosDir =
            fileSystem.directory(p.join(example.path, 'macos'));
        if (!macosDir.existsSync()) {
          continue;
        }
      }
      final Directory driverTests =
          fileSystem.directory(p.join(example.path, 'test_driver'));
      if (!driverTests.existsSync()) {
        // No driver tests available for this example
        continue;
      }
      // Look for driver tests ending in _test.dart in test_driver/
      await for (FileSystemEntity test in driverTests.list()) {
        final String driverTestName =
            p.relative(test.path, from: driverTests.path);
        if (!driverTestName.endsWith("_test.dart")) {
          continue;
        }
        // Try to find a matching app to drive without the _test.dart
        final String deviceTestName = driverTestName.replaceAll(
          RegExp(r'_test.dart$'),
          '.dart',
        );
        String deviceTestPath = p.join('test', deviceTestName);
        if (!fileSystem
            .file(p.join(example.path, deviceTestPath))
            .existsSync()) {
          // If the app isn't in test/ folder, look in test_driver/ instead.
          deviceTestPath = p.join('test_driver', deviceTestName);
        }
        if (!fileSystem
            .file(p.join(example.path, deviceTestPath))
            .existsSync()) {
          print('Unable to find an application for $driverTestName to drive');
          failingTests.add(p.join(example.path, driverTestName));
          continue;
        }

        final List<String> driveArgs = <String>['drive'];
        if (isMacos) {
          driveArgs.addAll(<String>[
            '-d',
            'macos',
          ]);
        }
        driveArgs.add(deviceTestPath);
        final int exitCode = await processRunner.runAndStream(
            'flutter', driveArgs,
            workingDir: example, exitOnError: true);
        if (exitCode != 0) {
          failingTests.add(p.join(packageName, deviceTestPath));
        }
      }
    }
    print('\n\n');

    if (failingTests.isNotEmpty) {
      print('The following driver tests are failing (see above for details):');
      for (String test in failingTests) {
        print(' * $test');
      }
      throw ToolExit(1);
    }

    print('All driver tests successful!');
  }
}
