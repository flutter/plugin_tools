import 'package:args/command_runner.dart';
import 'package:file/file.dart';
import 'package:flutter_plugin_tools/src/lint_podspecs_command.dart';
import 'package:mockito/mockito.dart';
import 'package:path/path.dart' as p;
import 'package:platform/platform.dart';
import 'package:test/test.dart';

import 'mocks.dart';
import 'util.dart';

void main() {
  group('$LintPodspecsCommand', () {
    CommandRunner<Null> runner;
    MockPlatform mockPlatform;
    final RecordingProcessRunner processRunner = RecordingProcessRunner();

    setUp(() {
      initializeFakePackages();
      mockPlatform = MockPlatform();
      when(mockPlatform.isMacOS).thenReturn(true);
      final LintPodspecsCommand command = LintPodspecsCommand(
          mockPackagesDir,
          mockFileSystem,
          processRunner: processRunner,
        platform: mockPlatform
      );

      runner = CommandRunner<Null>('podspec_test', 'Test for $LintPodspecsCommand');
      runner.addCommand(command);
      final MockProcess mockLintProcess = MockProcess();
      mockLintProcess.exitCodeCompleter.complete(0);
      processRunner.processToReturn = mockLintProcess;
      processRunner.recordedCalls.clear();
    });

    test('only runs on macOS', () async {
      createFakePlugin('plugin1', withExtraFiles: <List<String>>[
        <String>['plugin1.podspec'],
      ]);

      when(mockPlatform.isMacOS).thenReturn(false);
      await runner.run(<String>['podspecs']);

      expect(
        processRunner.recordedCalls,
        equals(<ProcessCall>[]),
      );

      cleanupPackages();
    });

    test('runs pod lib lint on a podspec', () async {
      Directory plugin1Dir =
      createFakePlugin('plugin1', withExtraFiles: <List<String>>[
        <String>['ios', 'plugin1.podspec'],
        <String>['bogus.dart'], // Ignore non-podspecs.
      ]);

      await runner.run(<String>['podspecs']);

      expect(
        processRunner.recordedCalls,
        orderedEquals(<ProcessCall>[
          ProcessCall('which', <String>['pod'], mockPackagesDir.path),
          ProcessCall('pod', <String>[
            'lib',
            'lint',
            p.join(plugin1Dir.path, 'ios', 'plugin1.podspec'),
            '--allow-warnings',
            '--fail-fast',
            '--silent',
            '--analyze',
            '--use-libraries'
          ], mockPackagesDir.path),
          ProcessCall('pod', <String>[
            'lib',
            'lint',
            p.join(plugin1Dir.path, 'ios', 'plugin1.podspec'),
            '--allow-warnings',
            '--fail-fast',
            '--silent',
            '--analyze',
          ], mockPackagesDir.path),
        ]),
      );

      cleanupPackages();
    });

    test('skips podspecs with known warnings', () async {
      createFakePlugin('url_launcher_web', withExtraFiles: <List<String>>[
        <String>['url_launcher_web.podspec']
      ]);

      await runner.run(<String>['podspecs']);

      expect(
        processRunner.recordedCalls,
        orderedEquals(<ProcessCall>[
          ProcessCall('which', <String>['pod'], mockPackagesDir.path),
        ]),
      );

      cleanupPackages();
    });

    test('skips analyzer for podspecs with known warnings', () async {
      Directory plugin1Dir =
      createFakePlugin('camera', withExtraFiles: <List<String>>[
        <String>['camera.podspec'],
      ]);

      await runner.run(<String>['podspecs']);

      expect(
        processRunner.recordedCalls,
        orderedEquals(<ProcessCall>[
          ProcessCall('which', <String>['pod'], mockPackagesDir.path),
          ProcessCall('pod', <String>[
            'lib',
            'lint',
            p.join(plugin1Dir.path, 'camera.podspec'),
            '--allow-warnings',
            '--fail-fast',
            '--silent',
            '--use-libraries'
          ], mockPackagesDir.path),
          ProcessCall('pod', <String>[
            'lib',
            'lint',
            p.join(plugin1Dir.path, 'camera.podspec'),
            '--allow-warnings',
            '--fail-fast',
            '--silent',
          ], mockPackagesDir.path),
        ]),
      );

      cleanupPackages();
    });
  });
}

class MockPlatform extends Mock implements Platform {}
