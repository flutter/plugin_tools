// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import 'common.dart';

const String _googleFormatterUrl =
    'https://github.com/google/google-java-format/releases/download/google-java-format-1.3/google-java-format-1.3-all-deps.jar';

class FormatCommand extends PluginCommand {
  FormatCommand(Directory packagesDir) : super(packagesDir) {
    argParser.addFlag('travis', hide: true);
    argParser.addOption('clang-format',
        defaultsTo: 'clang-format',
        help: 'Path to executable of clang-format v5.');
  }

  @override
  final String name = 'format';

  @override
  final String description =
      'Formats the code of all packages (Java, Objective-C, and Dart).\n\n'
      'This command requires "git", "flutter" and "clang-format" v5 to be in '
      'your path.';

  @override
  Future<Null> run() async {
    final String googleFormatterPath = await _getGoogleFormatterPath();

    await _formatDart();
    await _formatJava(googleFormatterPath);
    await _formatObjectiveC();

    if (argResults['travis']) {
      final bool modified = await _didModifyAnything();
      if (modified) {
        throw new ToolExit(1);
      }
    }
  }

  Future<bool> _didModifyAnything() async {
    final ProcessResult modifiedFiles = await runAndExitOnError(
        'git', <String>['ls-files', '--modified'],
        workingDir: packagesDir);

    print('\n\n');

    if (modifiedFiles.stdout.isEmpty) {
      print('All files formatted correctly.');
      return false;
    }

    final ProcessResult diff = await runAndExitOnError(
        'git', <String>['diff', '--color'],
        workingDir: packagesDir);
    print(diff.stdout);

    print('These files are not formatted correctly (see diff above):');
    LineSplitter
        .split(modifiedFiles.stdout)
        .map((String line) => '  $line')
        .forEach(print);
    print('\nTo fix run "pub global activate flutter_plugin_tools && '
        'pub global run flutter_plugin_tools format".');

    return true;
  }

  Future<Null> _formatObjectiveC() async {
    print('Formatting all .m and .h files...');
    final Iterable<String> hFiles = await _getFilesWithExtension('.h');
    final Iterable<String> mFiles = await _getFilesWithExtension('.m');
    await runAndStream(argResults['clang-format'],
        <String>['-i', '--style=Google']..addAll(hFiles)..addAll(mFiles),
        workingDir: packagesDir, exitOnError: true);
  }

  Future<Null> _formatJava(String googleFormatterPath) async {
    print('Formatting all .java files...');
    final Iterable<String> javaFiles = await _getFilesWithExtension('.java');
    await runAndStream('java',
        <String>['-jar', googleFormatterPath, '--replace']..addAll(javaFiles),
        workingDir: packagesDir, exitOnError: true);
  }

  Future<Null> _formatDart() async {
    print('Formatting all .dart files...');
    final Iterable<String> dartFiles = await _getFilesWithExtension('.dart');
    await runAndStream('flutter', <String>['format']..addAll(dartFiles),
        workingDir: packagesDir, exitOnError: true);
  }

  Future<List<String>> _getFilesWithExtension(String extension) async =>
      getPluginFiles(recursive: true)
          .where((FileSystemEntity entity) =>
              entity is File && p.extension(entity.path) == extension)
          .map((FileSystemEntity entity) => entity.path)
          .toList();

  Future<String> _getGoogleFormatterPath() async {
    final String javaFormatterPath = p.join(
        p.dirname(p.fromUri(Platform.script)),
        'google-java-format-1.3-all-deps.jar');
    final File javaFormatterFile = new File(javaFormatterPath);

    if (!javaFormatterFile.existsSync()) {
      print('Downloading Google Java Format...');
      final http.Response response = await http.get(_googleFormatterUrl);
      javaFormatterFile.writeAsBytesSync(response.bodyBytes);
    }

    return javaFormatterPath;
  }
}
