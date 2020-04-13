import 'package:args/command_runner.dart';
import 'package:file/file.dart';
import 'package:flutter_plugin_tools/src/drive_examples_command.dart';
import 'package:path/path.dart' as p;
import 'package:platform/platform.dart';
import 'package:test/test.dart';

import 'util.dart';

void main() {
  group('test drive_example_command', () {
    CommandRunner<Null> runner;
    RecordingProcessRunner processRunner;
    final String flutterCommand =
        LocalPlatform().isWindows ? 'flutter.bat' : 'flutter';
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

      String deviceTestPath = p.join('test', 'plugin.dart');
      print(processRunner.recordedCalls);
      expect(
          processRunner.recordedCalls,
          orderedEquals(<ProcessCall>[
            ProcessCall(flutterCommand, <String>['drive', deviceTestPath],
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

      String deviceTestPath = p.join('test_driver', 'plugin.dart');
      print(processRunner.recordedCalls);
      expect(
          processRunner.recordedCalls,
          orderedEquals(<ProcessCall>[
            ProcessCall(flutterCommand, <String>['drive', deviceTestPath],
                pluginExampleDirectory.path),
          ]));

      cleanupPackages();
    });
    test('runs drive when plugin does not suppport macOS is a no-op', () async {
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
    test('runs drive on a macOS plugin', () async {
      createFakePlugin('plugin',
          withExtraFiles: <List<String>>[
            <String>['example', 'test_driver', 'plugin_test.dart'],
            <String>['example', 'test_driver', 'plugin.dart'],
            <String>['example', 'macos', 'macos.swift'],
          ],
          isMacOsPlugin: true);

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

      String deviceTestPath = p.join('test_driver', 'plugin.dart');
      print(processRunner.recordedCalls);
      expect(
          processRunner.recordedCalls,
          orderedEquals(<ProcessCall>[
            ProcessCall(
                flutterCommand,
                <String>['drive', '-d', 'macos', deviceTestPath],
                pluginExampleDirectory.path),
          ]));

      cleanupPackages();
    });
    test('runs drive when plugin does not suppport windows is a no-op',
        () async {
      createFakePlugin('plugin',
          withExtraFiles: <List<String>>[
            <String>['example', 'test_driver', 'plugin_test.dart'],
            <String>['example', 'test_driver', 'plugin.dart'],
          ],
          isMacOsPlugin: false);

      final Directory pluginExampleDirectory =
          mockPackagesDir.childDirectory('plugin').childDirectory('example');

      createFakePubspec(pluginExampleDirectory, isFlutter: true);

      final List<String> output = await runCapturingPrint(runner, <String>[
        'drive-examples',
        '--windows',
      ]);

      expect(
        output,
        orderedEquals(<String>[
          '\n\n',
          'All driver tests successful!',
        ]),
      );

      print(processRunner.recordedCalls);
      // Output should be empty since running drive-examples --windows on a non-windows
      // plugin is a no-op.
      expect(processRunner.recordedCalls, <ProcessCall>[]);

      cleanupPackages();
    });

    test('runs drive on a Windows plugin', () async {
      createFakePlugin('plugin',
          withExtraFiles: <List<String>>[
            <String>['example', 'test_driver', 'plugin_test.dart'],
            <String>['example', 'test_driver', 'plugin.dart'],
          ],
          isWindowsPlugin: true);

      final Directory pluginExampleDirectory =
          mockPackagesDir.childDirectory('plugin').childDirectory('example');

      createFakePubspec(pluginExampleDirectory, isFlutter: true);

      final List<String> output = await runCapturingPrint(runner, <String>[
        'drive-examples',
        '--windows',
      ]);

      expect(
        output,
        orderedEquals(<String>[
          '\n\n',
          'All driver tests successful!',
        ]),
      );

      String deviceTestPath = p.join('test_driver', 'plugin.dart');
      print(processRunner.recordedCalls);
      expect(
          processRunner.recordedCalls,
          orderedEquals(<ProcessCall>[
            ProcessCall(flutterCommand, <String>['create', '.'],
                pluginExampleDirectory.path),
            ProcessCall(
                flutterCommand,
                <String>['drive', '-d', 'windows', deviceTestPath],
                pluginExampleDirectory.path),
          ]));

      cleanupPackages();
    });
    test('runs drive on a Windows plugin with a windows direactory does not call flutter create', () async {
      createFakePlugin('plugin',
          withExtraFiles: <List<String>>[
            <String>['example', 'test_driver', 'plugin_test.dart'],
            <String>['example', 'test_driver', 'plugin.dart'],
            <String>['example', 'windows', 'test.h'],
          ],
          isWindowsPlugin: true);

      final Directory pluginExampleDirectory =
          mockPackagesDir.childDirectory('plugin').childDirectory('example');

      createFakePubspec(pluginExampleDirectory, isFlutter: true);

      final List<String> output = await runCapturingPrint(runner, <String>[
        'drive-examples',
        '--windows',
      ]);

      expect(
        output,
        orderedEquals(<String>[
          '\n\n',
          'All driver tests successful!',
        ]),
      );

      String deviceTestPath = p.join('test_driver', 'plugin.dart');
      print(processRunner.recordedCalls);
      // flutter create . should NOT be called.
      expect(
          processRunner.recordedCalls,
          orderedEquals(<ProcessCall>[
            ProcessCall(
                flutterCommand,
                <String>['drive', '-d', 'windows', deviceTestPath],
                pluginExampleDirectory.path),
          ]));

      cleanupPackages();
    });
  });
}
