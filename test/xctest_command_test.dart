import 'package:args/command_runner.dart';
import 'package:file/file.dart';
import 'package:flutter_plugin_tools/src/xctest_command.dart';
import 'package:path/path.dart' as p;
import 'package:platform/platform.dart';
import 'package:test/test.dart';
import 'package:flutter_plugin_tools/src/common.dart';

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
      final XCTestCommand command = XCTestCommand(
          mockPackagesDir, mockFileSystem,
          processRunner: processRunner);

      runner = CommandRunner<Null>(
          'xctest_command', 'Test for build_example_command');
      runner.addCommand(command);
      cleanupPackages();
    });

    test('Not specified ios--destination or scheme throws',
        () async {

      await expectLater(() => runner.run(<String>['xctest','--scheme', 'a_scheme']),
          throwsA(const TypeMatcher<ToolExit>()));

      await expectLater(() => runner.run(<String>['xctest','--ios-destination', 'a_destination']),
          throwsA(const TypeMatcher<ToolExit>()));
    });

    // test('building for ios', () async {
    //   createFakePlugin('plugin',
    //       withExtraFiles: <List<String>>[
    //         <String>['example', 'test'],
    //       ],
    //       isIosPlugin: true);

    //   final Directory pluginExampleDirectory =
    //       mockPackagesDir.childDirectory('plugin').childDirectory('example');

    //   createFakePubspec(pluginExampleDirectory, isFlutter: true);

    //   final List<String> output = await runCapturingPrint(runner, <String>[
    //     'build-examples',
    //     '--ipa',
    //     '--no-macos',
    //     '--enable-experiment=exp1'
    //   ]);
    //   final String packageName =
    //       p.relative(pluginExampleDirectory.path, from: mockPackagesDir.path);

    //   expect(
    //     output,
    //     orderedEquals(<String>[
    //       '\nBUILDING IPA for $packageName',
    //       '\n\n',
    //       'All builds successful!',
    //     ]),
    //   );

    //   print(processRunner.recordedCalls);
    //   expect(
    //       processRunner.recordedCalls,
    //       orderedEquals(<ProcessCall>[
    //         ProcessCall(
    //             flutterCommand,
    //             <String>[
    //               'build',
    //               'ios',
    //               '--no-codesign',
    //               '--enable-experiment=exp1'
    //             ],
    //             pluginExampleDirectory.path),
    //       ]));
    //   cleanupPackages();
    // });
  });
}
