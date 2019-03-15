// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:io';
import 'dart:convert';

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
    final List<String> failingTests = <String>[];
    await for (Directory example in getExamples()) {
      final String packageName =
          p.relative(example.path, from: packagesDir.path);
      final Directory driverTests = Directory(p.join(example.path, 'test_driver'));
      if (!driverTests.existsSync()) {
        // No driver tests available for this example
        continue;
      }
      // Look for tests ending in _test.dart in test_driver/
      await for (FileSystemEntity test in driverTests.list()) {
        final String driverTestName = p.relative(test.path, from: driverTests.path);
        if (!driverTestName.endsWith("_test.dart")) {
          continue;
        }
        final String deviceTestName = driverTestName.replaceAll(RegExp(r'_test.dart$'), '.dart');
        String deviceTestPath = p.join('test', deviceTestName);
        if (!File(p.join(example.path, deviceTestPath)).existsSync()) {
          // If the app isn't in test/ folder, look in test_driver/ instead.
          deviceTestPath = p.join('test_driver', deviceTestName);
        }
        if (!File(p.join(example.path, deviceTestPath)).existsSync()) {
          print('Unable to find an application for $driverTestName to drive');
          failingTests.add(p.join(example.path, driverTestName));
          continue;
        }
        print(deviceTestPath);
        final Process process =
          await Process.start('flutter', <String>['drive', deviceTestPath], workingDirectory: example.path);
        process.stdout.transform(utf8.decoder).listen((String data) {
          if (data.contains('Some tests failed.')) {
            failingTests.add(p.join(example.path, deviceTestPath));
          }
          stdout.write(data);
        });
        stderr.addStream(process.stderr);
        if (await process.exitCode != 0) {
          print('failed');
          failingTests.add(p.join(example.path, deviceTestPath));
        }
      }
    }

    print('\n\n');

    if (failingTests.isNotEmpty) {
      print('The following driver tests are failing (see above for details):');
      for (String test in failingTests) {
        print(' * $test');
      }
      throw new ToolExit(1);
    }

    print('All driver tests successful!');
  }
}
