// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:io' as io;

import 'package:file/file.dart';
import 'package:path/path.dart' as p;

import 'common.dart';

const String kiOSDestination = 'ios-destination';
const String kScheme = 'scheme';

/// The command to run iOS' XCTests in plugins, this should work for both XCUnitTest and XCUITest targets.
/// The tests target have to be added to the xcode project of the example app. Usually at "example/ios/Runner.xcodeproj".
/// The command takes a "-scheme" argument which has to match the scheme of the test target.
/// For information on how to add test target in an xcode project, see https://developer.apple.com/library/archive/documentation/ToolsLanguages/Conceptual/Xcode_Overview/UnitTesting.html
class XCTestCommand extends PluginCommand {
  XCTestCommand(
    Directory packagesDir,
    FileSystem fileSystem, {
    ProcessRunner processRunner = const ProcessRunner(),
  }) : super(packagesDir, fileSystem, processRunner: processRunner) {
    argParser.addOption(
      kiOSDestination,
      help:
          'Specify the destination when running the test, used for -destination flag for xcodebuild command.',
    );
    argParser.addOption(
      kScheme,
      help: 'The test target scheme.',
    );
  }

  @override
  final String name = 'xctest';

  @override
  final String description = 'Runs the xctests in the iOS example apps.\n\n'
      'This command requires "flutter" to be in your path.';

  @override
  Future<Null> run() async {
    if (argResults[kScheme] == null) {
      print('--scheme must be specified');
      throw ToolExit(1);
    }

    if (argResults[kiOSDestination] == null) {
      print('--ios-destination must be specified');
      throw ToolExit(1);
    }

    checkSharding();

    final String scheme = argResults[kScheme];
    final String destination = argResults[kiOSDestination];

    List<String> failingPackages = <String>[];
    await for (Directory plugin in getPlugins()) {
      // Start running for package.
      final String packageName =
            p.relative(plugin.path, from: packagesDir.path);
      print('Start running for $packageName ...');
      if (!isIosPlugin(plugin, fileSystem)) {
        print('iOS is not supported by this plugin.\n\n');
        continue;
      }
      for (Directory example in getExamplesForPlugin(plugin)) {
        // Look for the test scheme in the example app.
        print('Look for scheme named $scheme: ...');
        final String findSchemeCommand =
            'xcodebuild -project ios/Runner.xcodeproj -list -json';
        print(findSchemeCommand);
        final io.ProcessResult xcodeprojListResult = await processRunner.run(
            'xcodebuild',
            <String>['-project', 'ios/Runner.xcodeproj', '-list', '-json'],
            workingDir: example);
        if (xcodeprojListResult.exitCode != 0) {
          print('Error occurred while running "$findSchemeCommand":\n\n'
              '${xcodeprojListResult.stderr}');
          failingPackages.add(packageName);
          continue;
        }

        final String xcdeprojListOutput = xcodeprojListResult.stdout;
        if (!xcdeprojListOutput.contains(scheme)) {
          print('$scheme not configured for $packageName, skipping.\n\n');
          continue;
        }
        // Found the scheme, running tests
        print('Running XCUITests for $packageName ...');
        final String xctestCommand =
            'xcodebuild test -project ios/Runner.xcodeproj -scheme $scheme -destination "$destination" CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO';
        print(xctestCommand);
        final int exitCode = await processRunner.runAndStream(
            'xcodebuild',
            <String>[
              'test',
              '-project',
              'ios/Runner.xcodeproj',
              '-scheme',
              scheme,
              '-destination',
              destination,
              'CODE_SIGN_IDENTITY=""',
              'CODE_SIGNING_REQUIRED=NO'
            ],
            workingDir: example);
        if (exitCode != 0) {
          failingPackages.add(packageName);
        }
      }
    }

    // Command end, print reports.
    if (failingPackages.isEmpty) {
      print("All XCUITests have passed!");
    } else {
      print(
          'The following packages are failing XCUITests (see above for details):');
      for (String package in failingPackages) {
        print(' * $package');
      }
      throw ToolExit(1);
    }
  }
}
