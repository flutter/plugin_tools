// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import 'common.dart';

class BuildExamplesCommand extends Command<Null> {
  BuildExamplesCommand(this.packagesDir) {
    argParser.addFlag('ipa', defaultsTo: Platform.isMacOS);
    argParser.addFlag('apk');
  }

  final Directory packagesDir;

  @override
  final String name = 'build-examples';

  @override
  final String description = 'Builds all example apps.';

  @override
  Future<Null> run() async {
    final List<String> failingPackages = <String>[];
    for (_ExamplePackage examplePackage in _getExamplePackages(packagesDir)) {
      final Directory dir = examplePackage.packageDir;
      final String packageName = p.relative(dir.path, from: packagesDir.path);

      if (argResults['ipa'] && examplePackage.hasiOS) {
        print('\nBUILDING IPA for $packageName');
        final int exitCode = await runAndStream(
            'flutter', <String>['build', 'ios', '--no-codesign'], dir);
        if (exitCode != 0) {
          failingPackages.add('$packageName (ipa)');
        }
      }

      if (argResults['apk'] && examplePackage.hasAndroid) {
        print('\nBUILDING APK for $packageName');
        final int exitCode =
            await runAndStream('flutter', <String>['build', 'apk'], dir);
        if (exitCode != 0) {
          failingPackages.add('$packageName (apk)');
        }
      }
    }

    print('\n\n');

    if (failingPackages.isNotEmpty) {
      print('The following build are failing (see above for details):');
      for (String package in failingPackages) {
        print(' * $package');
      }
      throw new ToolExit(1);
    }

    print('All builds successful!');
  }

  Iterable<_ExamplePackage> _getExamplePackages(Directory dir) {
    return dir
        .listSync(recursive: true)
        .where((FileSystemEntity entity) =>
            entity is Directory && p.basename(entity.path) == 'example')
        .where((FileSystemEntity entity) {
      final Directory dir = entity;
      return dir.listSync().any((FileSystemEntity entity) =>
          entity is File && p.basename(entity.path) == 'pubspec.yaml');
    }).map((FileSystemEntity entity) {
      final Directory dir = entity;
      final List<FileSystemEntity> contents = dir.listSync();
      return new _ExamplePackage(
        packageDir: dir,
        hasiOS: contents.any((FileSystemEntity entity) =>
            entity is Directory && p.basename(entity.path) == 'ios'),
        hasAndroid: contents.any((FileSystemEntity entity) =>
            entity is Directory && p.basename(entity.path) == 'android'),
      );
    });
  }
}

class _ExamplePackage {
  final Directory packageDir;
  final bool hasiOS;
  final bool hasAndroid;

  _ExamplePackage({this.packageDir, this.hasiOS, this.hasAndroid});
}
