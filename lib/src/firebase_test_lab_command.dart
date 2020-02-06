// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:io' as io;

import 'package:file/file.dart';
import 'package:path/path.dart' as p;

import 'common.dart';

class FirebaseTestLabCommand extends PluginCommand {
  FirebaseTestLabCommand(
    Directory packagesDir,
    FileSystem fileSystem, {
    ProcessRunner processRunner = const ProcessRunner(),
  }) : super(packagesDir, fileSystem, processRunner: processRunner) {
    argParser.addOption(
      'project',
      defaultsTo: 'flutter-infra',
      help: 'The Firebase project name.',
    );
    argParser.addOption('service-key',
        defaultsTo:
            p.join(io.Platform.environment['HOME'], 'gcloud-service-key.json'));
    argParser.addMultiOption('device',
        splitCommas: false,
        defaultsTo: <String>[
          'model=walleye,version=26',
          'model=flame,version=29'
        ],
        help:
            'Device model(s) to test. See https://cloud.google.com/sdk/gcloud/reference/firebase/test/android/run for more info');
    argParser.addOption('results-bucket',
        defaultsTo: 'gs://flutter_firebase_testlab');
  }

  @override
  final String name = 'firebase-test-lab';

  @override
  final String description = 'Runs the instrumentation tests of the example '
      'apps on Firebase Test Lab.\n\n'
      'Runs tests in test_instrumentation folder using the '
      'instrumentation_test package.';

  static const String _gradleWrapper = 'gradlew';

  Future<void> _configureFirebaseProject() async {
    int exitCode = await processRunner.runAndStream('gcloud', <String>[
      'auth',
      'activate-service-account',
      '--key-file=${argResults['service-key']}',
    ]);

    if (exitCode != 0) {
      throw ToolExit(1);
    }

    exitCode = await processRunner.runAndStream('gcloud', <String>[
      '--quiet',
      'config',
      'set',
      'project',
      argResults['project'],
    ]);

    if (exitCode != 0) {
      throw ToolExit(1);
    }
  }

  @override
  Future<Null> run() async {
    checkSharding();
    final Stream<Directory> packagesWithTests = getPackages().where(
        (Directory d) =>
            isFlutterPackage(d, fileSystem) &&
            fileSystem
                .directory(p.join(
                    d.path, 'example', 'android', 'app', 'src', 'androidTest'))
                .existsSync());

    final List<String> failingPackages = <String>[];
    final List<String> missingFlutterBuild = <String>[];
    await for (Directory package in packagesWithTests) {
      // See https://github.com/flutter/flutter/issues/38983

      final Directory exampleDirectory =
          fileSystem.directory(p.join(package.path, 'example'));
      final String packageName =
          p.relative(package.path, from: packagesDir.path);
      print('\nRUNNING FIREBASE TEST LAB TESTS for $packageName');

      final Directory androidDirectory =
          fileSystem.directory(p.join(exampleDirectory.path, 'android'));

      // Ensures that gradle wrapper exists
      if (!fileSystem
          .file(p.join(androidDirectory.path, _gradleWrapper))
          .existsSync()) {
        final int exitCode = await processRunner.runAndStream(
            'flutter',
            <String>[
              'build',
              'apk',
            ],
            workingDir: androidDirectory);

        if (exitCode != 0) {
          failingPackages.add(packageName);
          continue;
        }
        continue;
      }

      await _configureFirebaseProject();

      int exitCode = await processRunner.runAndStream(
          p.join(androidDirectory.path, _gradleWrapper),
          <String>[
            'app:assembleAndroidTest',
            '-Pverbose=true',
          ],
          workingDir: androidDirectory);

      if (exitCode != 0) {
        failingPackages.add(packageName);
        continue;
      }

      // Look for tests recursively in folders that start with 'test' and that
      // live in the root or example folders.
      bool isTestDir(FileSystemEntity dir) {
        return p.basename(dir.path).startsWith('test');
      }

      final List<FileSystemEntity> testDirs =
          package.listSync().where(isTestDir).toList();
      final Directory example =
          fileSystem.directory(p.join(package.path, 'example'));
      testDirs.addAll(example.listSync().where(isTestDir).toList());
      for (Directory testDir in testDirs) {
        bool isE2ETest(FileSystemEntity file) {
          return file.path.endsWith('_e2e.dart');
        }

        final List<FileSystemEntity> testFiles = testDir
            .listSync(recursive: true, followLinks: true)
            .where(isE2ETest)
            .toList();
        for (FileSystemEntity test in testFiles) {
          exitCode = await processRunner.runAndStream(
              p.join(androidDirectory.path, _gradleWrapper),
              <String>[
                'app:assembleDebug',
                '-Pverbose=true',
                '-Ptarget=${test.path}'
              ],
              workingDir: androidDirectory);

          if (exitCode != 0) {
            failingPackages.add(packageName);
            continue;
          }
          final String buildId = io.Platform.environment['CIRRUS_BUILD_ID'];
          final String resultsDir = 'plugins_android_test/$packageName/$buildId';
          final List<String> args = <String>[
            'firebase',
            'test',
            'android',
            'run',
            '--type',
            'instrumentation',
            '--app',
            'build/app/outputs/apk/debug/app-debug.apk',
            '--test',
            'build/app/outputs/apk/androidTest/debug/app-debug-androidTest.apk',
            '--timeout',
            '5m',
            '--results-bucket=${argResults['results-bucket']}',
            '--results-dir=${resultsDir}',
          ];
          for (String device in argResults['device']) {
            args.addAll(<String>['--device', device]);
          }
          exitCode = await processRunner.runAndStream('gcloud', args,
              workingDir: exampleDirectory);

          if (exitCode != 0) {
            failingPackages.add(packageName);
            continue;
          }
        }
      }
    }

    print('\n\n');
    if (failingPackages.isNotEmpty) {
      print(
          'The instrumentation tests for the following packages are failing (see above for'
          'details):');
      for (String package in failingPackages) {
        print(' * $package');
      }
    }
    if (missingFlutterBuild.isNotEmpty) {
      print('Run "pub global run flutter_plugin_tools build-examples --apk" on'
          'the following packages before executing tests again:');
      for (String package in missingFlutterBuild) {
        print(' * $package');
      }
    }

    if (failingPackages.isNotEmpty || missingFlutterBuild.isNotEmpty) {
      throw ToolExit(1);
    }

    print('All Firebase Test Lab tests successful!');
  }
}
