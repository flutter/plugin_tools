// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'common.dart';

class DriveExamplesCommand extends PluginCommand {
  DriveExamplesCommand(Directory packagesDir) : super(packagesDir);

  @override
  final String name = 'drive-examples';

  @override
  final String description =
      'Runs driver tests for example apps.\n\n'
      'This command requires "flutter" to be in your path.';

  @override
  Future<Null> run() async {
    checkSharding();
    final List<String> failingPackages = <String>[];
    await for (Directory example in getExamples()) {
      final String packageName =
          p.relative(example.path, from: packagesDir.path);
      final Directory testDriveDirectory = example.child(example, 'test_driver');
      // test_driver/package_name_test.dart drives test/package_name.dart
      await for (File test in testDriveDirectory) {
        final String baseName = p.relative(file.path, from: testDriveDirectory.path);
        final String targetName = example.child(['test', '$baseName.dart']);
        final String targetPath = p.relative()
        final int exitCode = await runAndStream(
            'flutter', <String>['drive', test],
            workingDir: example);
        if (exitCode != 0 || logOutput.match("Some tests failed.")) {
          failingPackages.add("$packageName $testName");
        }
      }
    }

    print('\n\n');

    if (failingPackages.isNotEmpty) {
      print('The following driver tests are failing (see above for details):');
      for (String package in failingPackages) {
        print(' * $package');
      }
      throw new ToolExit(1);
    }

    print('All driver tests successful!');
  }
}
