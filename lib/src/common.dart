// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

/// Error thrown when a command needs to exit with a non-zero exit code.
class ToolExit extends Error {
  ToolExit(this.exitCode);

  final int exitCode;
}

abstract class PluginCommand extends Command<Null> {
  static const String _pluginsArg = 'plugins';
  final Directory packagesDir;

  PluginCommand(this.packagesDir) {
    argParser.addOption(_pluginsArg,
        allowMultiple: true, splitCommas: true, help: 'Specifies which plugins the command should run on.',);
  }

  List<FileSystemEntity> getPluginFiles({bool recursive: false}) {
    final List<String> packages = argResults[_pluginsArg];
    if (packages.isEmpty) {
      return packagesDir.listSync(recursive: recursive);
    } else {
      final List<Directory> filteredPackages = packagesDir.listSync().where(
          (FileSystemEntity entity) =>
              entity is Directory &&
              packages.contains(p.basename(entity.path)));
      if (recursive) {
        final List<FileSystemEntity> allFiles = <FileSystemEntity>[];
        for (Directory directory in filteredPackages) {
          allFiles.addAll(directory.listSync(recursive: true));
        }
        return allFiles;
      } else {
        return filteredPackages;
      }
    }
  }
}

Future<int> runAndStream(
    String executable, List<String> args, Directory workingDir) async {
  final Process process =
      await Process.start(executable, args, workingDirectory: workingDir.path);
  stdout.addStream(process.stdout);
  stderr.addStream(process.stderr);
  return process.exitCode;
}
