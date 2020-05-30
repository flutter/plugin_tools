// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'package:file/file.dart';
import 'package:path/path.dart' as p;
import 'package:platform/platform.dart';
import 'common.dart';

class DriveExamplesCommand extends PluginCommand {
  DriveExamplesCommand(
    Directory packagesDir,
    FileSystem fileSystem, {
    ProcessRunner processRunner = const ProcessRunner(),
  }) : super(packagesDir, fileSystem, processRunner: processRunner) {
    // TODO(cyanglaz): Make mobile platforms flags also required like other platforms (breaking change).
    // https://github.com/flutter/flutter/issues/58285
    argParser.addFlag(kLinux,
        help: 'Runs the Linux implementation of the examples');
    argParser.addFlag(kMacos,
        help: 'Runs the macOS implementation of the examples');
    argParser.addFlag(kWindows,
        help: 'Runs the Windows implementation of the examples');
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
    final bool isLinux = argResults[kLinux];
    final bool isMacos = argResults[kMacos];
    final bool isWindows = argResults[kWindows];
    await for (Directory plugin in getPlugins()) {
      for (Directory example in getExamplesForPlugin(plugin)) {
        if (!(await pluginSupportedOnCurrentPlatform(
            plugin, fileSystem, example))) {
          continue;
        }

        final String packageName =
            p.relative(example.path, from: packagesDir.path);
        final String flutterCommand =
            LocalPlatform().isWindows ? 'flutter.bat' : 'flutter';
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
          if (!driverTestName.endsWith('_test.dart')) {
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
          if (isLinux && isLinuxPlugin(plugin, fileSystem)) {
            driveArgs.addAll(<String>[
              '-d',
              'linux',
            ]);
          }
          if (isMacos && isMacOsPlugin(plugin, fileSystem)) {
            driveArgs.addAll(<String>[
              '-d',
              'macos',
            ]);
          }
          if (isWindows && isWindowsPlugin(plugin, fileSystem)) {
            driveArgs.addAll(<String>[
              '-d',
              'windows',
            ]);
          }
          driveArgs.add(deviceTestPath);
          final int exitCode = await processRunner.runAndStream(
              flutterCommand, driveArgs,
              workingDir: example, exitOnError: true);
          if (exitCode != 0) {
            failingTests.add(p.join(packageName, deviceTestPath));
          }
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

  Future<bool> pluginSupportedOnCurrentPlatform(
      FileSystemEntity plugin, FileSystem fileSystem, Directory example) async {
    final String packageName = p.relative(example.path, from: packagesDir.path);
    final String flutterCommand =
        LocalPlatform().isWindows ? 'flutter.bat' : 'flutter';

    final bool isLinux = argResults[kLinux];
    final bool isMacos = argResults[kMacos];
    final bool isWindows = argResults[kWindows];
    if (isLinux) {
      if (!isLinuxPlugin(plugin, fileSystem)) {
        return false;
      }
      // The Linux tooling is not yet stable, so we need to
      // delete any existing linux directory and create a new one
      // with 'flutter create .'
      final Directory linuxFolder =
          fileSystem.directory(p.join(example.path, 'linux'));
      if (!linuxFolder.existsSync()) {
        int exitCode = await processRunner.runAndStream(
            flutterCommand, <String>['create', '.'],
            workingDir: example);
        if (exitCode != 0) {
          print('Failed to create a linux directory for $packageName');
          return false;
        }
      }
      return true;
    }
    if (isMacos) {
      if (!isMacOsPlugin(plugin, fileSystem)) {
        return false;
      }
      return true;
    }
    if (isWindows) {
      if (!isWindowsPlugin(plugin, fileSystem)) {
        return false;
      }
      // The Windows tooling is not yet stable, so we need to
      // delete any existing windows directory and create a new one
      // with 'flutter create .'
      final Directory windowsFolder =
          fileSystem.directory(p.join(example.path, 'windows'));
      if (!windowsFolder.existsSync()) {
        int exitCode = await processRunner.runAndStream(
            flutterCommand, <String>['create', '.'],
            workingDir: example);
        if (exitCode != 0) {
          print('Failed to create a windows directory for $packageName');
          return false;
        }
      }
      return true;
    }
    // When we are here, only return true if the plugin supports mobile.
    final bool isMobilePlugin =
        isIosPlugin(plugin, fileSystem) || isAndroidPlugin(plugin, fileSystem);
    return isMobilePlugin;
  }
}
