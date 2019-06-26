// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';
import 'package:pubspec_parse/pubspec_parse.dart';

import 'common.dart';

class GenPubspecCommand extends PluginCommand {
  GenPubspecCommand(Directory packagesDir) : super(packagesDir);

  static const List<String> _excludedPackages = <String>['firebase_core'];

  @override
  String get description =>
      'Generate `pubspec.yaml` that includes all plugins in packages';

  @override
  String get name => 'gen-pubspec';

  @override
  Future<Null> run() async {
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

    final File pubspecFile =
        new File(p.join(getAllPluginsApp().path, 'pubspec.yaml'));
    pubspecFile.writeAsStringSync(_pubspecToString(pubspec));
  }

  Future<Map<String, PathDependency>> _getValidPathDependencies() async {
    final Map<String, PathDependency> pathDependencies =
        <String, PathDependency>{};

    await for (Directory package in getPlugins()) {
      final String pluginName = package.path.split('/').last;
      if (_excludedPackages.contains(pluginName)) {
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
