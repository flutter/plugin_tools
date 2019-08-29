import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:flutter_plugin_tools/src/common.dart';
import 'package:flutter_plugin_tools/src/license_test_command.dart';
import 'package:test/test.dart';

void main() async {
  final CommandRunner<Null> commandRunner =
      CommandRunner<Null>('pub global run flutter_plugin_tools', '')
        ..addCommand(
          LicenseTestCommand(Directory('test/test_plugins_dir/packages')),
        );

  group('license-test command', () {
    test('no license header', () async {
      expect(
        () => commandRunner.run(
          <String>['license-test', '--plugins', 'no_header'],
        ),
        throwsA(const TypeMatcher<ToolExit>()),
      );
    });

    test('no LICENSE', () async {
      expect(
        () => commandRunner.run(
          <String>['license-test', '--plugins', 'no_license'],
        ),
        throwsA(const TypeMatcher<ToolExit>()),
      );
    });

    test('invalid author', () async {
      expect(
        () => commandRunner.run(
          <String>['license-test', '--plugins', 'invalid_author'],
        ),
        throwsA(const TypeMatcher<ToolExit>()),
      );
    });

    test('correct license', () async {
      expect(
        commandRunner.run(
          <String>['license-test', '--plugins', 'correct_license'],
        ),
        completes,
      );
    });
  });
}
