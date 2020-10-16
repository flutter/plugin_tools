// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:args/command_runner.dart';
import 'package:file/file.dart';
import 'package:flutter_plugin_tools/src/xctest_command.dart';
import 'package:test/test.dart';
import 'package:flutter_plugin_tools/src/common.dart';

import 'mocks.dart';
import 'util.dart';

void main() {
  group('test xctest_command', () {
    CommandRunner<Null> runner;
    RecordingProcessRunner processRunner;

    setUp(() {
      initializeFakePackages();
      processRunner = RecordingProcessRunner();
      final XCTestCommand command = XCTestCommand(
          mockPackagesDir, mockFileSystem,
          processRunner: processRunner);

      runner = CommandRunner<Null>(
          'xctest_command', 'Test for xctest_command');
      runner.addCommand(command);
      cleanupPackages();
    });

    test('Not specifying ios--destination or scheme throws',
        () async {

      await expectLater(() => runner.run(<String>['xctest','--scheme', 'a_scheme']),
          throwsA(const TypeMatcher<ToolExit>()));

      await expectLater(() => runner.run(<String>['xctest','--ios-destination', 'a_destination']),
          throwsA(const TypeMatcher<ToolExit>()));
    });

    test('skip is ios is not supported', () async {
      createFakePlugin('plugin',
          withExtraFiles: <List<String>>[
            <String>['example', 'test'],
          ], isIosPlugin: false);

      final Directory pluginExampleDirectory =
          mockPackagesDir.childDirectory('plugin').childDirectory('example');

      createFakePubspec(pluginExampleDirectory, isFlutter: true);

      final MockProcess mockProcess = MockProcess();
      mockProcess.exitCodeCompleter.complete(0);
      processRunner.processToReturn = mockProcess;
      final List<String> output = await runCapturingPrint(runner,
          <String>['xctest', '--scheme', 'foo_scheme', '--ios-destination', 'foo_destination']);
      expect(output, contains('iOS is not supported by this plugin.\n'
              '\n'
              ''));
      expect(
        processRunner.recordedCalls,
        orderedEquals(<ProcessCall>[]));

      cleanupPackages();
    });

    test('running with correct scheme and destination, did not find scheme', () async {
      createFakePlugin('plugin',
          withExtraFiles: <List<String>>[
            <String>['example', 'test'],
          ],
          isIosPlugin: true);

      final Directory pluginExampleDirectory =
          mockPackagesDir.childDirectory('plugin').childDirectory('example');

      createFakePubspec(pluginExampleDirectory, isFlutter: true);

      final MockProcess mockProcess = MockProcess();
      mockProcess.exitCodeCompleter.complete(0);
      processRunner.processToReturn = mockProcess;
      processRunner.resultStdout = 'bar_scheme';
      final List<String> output = await runCapturingPrint(runner,
          <String>['xctest', '--scheme', 'foo_scheme', '--ios-destination', 'foo_destination']);

      expect(output, contains('foo_scheme not configured for plugin, skipping.\n'
        '\n'
        ''));

      expect(
        processRunner.recordedCalls,
        orderedEquals(<ProcessCall>[
          ProcessCall('xcodebuild',
            <String>['-project', 'ios/Runner.xcodeproj', '-list', '-json'],
              pluginExampleDirectory.path),
        ]));

      cleanupPackages();
    });

    test('running with correct scheme and destination, found scheme', () async {
      createFakePlugin('plugin',
          withExtraFiles: <List<String>>[
            <String>['example', 'test'],
          ],
          isIosPlugin: true);

      final Directory pluginExampleDirectory =
          mockPackagesDir.childDirectory('plugin').childDirectory('example');

      createFakePubspec(pluginExampleDirectory, isFlutter: true);

      final MockProcess mockProcess = MockProcess();
      mockProcess.exitCodeCompleter.complete(0);
      processRunner.processToReturn = mockProcess;
      processRunner.resultStdout = 'foo_scheme, bar_scheme';
      await runner.run(
          <String>['xctest', '--scheme', 'foo_scheme', '--ios-destination', 'foo_destination']);

      expect(
        processRunner.recordedCalls,
        orderedEquals(<ProcessCall>[
          ProcessCall('xcodebuild',
            <String>['-project', 'ios/Runner.xcodeproj', '-list', '-json'],
              pluginExampleDirectory.path),
          ProcessCall('xcodebuild', <String>['test', '-project', 'ios/Runner.xcodeproj', '-scheme', 'foo_scheme', '-destination', 'foo_destination', 'CODE_SIGN_IDENTITY=""', 'CODE_SIGNING_REQUIRED=NO'],
              pluginExampleDirectory.path),
        ]));

      cleanupPackages();
    });
  });
}
