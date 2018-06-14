// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import 'analyze_command.dart';
import 'build_examples_command.dart';
import 'common.dart';
import 'format_command.dart';
import 'java_test_command.dart';
import 'list_command.dart';
import 'test_command.dart';

void main(List<String> args) {
  Directory packagesDir =
      new Directory(p.join(Directory.current.path, 'packages'));

  if (!packagesDir.existsSync()) {
    if (p.basename(Directory.current.path) == 'packages') {
      packagesDir = Directory.current;
    } else {
      print('Error: Cannot find a "packages" sub-directory');
      exit(1);
    }
  }

  final CommandRunner<Null> commandRunner = new CommandRunner<Null>(
      'pub global run flutter_plugin_tools',
      'Productivity utils for hosting multiple plugins within one repository.')
    ..addCommand(new TestCommand(packagesDir))
    ..addCommand(new AnalyzeCommand(packagesDir))
    ..addCommand(new FormatCommand(packagesDir))
    ..addCommand(new BuildExamplesCommand(packagesDir))
    ..addCommand(new JavaTestCommand(packagesDir))
    ..addCommand(new ListCommand(packagesDir));

  commandRunner.run(args).catchError((ToolExit e) {
    exit(e.exitCode);
  }, test: (Object e) => e is ToolExit);
}
