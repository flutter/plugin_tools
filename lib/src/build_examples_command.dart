// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:io' as io;

import 'package:file/file.dart' as fs;
import 'package:path/path.dart' as p;

import 'common.dart';

class BuildExamplesCommand extends PluginCommand {
  BuildExamplesCommand(fs.Directory packagesDir, fs.FileSystem fileSystem)
      : super(packagesDir, fileSystem) {
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
    if (!argResults['ipa'] && !argResults['apk']) {
      print('Neither --apk nor --ipa were specified, so not building '
          'anything.');
      return;
    }

    checkSharding();
    final List<String> failingPackages = <String>[];
    await for (io.Directory example in getExamples()) {
      final String packageName =
          p.relative(example.path, from: packagesDir.path);

      if (argResults['ipa']) {
        print('\nBUILDING IPA for $packageName');
        final int exitCode = await runAndStream(
            'flutter', <String>['build', 'ios', '--no-codesign'],
            workingDir: example);
        if (exitCode != 0) {
          failingPackages.add('$packageName (ipa)');
        }
      }

      if (argResults['apk']) {
        print('\nBUILDING APK for $packageName');
        final int exitCode = await runAndStream(
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
      throw new ToolExit(1);
    }

    print('All builds successful!');
  }
}
