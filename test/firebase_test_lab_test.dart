import 'package:args/command_runner.dart';
import 'package:file/file.dart';
import 'package:flutter_plugin_tools/src/firebase_test_lab_command.dart';
import 'package:test/test.dart';

import 'util.dart';

void main() {
  group('$FirebaseTestLabCommand', () {
    CommandRunner runner;

    setUp(() {
      initializeFakePackages();
      final FirebaseTestLabCommand command = FirebaseTestLabCommand(
          mockPackagesDir, mockFileSystem,
          processRunner: RecordingProcessRunner());

      runner = CommandRunner<Null>(
          'firebase_test_lab_command', 'Test for $FirebaseTestLabCommand');
      runner.addCommand(command);
    });

    test('runs e2e tests', () async {
      createFakePlugin('plugin', withExtraFiles: <List<String>>[
        <String>['example', 'test', 'plugin_e2e.dart'],
        <String>['example', 'test_driver', 'plugin_e2e_test.dart'],
        <String>['example', 'android', 'gradlew'],
        <String>[
          'example',
          'android',
          'app',
          'src',
          'androidTest',
          'MainActivityTest.java'
        ],
      ]);

      List<String> output =
          await runCapturingPrint(runner, <String>['firebase-test-lab']);

      expect(
        output,
        orderedEquals(<String>[
          '\nRUNNING FIREBASE TEST LAB TESTS for plugin',
          '\n\n',
          'All Firebase Test Lab tests successful!',
        ]),
      );

      cleanupPackages();
    });
  });
}
