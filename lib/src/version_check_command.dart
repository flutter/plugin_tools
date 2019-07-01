// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:colorize/colorize.dart';
import 'package:git/git.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:yaml/yaml.dart';

import 'common.dart';

const String _kBaseSha = 'base_sha';

class GitVersionFinder {
  GitVersionFinder(this.baseGitDir, this.baseSha);

  final GitDir baseGitDir;
  final String baseSha;

  static bool isPubspec(String file) {
    return file.trim().endsWith('pubspec.yaml');
  }

  Future<List<String>> getChangedPubSpecs() async {
    final ProcessResult changedFilesCommand = await baseGitDir
        .runCommand(<String>['diff', '--name-only', '$baseSha']);
    final List<String> changedFiles =
        changedFilesCommand.stdout.toString().split('\n');
    return changedFiles.where(isPubspec).toList();
  }

  Future<Version> getPackageVersion(String pubspecPath, String gitRef) async {
    final ProcessResult gitShow =
        await baseGitDir.runCommand(<String>['show', '$gitRef:$pubspecPath']);
    final String fileContent = gitShow.stdout;
    final String versionString = loadYaml(fileContent)['version'];
    return Version.parse(versionString);
  }
}

class VersionCheckCommand extends PluginCommand {
  VersionCheckCommand(Directory packagesDir) : super(packagesDir) {
    argParser.addOption(_kBaseSha);
  }

  @override
  final String name = 'version-check';

  @override
  final String description =
      'Checks if the versions of the plugins have been incremented per pub specification.\n\n'
      'This command requires "pub" and "flutter" to be in your path.';

  @override
  Future<Null> run() async {
    checkSharding();

    final String rootDir = packagesDir.parent.absolute.path;
    final String baseSha = argResults[_kBaseSha];

    if (!await GitDir.isGitDir(rootDir)) {
      print('$rootDir is not a valid Git repository.');
      throw new ToolExit(2);
    }

    final GitDir baseGitDir = await GitDir.fromExisting(rootDir);
    final GitVersionFinder gitVersionFinder =
        GitVersionFinder(baseGitDir, baseSha);

    final List<String> changedPubspecs =
        await gitVersionFinder.getChangedPubSpecs();

    for (final String pubspecPath in changedPubspecs) {
      try {
        final Version masterVersion =
            await gitVersionFinder.getPackageVersion(pubspecPath, baseSha);
        final Version headVersion =
            await gitVersionFinder.getPackageVersion(pubspecPath, 'HEAD');

        final Map<Version, String> allowedNextVersions = <Version, String>{
          masterVersion.nextBreaking: "BREAKING",
          masterVersion.nextMajor: "MAJOR",
          masterVersion.nextMinor: "MINOR",
          masterVersion.nextPatch: "PATCH",
        };

        if (masterVersion.major < 1 && headVersion.major < 1) {
          int nextBuildNumber = -1;
          if (masterVersion.build.isEmpty) {
            nextBuildNumber = 1;
          } else {
            final String currentBuildNumber = masterVersion.build.first;
            nextBuildNumber = int.parse(currentBuildNumber) + 1;
          }
          final Version preReleaseVersion = Version(
            masterVersion.major,
            masterVersion.minor,
            masterVersion.patch,
            build: nextBuildNumber.toString(),
          );
          allowedNextVersions[preReleaseVersion] = "PRE-1.0-PATCH";
        }

        if (!allowedNextVersions.containsKey(headVersion)) {
          final String error = '$pubspecPath incorrectly updated version.\n'
              'HEAD: $headVersion, master: $masterVersion.\n'
              'Allowed versions: $allowedNextVersions';
          final Colorize redError = Colorize(error)..red();
          print(redError);
          throw new ToolExit(1);
        }
      } on ProcessException {
        print('Unable to find pubspec in master for $pubspecPath.'
            ' Safe to ignore if the project is new.');
      }
    }

    print('No version check errors found!');
  }
}
