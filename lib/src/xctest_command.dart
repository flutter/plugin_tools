// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:file/file.dart';

import 'common.dart';

class XCTestCommand extends PluginCommand {
  XCTestCommand(
    Directory packagesDir,
    FileSystem fileSystem, {
    ProcessRunner processRunner = const ProcessRunner(),
  }) : super(packagesDir, fileSystem, processRunner: processRunner);

  @override
  final String name = 'xctest';

  @override
  final String description = 'Runs the XCTest of the example apps.\n\n'
      'Building the example apps is required before executing this'
      'command.';

  static const String _xcodebuildWrapper = 'xcodebuild';
  static const String _podFile = 'Podfile.lock';

  @override
  Future<Null> run() async {
    print('running xctest command');
    checkSharding();
    final Stream<Directory> examplesWithTests = getExamples().where(
        (Directory directory) =>
            isFlutterPackage(directory, fileSystem) &&
            fileSystem.directory(p.join(directory.path, 'ios'))
                .existsSync());

    final List<String> failingPackages = <String>[];
    final List<String> missingFlutterBuild = <String>[];
    await for (Directory example in examplesWithTests) {
      final String packageName =
          p.relative(example.path, from: packagesDir.path);
      print('\nRUNNING XCTest TESTS for $packageName');

      final Directory iOSDirectory =
          fileSystem.directory(p.join(example.path, 'ios'));
      if (!fileSystem.directory(p.join(iOSDirectory.path, _podFile))
          .existsSync()) {
        print('ERROR: Run "flutter build ios" on example app of $packageName '
            'before executing tests.');
        missingFlutterBuild.add(packageName);
        continue;
      }
      final int exitCode = await processRunner.runAndStream(
          _xcodebuildWrapper,
          <String>['-list', '|', 'grep', 'RunnerUnitTests'],
          workingDir: iOSDirectory);
          print('find scheme $exitCode');
      if (exitCode == 0) {
          final int exitCode = await processRunner.runAndStream(
          _xcodebuildWrapper,
          <String>['-workspace', 'Runner.xcworkspace', '-scheme', 'RunnerUnitTests', '-sdk', 'iphonesimulator', '-destination', 'platform=iOS Simulator,name=iPhone Xs', 'test'],
          workingDir: iOSDirectory);
          if (exitCode != 0) {
            failingPackages.add(packageName);
          }
      }
    }

    print('\n\n');
    if (failingPackages.isNotEmpty) {
      print(
          'The XCTest tests for the following packages are failing (see above for'
          'details):');
      for (String package in failingPackages) {
        print(' * $package');
      }
    }
    if (missingFlutterBuild.isNotEmpty) {
      print('Run "pub global run flutter_plugin_tools build-examples --ios" on '
          'the following packages before executing tests again:');
      for (String package in missingFlutterBuild) {
        print(' * $package');
      }
    }

    if (failingPackages.isNotEmpty || missingFlutterBuild.isNotEmpty) {
      throw new ToolExit(1);
    }

    print('All XCTest tests successful!');
  }
}
