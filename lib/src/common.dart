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
  static const String _shardArg = 'shard';
  static const String _shardCountArg = 'shardCount';
  final Directory packagesDir;

  PluginCommand(this.packagesDir) {
    argParser.addOption(
      _pluginsArg,
      allowMultiple: true,
      splitCommas: true,
      help: 'Specifies which plugins the command should run on.',
      valueHelp: 'plugin1,plugin2,...',
    );
    argParser.addOption(
      _shardArg,
      help: 'Specifies the zero-based index of the shard to '
          'which the command applies.',
      valueHelp: 'i',
      defaultsTo: '0',
    );
    argParser.addOption(
      _shardCountArg,
      help: 'Specifies the number of shards into which plugins are divided.',
      valueHelp: 'n',
      defaultsTo: '1',
    );
  }

  @override
  FutureOr<Null> run() {
    final int shard = int.tryParse(argResults[_shardArg]);
    final int shardCount = int.tryParse(argResults[_shardCountArg]);
    if (shard == null) {
      usageException('shard must be an integer');
    }
    if (shardCount == null) {
      usageException('shardCount must be an integer');
    }
    if (shardCount < 1) {
      usageException('shardCount must be positive');
    }
    if (shard < 0 || shardCount <= shard) {
      usageException('shard must be in the half-open range [0..$shardCount[');
    }
    return super.run();
  }

  /// Returns the root Dart package folders of the plugins involved in this
  /// command execution.
  Stream<Directory> getPlugins() {
    final int shardCount = int.parse(argResults[_shardCountArg]);
    final int shard = int.parse(argResults[_shardArg]);
    final Set<String> packages = new Set<String>.from(argResults[_pluginsArg]);
    int i = 0;
    return packagesDir
        .list(followLinks: false)
        .where(_isDartPackage)
        .where((FileSystemEntity entity) =>
            packages.isEmpty || packages.contains(p.basename(entity.path)))
        .where((_) => i++ % shardCount == shard)
        .cast<Directory>();
  }

  /// Returns the example Dart package folders of the plugins involved in this
  /// command execution.
  Stream<Directory> getExamples() {
    return getPlugins()
        .map<Directory>(_getExampleForPlugin)
        .where((Directory example) => example != null);
  }

  /// Returns all Dart package folders (typically, plugin + example) of the
  /// plugins involved in this command execution.
  Stream<Directory> getPackages() {
    return getPlugins().asyncExpand<Directory>((Directory folder) => folder
        .list(recursive: true, followLinks: false)
        .where(_isDartPackage)
        .cast<Directory>());
  }

  /// Returns the files contained, recursively, within the plugins
  /// involved in this command execution.
  Stream<File> getFiles() {
    return getPlugins().asyncExpand<File>((Directory folder) => folder
        .list(recursive: true, followLinks: false)
        .where((FileSystemEntity entity) => entity is File)
        .cast<File>());
  }

  /// Returns whether the specified entity is a directory containing a
  /// `pubspec.yaml` file.
  bool _isDartPackage(FileSystemEntity entity) {
    return entity is Directory &&
        new File(p.join(entity.path, 'pubspec.yaml')).existsSync();
  }

  /// Returns the example Dart package contained in the specified plugin, or
  /// null, if the plugin has no example.
  Directory _getExampleForPlugin(Directory plugin) {
    final Directory exampleFolder =
        new Directory(p.join(plugin.path, 'example'));
    return _isDartPackage(exampleFolder) ? exampleFolder : null;
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
