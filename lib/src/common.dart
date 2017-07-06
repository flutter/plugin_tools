// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import 'package:async/async.dart';

/// Error thrown when a command needs to exit with a non-zero exit code.
class ToolExit extends Error {
  ToolExit(this.exitCode);

  final int exitCode;
}

abstract class PluginCommand extends Command<Null> {
  static const String _pluginsArg = 'plugins';
  final Directory packagesDir;

  PluginCommand(this.packagesDir) {
    argParser.addOption(
      _pluginsArg,
      allowMultiple: true,
      splitCommas: true,
      help: 'Specifies which plugins the command should run on.',
      valueHelp: 'plugin1,plugin2,...',
    );
  }

  Stream<FileSystemEntity> getPluginFiles({bool recursive: false}) {
    final List<String> packages = argResults[_pluginsArg];
    if (packages.isEmpty) {
      return packagesDir.list(recursive: recursive);
    } else {
      final List<Directory> filteredPackages = packagesDir.listSync().where(
          (FileSystemEntity entity) =>
              entity is Directory &&
              packages.contains(p.basename(entity.path)));
      if (recursive) {
        final List<Stream<FileSystemEntity>> streams =
            <Stream<FileSystemEntity>>[];
        for (Directory directory in filteredPackages) {
          streams.add(directory.list(recursive: true));
        }
        return StreamGroup.merge(streams);
      } else {
        return new Stream<FileSystemEntity>.fromIterable(filteredPackages);
      }
    }
  }
}

Future<int> runAndStream(String executable, List<String> args,
    {Directory workingDir, bool exitOnError: false}) async {
  final Process process =
      await Process.start(executable, args, workingDirectory: workingDir?.path);
  stdout.addStream(process.stdout);
  stderr.addStream(process.stderr);
  if (exitOnError && await process.exitCode != 0) {
    final String error =
        _getErrorString(executable, args, workingDir: workingDir);
    print('$error See above for details.');
    throw new ToolExit(await process.exitCode);
  }
  return process.exitCode;
}

Future<ProcessResult> runAndExitOnError(String executable, List<String> args,
    {Directory workingDir, bool exitOnError: false}) async {
  final ProcessResult result =
      await Process.run(executable, args, workingDirectory: workingDir?.path);
  if (result.exitCode != 0) {
    final String error =
        _getErrorString(executable, args, workingDir: workingDir);
    print('$error Stderr:\n${result.stdout}');
    throw new ToolExit(result.exitCode);
  }
  return result;
}

String _getErrorString(String executable, List<String> args,
    {Directory workingDir}) {
  final String workdir = workingDir == null ? '' : ' in ${workingDir.path}';
  return 'ERROR: Unable to execute "$executable ${args.join(' ')}"$workdir.';
}
