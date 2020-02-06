import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:flutter_plugin_tools/src/firebase_test_lab_command.dart';
import 'package:test/test.dart';

import 'util.dart';

void main() {
  group('$FirebaseTestLabCommand', () {
    CommandRunner<FirebaseTestLabCommand> runner;
    RecordingProcessRunner processRunner;

    setUp(() {
      initializeFakePackages();
      processRunner = RecordingProcessRunner();
      final FirebaseTestLabCommand command = FirebaseTestLabCommand(
          mockPackagesDir, mockFileSystem,
          processRunner: processRunner);

      runner = CommandRunner<Null>(
          'firebase_test_lab_command', 'Test for $FirebaseTestLabCommand');
      runner.addCommand(command);
    });

    test('runs e2e tests', () async {
      createFakePlugin('plugin', withExtraFiles: <List<String>>[
        <String>['test', 'plugin_test.dart'],
        <String>['test', 'plugin_e2e.dart'],
        <String>['should_not_run_e2e.dart'],
        <String>['lib/test/should_not_run_e2e.dart'],
        <String>['example', 'test', 'plugin_e2e.dart'],
        <String>['example', 'test_driver', 'plugin_e2e.dart'],
        <String>['example', 'test_driver', 'plugin_e2e_test.dart'],
        <String>['example', 'android', 'gradlew'],
        <String>['example', 'should_not_run_e2e.dart'],
        <String>[
          'example',
          'android',
          'app',
          'src',
          'androidTest',
          'MainActivityTest.java'
        ],
      ]);

      final List<String> output = await runCapturingPrint(runner, <String>[
        'firebase-test-lab',
        '--device',
        'model=flame,version=29',
        '--device',
        'model=seoul,version=26',
      ]);

      expect(
        output,
        orderedEquals(<String>[
          '\nRUNNING FIREBASE TEST LAB TESTS for plugin',
          '\n\n',
          'All Firebase Test Lab tests successful!',
        ]),
      );

      expect(
        processRunner.recordedCalls,
        orderedEquals(<ProcessCall>[
          ProcessCall(
              'gcloud',
              'auth activate-service-account --key-file=${Platform.environment['HOME']}/gcloud-service-key.json'
                  .split(' '),
              null),
          ProcessCall('gcloud',
              '--quiet config set project flutter-infra'.split(' '), null),
          ProcessCall(
              '/packages/plugin/example/android/gradlew',
              'app:assembleAndroidTest -Pverbose=true'.split(' '),
              '/packages/plugin/example/android'),
          ProcessCall(
              '/packages/plugin/example/android/gradlew',
              'app:assembleDebug -Pverbose=true -Ptarget=/packages/plugin/test/plugin_e2e.dart'
                  .split(' '),
              '/packages/plugin/example/android'),
          ProcessCall(
              'gcloud',
              'firebase test android run --type instrumentation --app build/app/outputs/apk/debug/app-debug.apk --test build/app/outputs/apk/androidTest/debug/app-debug-androidTest.apk --timeout 5m --results-bucket=gs://flutter_firebase_testlab --results-dir=plugins_android_test/plugin/null --device model=flame,version=29 --device model=seoul,version=26'
                  .split(' '),
              '/packages/plugin/example'),
          ProcessCall(
              '/packages/plugin/example/android/gradlew',
              'app:assembleDebug -Pverbose=true -Ptarget=/packages/plugin/example/test/plugin_e2e.dart'
                  .split(' '),
              '/packages/plugin/example/android'),
          ProcessCall(
              'gcloud',
              'firebase test android run --type instrumentation --app build/app/outputs/apk/debug/app-debug.apk --test build/app/outputs/apk/androidTest/debug/app-debug-androidTest.apk --timeout 5m --results-bucket=gs://flutter_firebase_testlab --results-dir=plugins_android_test/plugin/null --device model=flame,version=29 --device model=seoul,version=26'
                  .split(' '),
              '/packages/plugin/example'),
          ProcessCall(
              '/packages/plugin/example/android/gradlew',
              'app:assembleDebug -Pverbose=true -Ptarget=/packages/plugin/example/test_driver/plugin_e2e.dart'
                  .split(' '),
              '/packages/plugin/example/android'),
          ProcessCall(
              'gcloud',
              'firebase test android run --type instrumentation --app build/app/outputs/apk/debug/app-debug.apk --test build/app/outputs/apk/androidTest/debug/app-debug-androidTest.apk --timeout 5m --results-bucket=gs://flutter_firebase_testlab --results-dir=plugins_android_test/plugin/null --device model=flame,version=29 --device model=seoul,version=26'
                  .split(' '),
              '/packages/plugin/example'),
        ]),
      );

      cleanupPackages();
    });
  });
}
