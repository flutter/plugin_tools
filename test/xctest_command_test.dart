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
  const String _kDestination = '--ios-destination';
  const String _kTarget = '--target';
  const String _kSkip = '--skip';

  group('test xctest_command', () {
    CommandRunner<Null> runner;
    RecordingProcessRunner processRunner;

    setUp(() {
      initializeFakePackages();
      processRunner = RecordingProcessRunner();
      final XCTestCommand command = XCTestCommand(
          mockPackagesDir, mockFileSystem,
          processRunner: processRunner);

      runner = CommandRunner<Null>('xctest_command', 'Test for xctest_command');
      runner.addCommand(command);
      cleanupPackages();
    });

    test('Not specifying ios--destination or scheme throws', () async {
      await expectLater(
          () => runner.run(<String>['xctest', _kTarget, 'a_scheme']),
          throwsA(const TypeMatcher<ToolExit>()));

      await expectLater(
          () => runner.run(<String>['xctest', _kDestination, 'a_destination']),
          throwsA(const TypeMatcher<ToolExit>()));
    });

    test('skip if ios is not supported', () async {
      createFakePlugin('plugin',
          withExtraFiles: <List<String>>[
            <String>['example', 'test'],
          ],
          isIosPlugin: false);

      final Directory pluginExampleDirectory =
          mockPackagesDir.childDirectory('plugin').childDirectory('example');

      createFakePubspec(pluginExampleDirectory, isFlutter: true);

      final MockProcess mockProcess = MockProcess();
      mockProcess.exitCodeCompleter.complete(0);
      processRunner.processToReturn = mockProcess;
      final List<String> output = await runCapturingPrint(runner, <String>[
        'xctest',
        _kTarget,
        'foo_scheme',
        _kDestination,
        'foo_destination'
      ]);
      expect(output, contains('iOS is not supported by this plugin.'));
      expect(processRunner.recordedCalls, orderedEquals(<ProcessCall>[]));

      cleanupPackages();
    });

    test('running with correct scheme and destination, did not find scheme',
        () async {
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
      processRunner.resultStdout = '{"project":{"targets":["bar_scheme"]}}';

      await expectLater(() async {
        final List<String> output = await runCapturingPrint(runner, <String>[
          'xctest',
          _kTarget,
          'foo_scheme',
          _kDestination,
          'foo_destination'
        ]);
        expect(output,
            contains('foo_scheme not configured for plugin, test failed.'));
        expect(
            processRunner.recordedCalls,
            orderedEquals(<ProcessCall>[
              ProcessCall(
                  'xcodebuild',
                  <String>[
                    '-project',
                    'ios/Runner.xcodeproj',
                    '-list',
                    '-json'
                  ],
                  pluginExampleDirectory.path),
            ]));
      }, throwsA(const TypeMatcher<ToolExit>()));
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
      processRunner.resultStdout =
          '{"project":{"targets":["bar_scheme", "foo_scheme"]}}';
      await runner.run(<String>[
        'xctest',
        _kTarget,
        'foo_scheme',
        _kDestination,
        'foo_destination'
      ]);

      expect(
          processRunner.recordedCalls,
          orderedEquals(<ProcessCall>[
            ProcessCall(
                'xcodebuild',
                <String>['-project', 'ios/Runner.xcodeproj', '-list', '-json'],
                pluginExampleDirectory.path),
            ProcessCall(
                'xcodebuild',
                <String>[
                  'test',
                  '-workspace',
                  'ios/Runner.xcworkspace',
                  '-scheme',
                  'foo_scheme',
                  '-destination',
                  'foo_destination',
                  'CODE_SIGN_IDENTITY=""',
                  'CODE_SIGNING_REQUIRED=NO'
                ],
                pluginExampleDirectory.path),
          ]));

      cleanupPackages();
    });

    test('running with correct scheme and destination, skip 1 plugin',
        () async {
      createFakePlugin('plugin1',
          withExtraFiles: <List<String>>[
            <String>['example', 'test'],
          ],
          isIosPlugin: true);
      createFakePlugin('plugin2',
          withExtraFiles: <List<String>>[
            <String>['example', 'test'],
          ],
          isIosPlugin: true);

      final Directory pluginExampleDirectory1 =
          mockPackagesDir.childDirectory('plugin1').childDirectory('example');
      createFakePubspec(pluginExampleDirectory1, isFlutter: true);
      final Directory pluginExampleDirectory2 =
          mockPackagesDir.childDirectory('plugin2').childDirectory('example');
      createFakePubspec(pluginExampleDirectory2, isFlutter: true);

      final MockProcess mockProcess = MockProcess();
      mockProcess.exitCodeCompleter.complete(0);
      processRunner.processToReturn = mockProcess;
      processRunner.resultStdout =
          '{"project":{"targets":["bar_scheme", "foo_scheme"]}}';
      List<String> output = await runCapturingPrint(runner, <String>[
        'xctest',
        _kTarget,
        'foo_scheme',
        _kDestination,
        'foo_destination',
        _kSkip,
        'plugin1'
      ]);

      expect(output, contains('plugin1 was skipped with the --skip flag.'));

      expect(
          processRunner.recordedCalls,
          orderedEquals(<ProcessCall>[
            ProcessCall(
                'xcodebuild',
                <String>['-project', 'ios/Runner.xcodeproj', '-list', '-json'],
                pluginExampleDirectory2.path),
            ProcessCall(
                'xcodebuild',
                <String>[
                  'test',
                  '-workspace',
                  'ios/Runner.xcworkspace',
                  '-scheme',
                  'foo_scheme',
                  '-destination',
                  'foo_destination',
                  'CODE_SIGN_IDENTITY=""',
                  'CODE_SIGNING_REQUIRED=NO'
                ],
                pluginExampleDirectory2.path),
          ]));

      cleanupPackages();
    });
  });
}
