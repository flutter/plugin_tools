// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'common.dart';

class FirebaseTestLabCommand extends PluginCommand {
  FirebaseTestLabCommand(Directory packagesDir) : super(packagesDir) {
    argParser.addOption('project', defaultsTo: 'flutter-infra');
    argParser.addOption('service-key',
        defaultsTo:
            p.join(Platform.environment['HOME'], 'gcloud-service-key.json'));
    argParser.addOption('results-bucket',
        defaultsTo: 'gs://flutter_firebase_testlab');
    final String gitRevision = Platform.environment['GIT_REVISION'];
    final String buildId = Platform.environment['CIRRUS_BUILD_ID'];
    argParser.addOption('results-dir',
        defaultsTo: 'plugins_android_test/$gitRevision/$buildId');
  }

  @override
  final String name = 'firebase-test-lab';

  @override
  final String description = 'Runs the instrumentation tests of the example '
      'apps on Firebase Test Lab.\n\n'
      'Runs tests in test_instrumentation folder using the '
      'instrumentation_test package.';

  static const String _gradleWrapper = 'gradlew';

  @override
  Future<Null> run() async {
    checkSharding();
    final Stream<Directory> examplesWithTests = getExamples().where((Directory
            d) =>
        isFlutterPackage(d) &&
        new Directory(p.join(d.path, 'android', 'app', 'src', 'androidTest'))
            .existsSync());

    final List<String> failingPackages = <String>[];
    final List<String> missingFlutterBuild = <String>[];
    await for (Directory example in examplesWithTests) {
      // TODO(jackson): We should also support testing lib/main.dart
      final Directory testsDir =
          Directory(p.join(example.path, 'test_instrumentation'));
      if (!testsDir.existsSync()) continue;

      final String packageName =
          p.relative(example.path, from: packagesDir.path);
      print('\nRUNNING FIREBASE TEST LAB TESTS for $packageName');

      final Directory androidDirectory =
          new Directory(p.join(example.path, 'android'));
      if (!new File(p.join(androidDirectory.path, _gradleWrapper))
          .existsSync()) {
        print('ERROR: Run "flutter build apk" on example app of $packageName'
            'before executing tests.');
        missingFlutterBuild.add(packageName);
        continue;
      }

      int exitCode = await runAndStream(
          'gcloud',
          <String>[
            'auth',
            'activate-service-account',
            '--key-file=${argResults['service-key']}',
          ],
          workingDir: example);

      if (exitCode != 0) {
        failingPackages.add(packageName);
        continue;
      }

      exitCode = await runAndStream(
          'gcloud',
          <String>[
            '--quiet',
            'config',
            'set',
            'project',
            argResults['project'],
          ],
          workingDir: example);

      if (exitCode != 0) {
        failingPackages.add(packageName);
        continue;
      }

      exitCode = await runAndStream(
          p.join(androidDirectory.path, _gradleWrapper),
          <String>[
            'assembleAndroidTest',
            '-Pverbose=true',
            '-Ptrack-widget-creation=false',
            '-Pfilesystem-scheme=org-dartlang-root',
          ],
          workingDir: androidDirectory);

      if (exitCode != 0) {
        failingPackages.add(packageName);
        continue;
      }

      for (File test in testsDir.listSync()) {
        exitCode = await runAndStream(
            p.join(androidDirectory.path, _gradleWrapper),
            <String>[
              'assembleDebug',
              '-Pverbose=true',
              '-Ptrack-widget-creation=false',
              '-Pfilesystem-scheme=org-dartlang-root',
              '-Ptarget=${test.path}'
            ],
            workingDir: androidDirectory);

        if (exitCode != 0) {
          failingPackages.add(packageName);
          continue;
        }

        exitCode = await runAndStream(
            'gcloud',
            <String>[
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
              '2m',
              '--results-bucket=${argResults['results-bucket']}',
              '--results-dir=${argResults['results-dir']}',
            ],
            workingDir: example);

        if (exitCode != 0) {
          failingPackages.add(packageName);
          continue;
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
      throw new ToolExit(1);
    }

    print('All Firebase Test Lab tests successful!');
  }
}
