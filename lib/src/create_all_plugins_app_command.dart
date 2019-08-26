// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';
import 'package:pubspec_parse/pubspec_parse.dart';

import 'common.dart';

class CreateAllPluginsAppCommand extends PluginCommand {
  CreateAllPluginsAppCommand(Directory packagesDir) : super(packagesDir) {
    argParser.addMultiOption(
      excludeOption,
      abbr: 'e',
      help: 'Exclude packages from the generated pubspec.yaml.',
      defaultsTo: <String>[],
    );
  }

  static const String excludeOption = 'exclude';

  @override
  String get description =>
      'Generate `pubspec.yaml` that includes all plugins in packages';

  @override
  String get name => 'gen-pubspec';

  @override
  Future<Null> run() async {
    final int exitCode = await _createPlugin();
    if (exitCode != 0) {
      throw ToolExit(exitCode);
    }

    await Future.wait(<Future<void>>[
      _genPubspecWithAllPlugins(),
      _updateAppGradle(),
      _updateManifest(),
      _updateProjectGradle(),
    ]);
  }

  Future<int> _createPlugin() async {
    final ProcessResult result = Process.runSync(
      'flutter',
      <String>[
        'create',
        '--template=app',
        '--project-name=all_plugins',
        '--androidx',
        './all_plugins',
      ],
    );

    print(result.stdout);
    print(result.stderr);
    return result.exitCode;
  }

  Future<void> _updateProjectGradle() async {
    final File gradleFile = File(p.join(
      'all_plugins',
      'android',
      'build.gradle',
    ));
    if (!gradleFile.existsSync()) {
      throw ToolExit(64);
    }

    final String newGradle = gradleFile.readAsStringSync().replaceFirst(
          RegExp(r"classpath \'com.android.tools.build:gradle:\d.\d.\d\'"),
          'classpath \'com.android.tools.build:gradle:3.3.1\'',
        );
    gradleFile.writeAsStringSync(newGradle);
  }

  Future<void> _updateAppGradle() async {
    final File gradleFile = File(p.join(
      'all_plugins',
      'android',
      'app',
      'build.gradle',
    ));
    if (!gradleFile.existsSync()) {
      throw ToolExit(64);
    }

    final StringBuffer newGradle = StringBuffer();
    for (String line in gradleFile.readAsLinesSync()) {
      newGradle.writeln(line);
      if (line.contains('defaultConfig {')) {
        newGradle.writeln('        multiDexEnabled true');
      } else if (line.contains('dependencies {')) {
        newGradle.writeln(
          '    implementation \'com.google.guava:guava:27.0.1-android\'',
        );
      }
    }
    gradleFile.writeAsStringSync(newGradle.toString());
  }

  Future<void> _updateManifest() async {
    final File manifestFile = File(p.join(
      'all_plugins',
      'android',
      'app',
      'src',
      'main',
      'AndroidManifest.xml',
    ));
    if (!manifestFile.existsSync()) {
      throw ToolExit(64);
    }

    final StringBuffer newManifest = StringBuffer();
    for (String line in manifestFile.readAsLinesSync()) {
      if (line.contains('package="com.example.all_plugins"')) {
        newManifest
          ..writeln('package="com.example.all_plugins"')
          ..writeln('xmlns:tools="http://schemas.android.com/tools">')
          ..writeln()
          ..writeln(
            '<uses-sdk tools:overrideLibrary="io.flutter.plugins.camera"/>',
          );
      } else {
        newManifest.writeln(line);
      }
    }
    manifestFile.writeAsStringSync(newManifest.toString());
  }

  Future<void> _genPubspecWithAllPlugins() async {
    final Pubspec pubspec = Pubspec(
      'all_plugins',
      description: 'Flutter app containing all 1st party plugins.',
      version: Version.parse('1.0.0+1'),
      environment: <String, VersionConstraint>{
        'sdk': VersionConstraint.compatibleWith(
          Version.parse('2.0.0'),
        ),
      },
      dependencies: <String, Dependency>{
        'flutter': SdkDependency('flutter'),
      }..addAll(await _getValidPathDependencies()),
      devDependencies: <String, Dependency>{
        'flutter_test': SdkDependency('flutter'),
      },
    );

    final File pubspecFile = new File(p.join('all_plugins', 'pubspec.yaml'));
    pubspecFile.writeAsStringSync(_pubspecToString(pubspec));
  }

  Future<Map<String, PathDependency>> _getValidPathDependencies() async {
    final Map<String, PathDependency> pathDependencies =
        <String, PathDependency>{};

    await for (Directory package in getPlugins()) {
      final String pluginName = package.path.split('/').last;
      if (argResults[excludeOption].contains(pluginName)) {
        continue;
      }

      final File pubspecFile = File(p.join(package.path, 'pubspec.yaml'));
      final Pubspec pubspec = Pubspec.parse(pubspecFile.readAsStringSync());

      if (pubspec.publishTo != 'none') {
        pathDependencies[pluginName] = PathDependency(package.path);
      }
    }

    return pathDependencies;
  }

  String _pubspecToString(Pubspec pubspec) {
    return '''
### Generated file. Do not edit. Run `pub global run flutter_plugin_tools gen-pubspec` to update.
name: ${pubspec.name}
description: ${pubspec.description}

version: ${pubspec.version}

environment:${_pubspecMapString(pubspec.environment)}

dependencies:${_pubspecMapString(pubspec.dependencies)}

dev_dependencies:${_pubspecMapString(pubspec.devDependencies)}
###''';
  }

  String _pubspecMapString(Map<String, dynamic> values) {
    final StringBuffer buffer = StringBuffer();

    for (MapEntry<String, dynamic> entry in values.entries) {
      buffer.writeln();
      if (entry.value is VersionConstraint) {
        buffer.write('  ${entry.key}: ${entry.value}');
      } else if (entry.value is SdkDependency) {
        final SdkDependency dep = entry.value;
        buffer.write('  ${entry.key}: \n    sdk: ${dep.sdk}');
      } else if (entry.value is PathDependency) {
        final PathDependency dep = entry.value;
        buffer.write('  ${entry.key}: \n    path: ${dep.path}');
      } else {
        throw UnimplementedError(
          'Not available for type: ${entry.value.runtimeType}',
        );
      }
    }

    return buffer.toString();
  }
}
