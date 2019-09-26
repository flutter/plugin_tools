// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io' as io;

import 'package:args/command_runner.dart';
import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:path/path.dart' as p;

import 'analyze_command.dart';
import 'build_examples_command.dart';
import 'common.dart';
import 'create_all_plugins_app_command.dart';
import 'drive_examples_command.dart';
import 'firebase_test_lab_command.dart';
import 'format_command.dart';
import 'java_test_command.dart';
import 'list_command.dart';
import 'test_command.dart';
import 'version_check_command.dart';

void main(List<String> args) {
  final FileSystem fileSystem = const LocalFileSystem();

  Directory packagesDir = fileSystem
      .directory(p.join(fileSystem.currentDirectory.path, 'packages'));

  if (!packagesDir.existsSync()) {
    if (p.basename(fileSystem.currentDirectory.path) == 'packages') {
      packagesDir = fileSystem.currentDirectory;
    } else {
      print('Error: Cannot find a "packages" sub-directory');
      io.exit(1);
    }
  }

  final CommandRunner<Null> commandRunner = new CommandRunner<Null>(
      'pub global run flutter_plugin_tools',
      'Productivity utils for hosting multiple plugins within one repository.')
    ..addCommand(new TestCommand(packagesDir, fileSystem))
    ..addCommand(new AnalyzeCommand(packagesDir, fileSystem))
    ..addCommand(new FormatCommand(packagesDir, fileSystem))
    ..addCommand(new BuildExamplesCommand(packagesDir, fileSystem))
    ..addCommand(new DriveExamplesCommand(packagesDir, fileSystem))
    ..addCommand(new FirebaseTestLabCommand(packagesDir, fileSystem))
    ..addCommand(new JavaTestCommand(packagesDir, fileSystem))
    ..addCommand(new ListCommand(packagesDir, fileSystem))
    ..addCommand(new VersionCheckCommand(packagesDir, fileSystem))
    ..addCommand(new CreateAllPluginsAppCommand(packagesDir, fileSystem));

  commandRunner.run(args).catchError((Object e) {
    final ToolExit toolExit = e;
    io.exit(toolExit.exitCode);
  }, test: (Object e) => e is ToolExit);
}
