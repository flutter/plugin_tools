// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:io' as io;

import 'package:file/file.dart';
import 'package:path/path.dart' as p;
import 'package:platform/platform.dart';

import 'common.dart';

class BuildExamplesCommand extends PluginCommand {
  BuildExamplesCommand(
    Directory packagesDir,
    FileSystem fileSystem, {
    ProcessRunner processRunner = const ProcessRunner(),
  }) : super(packagesDir, fileSystem, processRunner: processRunner) {
    argParser.addFlag(kLinux, defaultsTo: false);
    argParser.addFlag(kMacos, defaultsTo: false);
    argParser.addFlag(kWindows, defaultsTo: false);
    argParser.addFlag(kIpa, defaultsTo: io.Platform.isMacOS);
    argParser.addFlag(kApk);
  }

  @override
  final String name = 'build-examples';

  @override
  final String description =
      'Builds all example apps (IPA for iOS and APK for Android).\n\n'
      'This command requires "flutter" to be in your path.';

  @override
  Future<Null> run() async {
    if (!argResults[kIpa] &&
        !argResults[kApk] &&
        !argResults[kLinux] &&
        !argResults[kMacos] &&
        !argResults[kWindows]) {
      print(
          'None of --linux, --macos, --windows, --apk nor --ipa were specified, '
          'so not building anything.');
      return;
    }
    final String flutterCommand =
        LocalPlatform().isWindows ? 'flutter.bat' : 'flutter';

    checkSharding();
    final List<String> failingPackages = <String>[];
    await for (Directory plugin in getPlugins()) {
      for (Directory example in getExamplesForPlugin(plugin)) {
        final String packageName =
            p.relative(example.path, from: packagesDir.path);

        if (argResults[kLinux]) {
          print('\nBUILDING Linux for $packageName');
          if (isLinuxPlugin(plugin, fileSystem)) {
            // The Linux tooling is not yet stable, so we need to
            // delete any existing linux directory and create a new one
            // with 'flutter create .'
            final Directory linuxFolder =
                fileSystem.directory(p.join(example.path, 'linux'));
            bool exampleCreated = false;
            if (!linuxFolder.existsSync()) {
              int exampleCreateCode = await processRunner.runAndStream(
                  flutterCommand, <String>['create', '.'],
                  workingDir: example);
              if (exampleCreateCode == 0) {
                exampleCreated = true;
              }
            }
            int buildExitCode = await processRunner.runAndStream(
                flutterCommand, <String>['build', kLinux],
                workingDir: example);
            if (buildExitCode != 0) {
              failingPackages.add('$packageName (linux)');
            }
            if (exampleCreated && linuxFolder.existsSync()) {
              linuxFolder.deleteSync(recursive: true);
            }
          } else {
            print('Linux is not supported by this plugin');
          }
        }

        if (argResults[kMacos]) {
          print('\nBUILDING macOS for $packageName');
          if (isMacOsPlugin(plugin, fileSystem)) {
            // TODO(https://github.com/flutter/flutter/issues/46236):
            // Builing macos without running flutter pub get first results
            // in an error.
            int exitCode = await processRunner.runAndStream(
                flutterCommand, <String>['pub', 'get'],
                workingDir: example);
            if (exitCode != 0) {
              failingPackages.add('$packageName (macos)');
            } else {
              exitCode = await processRunner.runAndStream(
                  flutterCommand, <String>['build', kMacos],
                  workingDir: example);
              if (exitCode != 0) {
                failingPackages.add('$packageName (macos)');
              }
            }
          } else {
            print('macOS is not supported by this plugin');
          }
        }

        if (argResults[kWindows]) {
          print('\nBUILDING Windows for $packageName');
          if (isWindowsPlugin(plugin, fileSystem)) {
            // The Windows tooling is not yet stable, so we need to
            // delete any existing windows directory and create a new one
            // with 'flutter create .'
            final Directory windowsFolder =
                fileSystem.directory(p.join(example.path, 'windows'));
            bool exampleCreated = false;
            if (!windowsFolder.existsSync()) {
              int exampleCreateCode = await processRunner.runAndStream(
                  flutterCommand, <String>['create', '.'],
                  workingDir: example);
              if (exampleCreateCode == 0) {
                exampleCreated = true;
              }
            }
            int buildExitCode = await processRunner.runAndStream(
                flutterCommand, <String>['build', kWindows],
                workingDir: example);
            if (buildExitCode != 0) {
              failingPackages.add('$packageName (windows)');
            }
            if (exampleCreated && windowsFolder.existsSync()) {
              windowsFolder.deleteSync(recursive: true);
            }
          } else {
            print('Windows is not supported by this plugin');
          }
        }

        if (argResults[kIpa]) {
          print('\nBUILDING IPA for $packageName');
          final int exitCode = await processRunner.runAndStream(
              flutterCommand, <String>['build', 'ios', '--no-codesign'],
              workingDir: example);
          if (exitCode != 0) {
            failingPackages.add('$packageName (ipa)');
          }
        }

        if (argResults[kApk]) {
          print('\nBUILDING APK for $packageName');
          final int exitCode = await processRunner.runAndStream(
              flutterCommand, <String>['build', 'apk'],
              workingDir: example);
          if (exitCode != 0) {
            failingPackages.add('$packageName (apk)');
          }
        }
      }
    }
    print('\n\n');

    if (failingPackages.isNotEmpty) {
      print('The following build are failing (see above for details):');
      for (String package in failingPackages) {
        print(' * $package');
      }
      throw ToolExit(1);
    }

    print('All builds successful!');
  }
}
