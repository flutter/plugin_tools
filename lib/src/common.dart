// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:io' as io;
import 'dart:math';

import 'package:args/command_runner.dart';
import 'package:file/file.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// Returns whether the given directory contains a Flutter package.
bool isFlutterPackage(FileSystemEntity entity, FileSystem fileSystem) {
  if (entity == null || entity is! Directory) {
    return false;
  }

  try {
    final File pubspecFile =
        fileSystem.file(p.join(entity.path, 'pubspec.yaml'));
    final YamlMap pubspecYaml = loadYaml(pubspecFile.readAsStringSync());
    final YamlMap dependencies = pubspecYaml['dependencies'];
    if (dependencies == null) {
      return false;
    }
    return dependencies.containsKey('flutter');
  } on FileSystemException {
    return false;
  } on YamlException {
    return false;
  }
}

/// Error thrown when a command needs to exit with a non-zero exit code.
class ToolExit extends Error {
  ToolExit(this.exitCode);

  final int exitCode;
}

abstract class PluginCommand extends Command<Null> {
  PluginCommand(this.packagesDir, this.fileSystem) {
    argParser.addMultiOption(
      _pluginsArg,
      splitCommas: true,
      help:
          'Specifies which plugins the command should run on (before sharding).',
      valueHelp: 'plugin1,plugin2,...',
    );
    argParser.addOption(
      _shardIndexArg,
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

  static const String _pluginsArg = 'plugins';
  static const String _shardIndexArg = 'shardIndex';
  static const String _shardCountArg = 'shardCount';

  /// The directory containing the plugin packages.
  final Directory packagesDir;

  /// The file system.
  ///
  /// This can be overridden for testing.
  final FileSystem fileSystem;

  int _shardIndex;
  int _shardCount;

  int get shardIndex {
    if (_shardIndex == null) {
      checkSharding();
    }
    return _shardIndex;
  }

  int get shardCount {
    if (_shardCount == null) {
      checkSharding();
    }
    return _shardCount;
  }

  void checkSharding() {
    final int shardIndex = int.tryParse(argResults[_shardIndexArg]);
    final int shardCount = int.tryParse(argResults[_shardCountArg]);
    if (shardIndex == null) {
      usageException('$_shardIndexArg must be an integer');
    }
    if (shardCount == null) {
      usageException('$_shardCountArg must be an integer');
    }
    if (shardCount < 1) {
      usageException('$_shardCountArg must be positive');
    }
    if (shardIndex < 0 || shardCount <= shardIndex) {
      usageException(
          '$_shardIndexArg must be in the half-open range [0..$shardCount[');
    }
    _shardIndex = shardIndex;
    _shardCount = shardCount;
  }

  /// Returns the root Dart package folders of the plugins involved in this
  /// command execution.
  Stream<Directory> getPlugins() async* {
    // To avoid assuming consistency of `Directory.list` across command
    // invocations, we collect and sort the plugin folders before sharding.
    // This is considered an implementation detail which is why the API still
    // uses streams.
    final List<Directory> allPlugins = await _getAllPlugins().toList();
    allPlugins.sort((Directory d1, Directory d2) => d1.path.compareTo(d2.path));
    // Sharding 10 elements into 3 shards should yield shard sizes 4, 4, 2.
    // Sharding  9 elements into 3 shards should yield shard sizes 3, 3, 3.
    // Sharding  2 elements into 3 shards should yield shard sizes 1, 1, 0.
    final int shardSize = allPlugins.length ~/ shardCount +
        (allPlugins.length % shardCount == 0 ? 0 : 1);
    final int start = min(shardIndex * shardSize, allPlugins.length);
    final int end = min(start + shardSize, allPlugins.length);
    for (Directory plugin in allPlugins.sublist(start, end)) {
      yield plugin;
    }
  }

  /// Returns the root Dart package folders of the plugins involved in this
  /// command execution, assuming there is only one shard.
  ///
  /// Plugin packages can exist in one of two places relative to the packages
  /// directory.
  ///
  /// 1. As a Dart package in a directory which is a direct child of the
  ///    packages directory. This is a plugin where all of the implementations
  ///    exist in a single Dart package.
  /// 2. Several plugin packages may live in a directory which is a direct
  ///    child of the packages directory. This directory groups several Dart
  ///    packages which implement a single plugin. This directory contains a
  ///    "client library" package, which declares the API for the plugin, as
  ///    well as one or more platform-specific implementations.
  Stream<Directory> _getAllPlugins() async* {
    final Set<String> packages = new Set<String>.from(argResults[_pluginsArg]);
    await for (FileSystemEntity entity
        in packagesDir.list(followLinks: false)) {
      // A top-level Dart package is a plugin package.
      if (_isDartPackage(entity)) {
        if (packages.isEmpty || packages.contains(p.basename(entity.path))) {
          yield entity;
        }
      } else if (entity is Directory) {
        // Look for Dart packages under this top-level directory.
        await for (FileSystemEntity subdir in entity.list(followLinks: false)) {
          if (_isDartPackage(subdir)) {
            if (packages.isEmpty ||
                packages.contains(p.basename(subdir.path))) {
              yield subdir;
            }
          }
        }
      }
    }
  }

  /// Returns the example Dart package folders of the plugins involved in this
  /// command execution.
  Stream<Directory> getExamples() =>
      getPlugins().expand<Directory>(_getExamplesForPlugin);

  /// Returns all Dart package folders (typically, plugin + example) of the
  /// plugins involved in this command execution.
  Stream<Directory> getPackages() async* {
    await for (Directory plugin in getPlugins()) {
      yield plugin;
      yield* plugin
          .list(recursive: true, followLinks: false)
          .where(_isDartPackage)
          .cast<Directory>();
    }
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
        fileSystem.file(p.join(entity.path, 'pubspec.yaml')).existsSync();
  }

  /// Returns the example Dart packages contained in the specified plugin, or
  /// an empty List, if the plugin has no examples.
  Iterable<Directory> _getExamplesForPlugin(Directory plugin) {
    final Directory exampleFolder =
        fileSystem.directory(p.join(plugin.path, 'example'));
    if (!exampleFolder.existsSync()) {
      return <Directory>[];
    }
    if (isFlutterPackage(exampleFolder, fileSystem)) {
      return <Directory>[exampleFolder];
    }
    // Only look at the subdirectories of the example directory if the example
    // directory itself is not a Dart package, and only look one level below the
    // example directory for other dart packages.
    return exampleFolder
        .listSync()
        .where(
            (FileSystemEntity entity) => isFlutterPackage(entity, fileSystem))
        .cast<Directory>();
  }
}

Future<int> runAndStream(String executable, List<String> args,
    {Directory workingDir, bool exitOnError: false}) async {
  final io.Process process = await io.Process.start(executable, args,
      workingDirectory: workingDir?.path);
  io.stdout.addStream(process.stdout);
  io.stderr.addStream(process.stderr);
  if (exitOnError && await process.exitCode != 0) {
    final String error =
        _getErrorString(executable, args, workingDir: workingDir);
    print('$error See above for details.');
    throw new ToolExit(await process.exitCode);
  }
  return process.exitCode;
}

Future<io.ProcessResult> runAndExitOnError(String executable, List<String> args,
    {Directory workingDir, bool exitOnError: false}) async {
  final io.ProcessResult result = await io.Process.run(executable, args,
      workingDirectory: workingDir?.path);
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
