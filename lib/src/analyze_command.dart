// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'common.dart';

class AnalyzeCommand extends PluginCommand {
  AnalyzeCommand(Directory packagesDir) : super(packagesDir);

  @override
  final String name = 'analyze';

  @override
  final String description = 'Analyzes all packages using package:tuneup.\n\n'
      'This command requires "pub" and "flutter" to be in your path.';

  @override
  Future<Null> run() async {
    print('Activating tuneup package...');
    await runAndStream('pub', <String>['global', 'activate', 'tuneup'],
        workingDir: packagesDir, exitOnError: true);

    await for (Directory package in _listAllPackages()) {
      await runAndStream('flutter', <String>['packages', 'get'],
          workingDir: package, exitOnError: true);
    }

    final List<String> failingPackages = <String>[];
    await for (Directory package in _listAllPluginPackages()) {
      final int exitCode = await runAndStream(
          'pub', <String>['global', 'run', 'tuneup', 'check'],
          workingDir: package);
      if (exitCode != 0) {
        failingPackages.add(p.basename(package.path));
      }
    }

    print('\n\n');
    if (failingPackages.isNotEmpty) {
      print('The following packages have analyzer errors (see above):');
      failingPackages.forEach((String package) {
        print(' * $package');
      });
      throw new ToolExit(1);
    }

    print('No analyzer errors found!');
  }

  Stream<Directory> _listAllPluginPackages() =>
      getPluginFiles().where((FileSystemEntity entity) =>
          entity is Directory &&
          new File(p.join(entity.path, 'pubspec.yaml')).existsSync());

  Stream<Directory> _listAllPackages() => getPluginFiles()
      .where((FileSystemEntity entity) =>
          entity is File && p.basename(entity.path) == 'pubspec.yaml')
      .map((FileSystemEntity entity) => entity.parent);
}
