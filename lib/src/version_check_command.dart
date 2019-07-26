// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:meta/meta.dart';
import 'package:colorize/colorize.dart';
import 'package:git/git.dart';
import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';
import 'package:pubspec_parse/pubspec_parse.dart';
import 'package:yaml/yaml.dart';

import 'common.dart';

const String _kBaseSha = 'base_sha';

class GitVersionFinder {
  GitVersionFinder(this.baseGitDir, this.baseSha);

  final GitDir baseGitDir;
  final String baseSha;

  static bool isPubspec(String file) {
    return p.basename(file) == 'pubspec.yaml';
  }

  static bool isChangeLog(String file) {
    return p.basename(file) == 'CHANGELOG.md';
  }

  Future<List<String>> getChangedPubSpecs() async {
    final ProcessResult changedFilesCommand = await baseGitDir
        .runCommand(<String>['diff', '--name-only', '$baseSha']);
    final List<String> changedFiles =
        changedFilesCommand.stdout.toString().split('\n');
    return changedFiles.where(isPubspec).toList();
  }

  Future<List<String>> getChangedChangeLogs() async {
    final ProcessResult changedFilesCommand = await baseGitDir
        .runCommand(<String>['diff', '--name-only', '$baseSha']);
    final List<String> changedFiles =
    changedFilesCommand.stdout.toString().split('\n');
    return changedFiles.where(isChangeLog).toList();
  }

  Future<Version> getPackageVersion(String pubspecPath, String gitRef) async {
    final ProcessResult gitShow =
        await baseGitDir.runCommand(<String>['show', '$gitRef:$pubspecPath']);
    final String fileContent = gitShow.stdout;
    final String versionString = loadYaml(fileContent)['version'];
    return versionString == null ? null : Version.parse(versionString);
  }
}

enum NextVersionType {
  BREAKING_MAJOR,
  MINOR,
  PATCH,
  RELEASE,
}

@visibleForTesting
Map<Version, NextVersionType> getAllowedNextVersions(
    Version masterVersion, Version headVersion) {
  final Map<Version, NextVersionType> allowedNextVersions =
      <Version, NextVersionType>{
    masterVersion.nextMajor: NextVersionType.BREAKING_MAJOR,
    masterVersion.nextMinor: NextVersionType.MINOR,
    masterVersion.nextPatch: NextVersionType.PATCH,
  };

  if (masterVersion.major < 1 && headVersion.major < 1) {
    int nextBuildNumber = -1;
    if (masterVersion.build.isEmpty) {
      nextBuildNumber = 1;
    } else {
      final int currentBuildNumber = masterVersion.build.first;
      nextBuildNumber = currentBuildNumber + 1;
    }
    final Version preReleaseVersion = Version(
      masterVersion.major,
      masterVersion.minor,
      masterVersion.patch,
      build: nextBuildNumber.toString(),
    );
    allowedNextVersions.clear();
    allowedNextVersions[masterVersion.nextMajor] = NextVersionType.RELEASE;
    allowedNextVersions[masterVersion.nextMinor] =
        NextVersionType.BREAKING_MAJOR;
    allowedNextVersions[masterVersion.nextPatch] = NextVersionType.MINOR;
    allowedNextVersions[preReleaseVersion] = NextVersionType.PATCH;
  }
  return allowedNextVersions;
}

class VersionCheckCommand extends PluginCommand {
  VersionCheckCommand(Directory packagesDir) : super(packagesDir) {
    argParser.addOption(_kBaseSha);
  }

  @override
  final String name = 'version-check';

  @override
  final String description =
      'Checks if the versions of the plugins have been incremented per pub specification and match CHANGELOG.md..\n\n'
      'This command requires "pub" and "flutter" to be in your path.';

  void _validateChangelog(String changelogPath, Version headVersion) async {
    if (headVersion == null)
      return;
    final String firstLine = await File(changelogPath).readAsLinesSync().first;
    if (firstLine != "## $headVersion") {
      final String error =
          'First line of CHANGELOG.md does not match version in pubspec.yaml.\n'
          'Found: ${firstLine}\n'
          'Expected: ## $headVersion';
      final Colorize redError = Colorize(error)
        ..red();
      print(redError);
      throw new ToolExit(1);
    }
  }

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

    final List<String> changedChangelogs =
        await gitVersionFinder.getChangedChangeLogs();

    final List<String> changedPubspecs =
        await gitVersionFinder.getChangedPubSpecs();

    for (final String pubspecPath in changedPubspecs) {
      try {
        final File pubspecFile = File(pubspecPath);
        final Pubspec pubspec = Pubspec.parse(pubspecFile.readAsStringSync());

        if (pubspec.publishTo == 'none') {
          continue;
        }

        final Version masterVersion =
            await gitVersionFinder.getPackageVersion(pubspecPath, baseSha);
        final Version headVersion =
            await gitVersionFinder.getPackageVersion(pubspecPath, 'HEAD');
        if (headVersion == null) {
          continue; // Example apps don't have versions
        }

        final Map<Version, NextVersionType> allowedNextVersions =
            getAllowedNextVersions(masterVersion, headVersion);

        if (!allowedNextVersions.containsKey(headVersion)) {
          final String error = '$pubspecPath incorrectly updated version.\n'
              'HEAD: $headVersion, master: $masterVersion.\n'
              'Allowed versions: $allowedNextVersions';
          final Colorize redError = Colorize(error)..red();
          print(redError);
          throw new ToolExit(1);
        }

        _validateChangelog(
            p.join(p.dirname(pubspecPath), 'CHANGELOG.md'),
            headVersion
        );
      } on ProcessException {
        print('Unable to find pubspec in master for $pubspecPath.'
            ' Safe to ignore if the project is new.');
      }
    }

    // Find changelog changes where the pubspec.yaml hasn't changed and ensure
    // that the versions still match.
    for (final String changelogPath in changedChangelogs) {
      String pubspecPath = p.join(p.dirname(changelogPath), 'pubspec.yaml');
      final Version headVersion =
          await gitVersionFinder.getPackageVersion(pubspecPath, 'HEAD');
      _validateChangelog(changelogPath, headVersion);
    }

    print('No version check errors found!');
  }
}
