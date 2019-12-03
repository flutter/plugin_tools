// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:file/file.dart';
import 'package:path/path.dart' as p;
import 'package:platform/platform.dart';

import 'common.dart';

/// Lint the CocoaPod podspecs, run the static analyzer on iOS/macOS plugin
/// platform code, and run unit tests.
///
/// See https://guides.cocoapods.org/terminal/commands.html#pod_lib_lint.
class LintPodspecsCommand extends PluginCommand {
  LintPodspecsCommand(Directory packagesDir,
      FileSystem fileSystem, {
        ProcessRunner processRunner = const ProcessRunner(),
        this.platform = const LocalPlatform(),
      }) : super(packagesDir, fileSystem, processRunner: processRunner);

  @override
  final String name = 'podspecs';

  @override
  List<String> get aliases => <String>['podspec'];

  @override
  final String description = 'Runs "pod lib lint" on all iOS and macOS plugin podspecs.\n\n'
      'This command requires "pod" and "flutter" to be in your path. Runs on macOS only.';

  final Platform platform;

  @override
  Future<Null> run() async {
    if (!platform.isMacOS) {
      print('Detected platform is not macOS, skipping podspec lint');
      return;
    }

    checkSharding();

    await processRunner.runAndExitOnError(
        'which',
        <String>['pod'],
        workingDir: packagesDir
    );

    print('Starting podspec lint test');

    final List<String> failingPlugins = <String>[];
    for (File podspec in await _podspecsToLint()) {
      if (!await _lintPodspec(podspec)) {
        failingPlugins.add(p.basenameWithoutExtension(podspec.path));
      }
    }

    print('\n\n');
    if (failingPlugins.isNotEmpty) {
      print('The following plugins have podspec errors (see above):');
      failingPlugins.forEach((String plugin) {
        print(' * $plugin');
      });
      throw new ToolExit(1);
    }
  }

  Future<List<File>> _podspecsToLint() async {
    // Skip placeholder podspecs for plugins that do not have iOS platform code.
    const List<String> skippedPodspecs = <String>[
      'url_launcher_web',
      'google_sign_in_web'
    ];

    final List<File> podspecs = await getFiles().where((File entity) {
      final String filePath = entity.path;
      return p.extension(filePath) == '.podspec' &&
          !skippedPodspecs.contains(p.basenameWithoutExtension(filePath));
    }).toList();

    podspecs.sort((File a, File b) => p.basename(a.path).compareTo(p.basename(b.path)));
    return podspecs;
  }

  Future<bool> _lintPodspec(File podspec) async {
    // Do not run the static analyzer on plugins with known analyzer issues.
    const List<String> knownAnalyzerIssuePodspecs = <String>['camera'];
    final String podspecPath = podspec.path;
    final bool runAnalyzer = !knownAnalyzerIssuePodspecs.contains(p.basenameWithoutExtension(podspecPath));

    final String podspecBasename = p.basename(podspecPath);
    if (runAnalyzer) {
      print('Linting and analyzing $podspecBasename');
    } else {
      print('Linting $podspecBasename');
    }

    // Lint two at a time.
    final Iterable<bool> statuses = await Future.wait(<Future<bool>>[
      // Lint plugin as framework (use_frameworks!).
      _runPodLint(podspecPath, runAnalyzer, true),

      // Lint plugin as library.
      _runPodLint(podspecPath, runAnalyzer, false)
    ]);

    return !statuses.contains(false);
  }

  Future<bool> _runPodLint(String podspecPath, bool runAnalyzer, bool libraryLint) async {
    final List<String> arguments = <String>[
      'lib',
      'lint',
      podspecPath,
      '--allow-warnings',
      '--fail-fast',
      '--silent',
      if (runAnalyzer) '--analyze',
      if (libraryLint) '--use-libraries'
    ];

    final Process process = await processRunner.start(
        'pod',
        arguments,
        workingDirectory: packagesDir
    );

    if (await process.exitCode != 0) {
      final String lintType = libraryLint ? 'library' : 'framework';
      String command = 'pod lib lint $podspecPath --analyze --allow-warnings --no-clean';
      if (libraryLint) {
        command += ' --use-libraries';
      }
      stderr.writeln('${p.basename(podspecPath)} has $lintType issues. Run "$command" to inspect.');
      return false;
    }

    return true;
  }
}
