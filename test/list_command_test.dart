import 'package:args/command_runner.dart';
import 'package:flutter_plugin_tools/src/list_command.dart';
import 'package:test/test.dart';

import 'util.dart';

void main() {
  group('$ListCommand', () {
    CommandRunner runner;

    setUp(() {
      initializeFakePackages();
      final ListCommand command = ListCommand(mockPackagesDir, mockFileSystem);

      runner = CommandRunner<Null>('list_test', 'Test for $ListCommand');
      runner.addCommand(command);
    });

    test('lists plugins', () async {
      createFakePlugin('plugin1');
      createFakePlugin('plugin2');

      List<String> plugins =
          await runCapturingPrint(runner, <String>['list', '--type=plugin']);

      expect(
        plugins,
        orderedEquals(<String>[
          '/packages/plugin1',
          '/packages/plugin2',
        ]),
      );

      cleanupPackages();
    });

    test('lists examples', () async {
      createFakePlugin('plugin1', withSingleExample: true);
      createFakePlugin('plugin2',
          withExamples: <String>['example1', 'example2']);
      createFakePlugin('plugin3');

      List<String> examples =
          await runCapturingPrint(runner, <String>['list', '--type=example']);

      expect(
        examples,
        orderedEquals(<String>[
          '/packages/plugin1/example',
          '/packages/plugin2/example/example1',
          '/packages/plugin2/example/example2',
        ]),
      );

      cleanupPackages();
    });

    test('lists packages', () async {
      createFakePlugin('plugin1', withSingleExample: true);
      createFakePlugin('plugin2',
          withExamples: <String>['example1', 'example2']);
      createFakePlugin('plugin3');

      List<String> packages =
          await runCapturingPrint(runner, <String>['list', '--type=package']);

      expect(
        packages,
        unorderedEquals(<String>[
          '/packages/plugin1',
          '/packages/plugin1/example',
          '/packages/plugin2',
          '/packages/plugin2/example/example1',
          '/packages/plugin2/example/example2',
          '/packages/plugin3',
        ]),
      );

      cleanupPackages();
    });

    test('lists file', () async {
      createFakePlugin('plugin1', withSingleExample: true);
      createFakePlugin('plugin2',
          withExamples: <String>['example1', 'example2']);
      createFakePlugin('plugin3');

      List<String> examples =
          await runCapturingPrint(runner, <String>['list', '--type=file']);

      expect(
        examples,
        unorderedEquals(<String>[
          '/packages/plugin1/pubspec.yaml',
          '/packages/plugin1/example/pubspec.yaml',
          '/packages/plugin2/pubspec.yaml',
          '/packages/plugin2/example/example1/pubspec.yaml',
          '/packages/plugin2/example/example2/pubspec.yaml',
          '/packages/plugin3/pubspec.yaml',
        ]),
      );

      cleanupPackages();
    });
  });
}
