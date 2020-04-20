import 'package:args/command_runner.dart';
import 'package:file/file.dart';
import 'package:flutter_plugin_tools/src/build_examples_command.dart';
import 'package:path/path.dart' as p;
import 'package:platform/platform.dart';
import 'package:test/test.dart';

import 'util.dart';

void main() {
  group('test build_example_command', () {
    CommandRunner<Null> runner;
    RecordingProcessRunner processRunner;
    final String flutterCommand =
        LocalPlatform().isWindows ? 'flutter.bat' : 'flutter';

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
      final String packageName =
          p.relative(pluginExampleDirectory.path, from: mockPackagesDir.path);

      expect(
        output,
        orderedEquals(<String>[
          '\nBUILDING IPA for $packageName',
          '\n\n',
          'All builds successful!',
        ]),
      );

      print(processRunner.recordedCalls);
      expect(
          processRunner.recordedCalls,
          orderedEquals(<ProcessCall>[
            ProcessCall(
                flutterCommand,
                <String>['build', 'ios', '--no-codesign'],
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
      final String packageName =
          p.relative(pluginExampleDirectory.path, from: mockPackagesDir.path);

      expect(
        output,
        orderedEquals(<String>[
          '\nBUILDING macos for $packageName',
          '\macOS is not supported by this plugin',
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
      createFakePlugin('plugin',
          withExtraFiles: <List<String>>[
            <String>['example', 'test'],
            <String>['example', 'macos', 'macos.swift'],
          ],
          isMacOsPlugin: true);

      final Directory pluginExampleDirectory =
          mockPackagesDir.childDirectory('plugin').childDirectory('example');

      createFakePubspec(pluginExampleDirectory, isFlutter: true);

      final List<String> output = await runCapturingPrint(
          runner, <String>['build-examples', '--no-ipa', '--macos']);
      final String packageName =
          p.relative(pluginExampleDirectory.path, from: mockPackagesDir.path);

      expect(
        output,
        orderedEquals(<String>[
          '\nBUILDING macos for $packageName',
          '\n\n',
          'All builds successful!',
        ]),
      );

      print(processRunner.recordedCalls);
      expect(
          processRunner.recordedCalls,
          orderedEquals(<ProcessCall>[
            ProcessCall(flutterCommand, <String>['pub', 'get'],
                pluginExampleDirectory.path),
            ProcessCall(flutterCommand, <String>['build', 'macos'],
                pluginExampleDirectory.path),
          ]));
      cleanupPackages();
    });

    test(
        'runs build for Windows when plugin is not setup for Windows results in no-op',
        () async {
      createFakePlugin('plugin',
          withExtraFiles: <List<String>>[
            <String>['example', 'test'],
          ],
          isWindowsPlugin: false);

      final Directory pluginExampleDirectory =
          mockPackagesDir.childDirectory('plugin').childDirectory('example');

      createFakePubspec(pluginExampleDirectory, isFlutter: true);

      final List<String> output = await runCapturingPrint(
          runner, <String>['build-examples', '--no-ipa', '--windows']);
      final String packageName =
          p.relative(pluginExampleDirectory.path, from: mockPackagesDir.path);

      expect(
        output,
        orderedEquals(<String>[
          '\nBUILDING windows for $packageName',
          'Windows is not supported by this plugin',
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

    test('runs build for windows', () async {
      createFakePlugin('plugin',
          withExtraFiles: <List<String>>[
            <String>['example', 'test'],
          ],
          isWindowsPlugin: true);

      final Directory pluginExampleDirectory =
          mockPackagesDir.childDirectory('plugin').childDirectory('example');

      createFakePubspec(pluginExampleDirectory, isFlutter: true);

      final List<String> output = await runCapturingPrint(
          runner, <String>['build-examples', '--no-ipa', '--windows']);
      final String packageName =
          p.relative(pluginExampleDirectory.path, from: mockPackagesDir.path);

      expect(
        output,
        orderedEquals(<String>[
          '\nBUILDING windows for $packageName',
          '\n\n',
          'All builds successful!',
        ]),
      );

      print(processRunner.recordedCalls);
      expect(
          processRunner.recordedCalls,
          orderedEquals(<ProcessCall>[
            ProcessCall(flutterCommand, <String>['create', '.'],
                pluginExampleDirectory.path),
            ProcessCall(flutterCommand, <String>['build', 'windows'],
                pluginExampleDirectory.path),
          ]));
      cleanupPackages();
    });

    test(
        'runs build for windows does not call flutter create if a directory exists',
        () async {
      createFakePlugin('plugin',
          withExtraFiles: <List<String>>[
            <String>['example', 'test'],
            <String>['example', 'windows', 'test.h']
          ],
          isWindowsPlugin: true);

      final Directory pluginExampleDirectory =
          mockPackagesDir.childDirectory('plugin').childDirectory('example');

      createFakePubspec(pluginExampleDirectory, isFlutter: true);

      final List<String> output = await runCapturingPrint(
          runner, <String>['build-examples', '--no-ipa', '--windows']);
      final String packageName =
          p.relative(pluginExampleDirectory.path, from: mockPackagesDir.path);

      expect(
        output,
        orderedEquals(<String>[
          '\nBUILDING windows for $packageName',
          '\n\n',
          'All builds successful!',
        ]),
      );

      print(processRunner.recordedCalls);
      // flutter create . should NOT be called.
      expect(
          processRunner.recordedCalls,
          orderedEquals(<ProcessCall>[
            ProcessCall(flutterCommand, <String>['build', 'windows'],
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
      final String packageName =
          p.relative(pluginExampleDirectory.path, from: mockPackagesDir.path);

      expect(
        output,
        orderedEquals(<String>[
          '\nBUILDING APK for $packageName',
          '\n\n',
          'All builds successful!',
        ]),
      );

      print(processRunner.recordedCalls);
      expect(
          processRunner.recordedCalls,
          orderedEquals(<ProcessCall>[
            ProcessCall(flutterCommand, <String>['build', 'apk'],
                pluginExampleDirectory.path),
          ]));
      cleanupPackages();
    });
  });
}
