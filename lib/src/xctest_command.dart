// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:io' as io;

import 'package:file/file.dart';
import 'package:path/path.dart' as p;
import 'package:platform/platform.dart';

import 'common.dart';

const String kiOSDestination = 'ios-destination';
const String kScheme = 'scheme';

class XCTestCommand extends PluginCommand {
  XCTestCommand(
    Directory packagesDir,
    FileSystem fileSystem, {
    ProcessRunner processRunner = const ProcessRunner(),
  }) : super(packagesDir, fileSystem, processRunner: processRunner) {
    argParser.addOption(
      kiOSDestination,
      help: 'Specify the destination when running the test, used for -destination flag for xcodebuild command.',
    );
    argParser.addOption(
      kScheme,
      help: 'The test target scheme.',
    );
  }

  @override
  final String name = 'xctest';

  @override
  final String description =
      'Runs the xctests in the iOS example apps.\n\n'
      'This command requires "flutter" to be in your path.';

  @override
  Future<Null> run() async {
    if (argResults[kScheme] == null) {
      print(
          '--scheme must be specified');
      throw ToolExit(1);
    }

    if (argResults[kiOSDestination] == null) {
      print(
          '--ios-destination must be specified');
      throw ToolExit(1);
    }

    checkSharding();

    final String scheme = argResults[kScheme];
    final String destination = argResults[kiOSDestination];

    



    print('Look for scheme named $scheme:');
    final String findSchemeCommand = 'xcodebuild -project example/ios/Runner.xcodeproj -list -json';
    print(findSchemeCommand);
    final io.ProcessResult xcodeprojListResult = await processRunner.run('xcodebuld', <String>['-project', 'example/ios/Runner.xcodeproj', '-list', '-json']);
    if (xcodeprojListResult.stderr != null) {
      print('Error occurred while running "$findSchemeCommand":\n\n'
            '${xcodeprojListResult.stderr}');
      throw ToolExit(1);
    }
    final String xcdeprojListOutput = xcodeprojListResult.stdout;
    if (!xcdeprojListOutput.contains(scheme)) {
      print('$scheme not configured for this project, skipping');
      return;
    }
    final String xctestCommand = 'xcodebuild test -project example/ios/Runner.xcodeproj -scheme $scheme -destination $destination CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO';
    print(xctestCommand);
    final int exitCode = await processRunner.runAndStream(
                'xcodebuild',
                <String>[
                  'test',
                  '-project',
                  'example/ios/Runner.xcodeproj',
                ],);

        // final String flutterCommand =
        // LocalPlatform().isWindows ? 'flutter.bat' : 'flutter';

    // final String enableExperiment = argResults[kEnableExperiment];
    // final List<String> failingPackages = <String>[];
    // await for (Directory plugin in getPlugins()) {
    //   for (Directory example in getExamplesForPlugin(plugin)) {
    //     final String packageName =
    //         p.relative(example.path, from: packagesDir.path);

    //     if (argResults[kLinux]) {
    //       print('\nBUILDING Linux for $packageName');
    //       if (isLinuxPlugin(plugin, fileSystem)) {
    //         int buildExitCode = await processRunner.runAndStream(
    //             flutterCommand,
    //             <String>[
    //               'build',
    //               kLinux,
    //               if (enableExperiment.isNotEmpty)
    //                 '--enable-experiment=$enableExperiment',
    //             ],
    //             workingDir: example);
    //         if (buildExitCode != 0) {
    //           failingPackages.add('$packageName (linux)');
    //         }
    //       } else {
    //         print('Linux is not supported by this plugin');
    //       }
    //     }

    //     if (argResults[kMacos]) {
    //       print('\nBUILDING macOS for $packageName');
    //       if (isMacOsPlugin(plugin, fileSystem)) {
    //         // TODO(https://github.com/flutter/flutter/issues/46236):
    //         // Builing macos without running flutter pub get first results
    //         // in an error.
    //         int exitCode = await processRunner.runAndStream(
    //             flutterCommand, <String>['pub', 'get'],
    //             workingDir: example);
    //         if (exitCode != 0) {
    //           failingPackages.add('$packageName (macos)');
    //         } else {
    //           exitCode = await processRunner.runAndStream(
    //               flutterCommand,
    //               <String>[
    //                 'build',
    //                 kMacos,
    //                 if (enableExperiment.isNotEmpty)
    //                   '--enable-experiment=$enableExperiment',
    //               ],
    //               workingDir: example);
    //           if (exitCode != 0) {
    //             failingPackages.add('$packageName (macos)');
    //           }
    //         }
    //       } else {
    //         print('macOS is not supported by this plugin');
    //       }
    //     }

    //     if (argResults[kWindows]) {
    //       print('\nBUILDING Windows for $packageName');
    //       if (isWindowsPlugin(plugin, fileSystem)) {
    //         // The Windows tooling is not yet stable, so we need to
    //         // delete any existing windows directory and create a new one
    //         // with 'flutter create .'
    //         final Directory windowsFolder =
    //             fileSystem.directory(p.join(example.path, 'windows'));
    //         bool exampleCreated = false;
    //         if (!windowsFolder.existsSync()) {
    //           int exampleCreateCode = await processRunner.runAndStream(
    //               flutterCommand, <String>['create', '.'],
    //               workingDir: example);
    //           if (exampleCreateCode == 0) {
    //             exampleCreated = true;
    //           }
    //         }
    //         int buildExitCode = await processRunner.runAndStream(
    //             flutterCommand,
    //             <String>[
    //               'build',
    //               kWindows,
    //               if (enableExperiment.isNotEmpty)
    //                 '--enable-experiment=$enableExperiment',
    //             ],
    //             workingDir: example);
    //         if (buildExitCode != 0) {
    //           failingPackages.add('$packageName (windows)');
    //         }
    //         if (exampleCreated && windowsFolder.existsSync()) {
    //           windowsFolder.deleteSync(recursive: true);
    //         }
    //       } else {
    //         print('Windows is not supported by this plugin');
    //       }
    //     }

    //     if (argResults[kIpa]) {
    //       print('\nBUILDING IPA for $packageName');
    //       if (isIosPlugin(plugin, fileSystem)) {
    //         final int exitCode = await processRunner.runAndStream(
    //             flutterCommand,
    //             <String>[
    //               'build',
    //               'ios',
    //               '--no-codesign',
    //               if (enableExperiment.isNotEmpty)
    //                 '--enable-experiment=$enableExperiment',
    //             ],
    //             workingDir: example);
    //         if (exitCode != 0) {
    //           failingPackages.add('$packageName (ipa)');
    //         }
    //       } else {
    //         print('iOS is not supported by this plugin');
    //       }
    //     }

    //     if (argResults[kApk]) {
    //       print('\nBUILDING APK for $packageName');
    //       if (isAndroidPlugin(plugin, fileSystem)) {
    //         final int exitCode = await processRunner.runAndStream(
    //             flutterCommand,
    //             <String>[
    //               'build',
    //               'apk',
    //               if (enableExperiment.isNotEmpty)
    //                 '--enable-experiment=$enableExperiment',
    //             ],
    //             workingDir: example);
    //         if (exitCode != 0) {
    //           failingPackages.add('$packageName (apk)');
    //         }
    //       } else {
    //         print('Android is not supported by this plugin');
    //       }
    //     }
    //   }
    // }
    // print('\n\n');

    // if (failingPackages.isNotEmpty) {
    //   print('The following build are failing (see above for details):');
    //   for (String package in failingPackages) {
    //     print(' * $package');
    //   }
    //   throw ToolExit(1);
    // }

    // print('All builds successful!');
  }
}
