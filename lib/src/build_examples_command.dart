// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:io' as io;

import 'package:file/file.dart';
import 'package:path/path.dart' as p;

import 'common.dart';

class BuildExamplesCommand extends PluginCommand {
  BuildExamplesCommand(
    Directory packagesDir,
    FileSystem fileSystem, {
    ProcessRunner processRunner = const ProcessRunner(),
  }) : super(packagesDir, fileSystem, processRunner: processRunner) {
    argParser.addFlag('macos', defaultsTo: false);
    argParser.addFlag('ipa', defaultsTo: io.Platform.isMacOS);
    argParser.addFlag('apk');
  }

  @override
  final String name = 'build-examples';

  @override
  final String description =
      'Builds all example apps (IPA for iOS and APK for Android).\n\n'
      'This command requires "flutter" to be in your path.';

  @override
  Future<Null> run() async {
    if (!argResults['ipa'] && !argResults['apk'] && !argResults['macos']) {
      print('Neither --macos, --apk nor --ipa were specified, so not building '
          'anything.');
      return;
    }

    checkSharding();
    final List<String> failingPackages = <String>[];
    await for (io.Directory example in getExamples()) {
      final String packageName =
          p.relative(example.path, from: packagesDir.path);

      if (argResults['macos']) {
        print('\nBUILDING macos for $packageName');
        final Directory macosDir =
            fileSystem.directory(p.join(example.path, 'macos'));
        if (!macosDir.existsSync()) {
          print('No macOS implementation found.');
          continue;
        }
        // TODO(https://github.com/flutter/flutter/issues/46236):
        // Builing macos without running flutter pub get first results
        // in an error.
        int exitCode = await processRunner.runAndStream(
            'flutter', <String>['pub', 'get'],
            workingDir: example);
        if (exitCode != 0) {
          failingPackages.add('$packageName (macos)');
        }

        exitCode = await processRunner.runAndStream(
            'flutter', <String>['build', 'macos'],
            workingDir: example);
        if (exitCode != 0) {
          failingPackages.add('$packageName (macos)');
        }
      }

      if (argResults['ipa']) {
        print('\nBUILDING IPA for $packageName');
        final int exitCode = await processRunner.runAndStream(
            'flutter', <String>['build', 'ios', '--no-codesign'],
            workingDir: example);
        if (exitCode != 0) {
          failingPackages.add('$packageName (ipa)');
        }
      }

      if (argResults['apk']) {
        print('\nBUILDING APK for $packageName');
        final int exitCode = await processRunner.runAndStream(
            'flutter', <String>['build', 'apk'],
            workingDir: example);
        if (exitCode != 0) {
          failingPackages.add('$packageName (apk)');
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
