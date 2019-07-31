import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:flutter_plugin_tools/src/common.dart';
import 'package:flutter_plugin_tools/src/license_check_command.dart';
import 'package:test/test.dart';

void main() async {
  final CommandRunner<Null> commandRunner =
      CommandRunner<Null>('pub global run flutter_plugin_tools', '')
        ..addCommand(
          LicenseCheckCommand(Directory('test/test_plugins_dir/packages')),
        );

  group('license-check command', () {
    test('no license header', () async {
      expect(
        () => commandRunner.run(
          <String>['license-check', '--plugins', 'no_header'],
        ),
        throwsA(const TypeMatcher<ToolExit>()),
      );
    });

    test('no LICENSE', () async {
      expect(
        () => commandRunner.run(
          <String>['license-check', '--plugins', 'no_license'],
        ),
        throwsA(const TypeMatcher<ToolExit>()),
      );
    });

    test('invalid author', () async {
      expect(
        () => commandRunner.run(
          <String>['license-check', '--plugins', 'invalid_author'],
        ),
        throwsA(const TypeMatcher<ToolExit>()),
      );
    });

    test('correct license', () async {
      expect(
        () => commandRunner.run(
          <String>['license-check', '--plugins', 'correct_license'],
        ),
        returnsNormally,
      );
    });
  });
}
