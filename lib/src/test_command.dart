// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'common.dart';

class TestCommand extends PluginCommand {
  TestCommand(Directory packagesDir) : super(packagesDir);

  @override
  final String name = 'test';

  @override
  final String description = 'Runs the Dart tests for all packages.\n\n'
      'This command requires "flutter" to be in your path.';

  @override
  Future<Null> run() async {
    checkSharding();
    final List<String> failingPackages = <String>[];
    await for (Directory packageDir in getPackages()) {
      final String packageName =
          p.relative(packageDir.path, from: packagesDir.path);
      if (!new Directory(p.join(packageDir.path, 'test')).existsSync()) {
        print('SKIPPING $packageName - no test subdirectory');
        continue;
      }

      print('RUNNING $packageName tests...');
      final int exitCode = await runAndStream(
          'flutter', <String>['test', '--color'],
          workingDir: packageDir);
      if (exitCode != 0) {
        failingPackages.add(packageName);
      }
    }

    print('\n\n');
    if (failingPackages.isNotEmpty) {
      print('Tests for the following packages are failing (see above):');
      failingPackages.forEach((String package) {
        print(' * $package');
      });
      throw new ToolExit(1);
    }

    print('All tests are passing!');
  }
}
