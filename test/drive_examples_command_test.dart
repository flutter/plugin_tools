import 'package:args/command_runner.dart';
import 'package:file/file.dart';
import 'package:flutter_plugin_tools/src/drive_examples_command.dart';
import 'package:test/test.dart';

import 'util.dart';

void main() {
  group('test drive_example_command', () {
    CommandRunner<Null> runner;
    RecordingProcessRunner processRunner;

    setUp(() {
      initializeFakePackages();
      processRunner = RecordingProcessRunner();
      final DriveExamplesCommand command = DriveExamplesCommand(
          mockPackagesDir, mockFileSystem,
          processRunner: processRunner);

      runner = CommandRunner<Null>(
          'drive_examples_command', 'Test for drive_example_command');
      runner.addCommand(command);
      cleanupPackages();
    });

    test('runs drive under folder "test"', () async {
      createFakePlugin('plugin', withExtraFiles: <List<String>>[
        <String>['example', 'test_driver', 'plugin_test.dart'],
        <String>['example', 'test', 'plugin.dart'],
      ]);

      final Directory pluginExampleDirectory =
          mockPackagesDir.childDirectory('plugin').childDirectory('example');

      createFakePubspec(pluginExampleDirectory, isFlutter: true);

      final List<String> output = await runCapturingPrint(runner, <String>[
        'drive-examples',
      ]);

      expect(
        output,
        orderedEquals(<String>[
          '\n\n',
          'All driver tests successful!',
        ]),
      );

      print(processRunner.recordedCalls);
      expect(
          processRunner.recordedCalls,
          orderedEquals(<ProcessCall>[
            ProcessCall('flutter', <String>['drive', 'test/plugin.dart'],
                pluginExampleDirectory.path),
          ]));
      cleanupPackages();
    });

    test('runs drive under folder "test_driver"', () async {
      createFakePlugin('plugin', withExtraFiles: <List<String>>[
        <String>['example', 'test_driver', 'plugin_test.dart'],
        <String>['example', 'test_driver', 'plugin.dart'],
      ]);

      final Directory pluginExampleDirectory =
          mockPackagesDir.childDirectory('plugin').childDirectory('example');

      createFakePubspec(pluginExampleDirectory, isFlutter: true);

      final List<String> output = await runCapturingPrint(runner, <String>[
        'drive-examples',
      ]);

      expect(
        output,
        orderedEquals(<String>[
          '\n\n',
          'All driver tests successful!',
        ]),
      );

      print(processRunner.recordedCalls);
      expect(
          processRunner.recordedCalls,
          orderedEquals(<ProcessCall>[
            ProcessCall('flutter', <String>['drive', 'test_driver/plugin.dart'],
                pluginExampleDirectory.path),
          ]));

      cleanupPackages();
    });
    test('runs drive with no macos implementation', () async {
      createFakePlugin('plugin', withExtraFiles: <List<String>>[
        <String>['example', 'test_driver', 'plugin_test.dart'],
        <String>['example', 'test_driver', 'plugin.dart'],
      ]);

      final Directory pluginExampleDirectory =
          mockPackagesDir.childDirectory('plugin').childDirectory('example');

      createFakePubspec(pluginExampleDirectory, isFlutter: true);

      final List<String> output = await runCapturingPrint(runner, <String>[
        'drive-examples',
        '--macos',
      ]);

      expect(
        output,
        orderedEquals(<String>[
          '\n\n',
          'All driver tests successful!',
        ]),
      );

      print(processRunner.recordedCalls);
      // Output should be empty since running drive-examples --macos with no macos
      // implementation is a no-op.
      expect(processRunner.recordedCalls, <ProcessCall>[]);

      cleanupPackages();
    });
    test('runs drive with a macOS implementation', () async {
      createFakePlugin('plugin', withExtraFiles: <List<String>>[
        <String>['example', 'test_driver', 'plugin_test.dart'],
        <String>['example', 'test_driver', 'plugin.dart'],
        <String>['example', 'macos', 'macos.swift'],
      ]);

      final Directory pluginExampleDirectory =
          mockPackagesDir.childDirectory('plugin').childDirectory('example');

      createFakePubspec(pluginExampleDirectory, isFlutter: true);

      final List<String> output = await runCapturingPrint(runner, <String>[
        'drive-examples',
        '--macos',
      ]);

      expect(
        output,
        orderedEquals(<String>[
          '\n\n',
          'All driver tests successful!',
        ]),
      );

      print(processRunner.recordedCalls);
      expect(
          processRunner.recordedCalls,
          orderedEquals(<ProcessCall>[
            ProcessCall(
                'flutter',
                <String>['drive', '-d', 'macos', 'test_driver/plugin.dart'],
                pluginExampleDirectory.path),
          ]));

      cleanupPackages();
    });
  });
}
