import 'package:args/command_runner.dart';
import 'package:file/file.dart';
import 'package:flutter_plugin_tools/src/build_examples_command.dart';
import 'package:test/test.dart';

import 'util.dart';

void main() {
  group('test build_example_command', () {
    CommandRunner<Null> runner;
    RecordingProcessRunner processRunner;

    setUp(() {
      initializeFakePackages();
      processRunner = RecordingProcessRunner();
      final BuildExamplesCommand command = BuildExamplesCommand(
          mockPackagesDir, mockFileSystem,
          processRunner: processRunner);

      runner = CommandRunner<Null>(
          'build_examples_command', 'Test for build_example_command');
      runner.addCommand(command);
      cleanupPackages();
    });

    test('runs build for ios', () async {
      createFakePlugin('plugin', withExtraFiles: <List<String>>[
        <String>['example', 'test'],
      ]);

      final Directory pluginExampleDirectory =
          mockPackagesDir.childDirectory('plugin').childDirectory('example');

      createFakePubspec(pluginExampleDirectory, isFlutter: true);

      final List<String> output = await runCapturingPrint(
          runner, <String>['build-examples', '--ipa', '--no-macos']);

      expect(
        output,
        orderedEquals(<String>[
          '\nBUILDING IPA for plugin/example',
          '\n\n',
          'All builds successful!',
        ]),
      );

      print(processRunner.recordedCalls);
      expect(
          processRunner.recordedCalls,
          orderedEquals(<ProcessCall>[
            ProcessCall('flutter', <String>['build', 'ios', '--no-codesign'],
                pluginExampleDirectory.path),
          ]));
      cleanupPackages();
    });
    test('runs build for macos with no implementation results in no-op',
        () async {
      createFakePlugin('plugin', withExtraFiles: <List<String>>[
        <String>['example', 'test'],
      ]);

      final Directory pluginExampleDirectory =
          mockPackagesDir.childDirectory('plugin').childDirectory('example');

      createFakePubspec(pluginExampleDirectory, isFlutter: true);

      final List<String> output = await runCapturingPrint(
          runner, <String>['build-examples', '--no-ipa', '--macos']);

      expect(
        output,
        orderedEquals(<String>[
          '\nBUILDING macos for plugin/example',
          '\No macOS implementation found.',
          '\n\n',
          'All builds successful!',
        ]),
      );

      print(processRunner.recordedCalls);
      // Output should be empty since running build-examples --macos with no macos
      // implementation is a no-op.
      expect(processRunner.recordedCalls, orderedEquals(<ProcessCall>[]));
      cleanupPackages();
    });
    test('runs build for macos', () async {
      createFakePlugin('plugin', withExtraFiles: <List<String>>[
        <String>['example', 'test'],
        <String>['example', 'macos', 'macos.swift'],
      ]);

      final Directory pluginExampleDirectory =
          mockPackagesDir.childDirectory('plugin').childDirectory('example');

      createFakePubspec(pluginExampleDirectory, isFlutter: true);

      final List<String> output = await runCapturingPrint(
          runner, <String>['build-examples', '--no-ipa', '--macos']);

      expect(
        output,
        orderedEquals(<String>[
          '\nBUILDING macos for plugin/example',
          '\n\n',
          'All builds successful!',
        ]),
      );

      print(processRunner.recordedCalls);
      expect(
          processRunner.recordedCalls,
          orderedEquals(<ProcessCall>[
            ProcessCall(
                'flutter', <String>['pub', 'get'], pluginExampleDirectory.path),
            ProcessCall('flutter', <String>['build', 'macos'],
                pluginExampleDirectory.path),
          ]));
      cleanupPackages();
    });

    test('runs build for android', () async {
      createFakePlugin('plugin', withExtraFiles: <List<String>>[
        <String>['example', 'test'],
      ]);

      final Directory pluginExampleDirectory =
          mockPackagesDir.childDirectory('plugin').childDirectory('example');

      createFakePubspec(pluginExampleDirectory, isFlutter: true);

      final List<String> output = await runCapturingPrint(runner,
          <String>['build-examples', '--apk', '--no-ipa', '--no-macos']);

      expect(
        output,
        orderedEquals(<String>[
          '\nBUILDING APK for plugin/example',
          '\n\n',
          'All builds successful!',
        ]),
      );

      print(processRunner.recordedCalls);
      expect(
          processRunner.recordedCalls,
          orderedEquals(<ProcessCall>[
            ProcessCall('flutter', <String>['build', 'apk'],
                pluginExampleDirectory.path),
          ]));
      cleanupPackages();
    });
  });
}
