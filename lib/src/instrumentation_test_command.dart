// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'common.dart';

class InstrumentationTestCommand extends PluginCommand {
  InstrumentationTestCommand(Directory packagesDir) : super(packagesDir);

  @override
  final String name = 'instrumentation-test';

  @override
  final String description = 'Runs the instrumentation tests of the example apps.\n\n'
      'Building the apks of the example apps is required before executing this'
      'command.';

  static const String _gradleWrapper = 'gradlew';

  @override
  Future<Null> run() async {
    checkSharding();
    final Stream<Directory> examplesWithTests = getExamples().where(
            (Directory d) =>
        isFlutterPackage(d) &&
            new Directory(p.join(d.path, 'android', 'app', 'src', 'androidTest'))
                .existsSync());

    final List<String> failingPackages = <String>[];
    final List<String> missingFlutterBuild = <String>[];
    await for (Directory example in examplesWithTests) {
      final String packageName =
      p.relative(example.path, from: packagesDir.path);
      print('\nRUNNING INSTRUMENTATION TESTS for $packageName');

      final Directory androidDirectory =
      new Directory(p.join(example.path, 'android'));
      if (!new File(p.join(androidDirectory.path, _gradleWrapper))
          .existsSync()) {
        print('ERROR: Run "flutter build apk" on example app of $packageName'
            'before executing tests.');
        missingFlutterBuild.add(packageName);
        continue;
      }

      final int exitCode = await runAndStream(
          p.join(androidDirectory.path, _gradleWrapper),
          <String>[
            'connectedAndroidTest',
            '-Ptarget=${androidDirectory.path}/../test_live/adapter.dart',
            '-Pverbose=true', '-Ptrack-widget-creation=false',
            '-Pfilesystem-scheme=org-dartlang-root',
          ],
          workingDir: androidDirectory);
      if (exitCode != 0) {
        failingPackages.add(packageName);
        continue;
      }

      // TODO(jackson): Switch to using assembleAndroidTest above and run on Firebase Test Lab
      //    echo $GCLOUD_FIREBASE_TESTLAB_KEY > ${HOME}/gcloud-service-key.json
      //    gcloud auth activate-service-account --key-file=${HOME}/gcloud-service-key.json
      //    gcloud --quiet config set project flutter-infra
      //    gcloud firebase test android run --type instrumentation \
      //    --app build/app/outputs/apk/app.apk \
      //    --test build/app/outputs/apk/androidTest/debug/app-debug-androidTest.apk\
      //    --timeout 2m \
      //    --results-bucket=gs://flutter_firebase_testlab \
      //    --results-dir=engine_android_test/$GIT_REVISION/$CIRRUS_BUILD_ID
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

    print('All instrumentation tests successful!');
  }
}
