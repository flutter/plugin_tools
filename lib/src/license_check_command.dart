// Copyright 2019 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:colorize/colorize.dart';
import 'package:path/path.dart' as path;

import 'common.dart';

class LicenseCheckCommand extends PluginCommand {
  LicenseCheckCommand(Directory packagesDir) : super(packagesDir) {
    argParser.addFlag(
      'print',
      help: 'Print out files without a valid license.',
    );
    argParser.addFlag(
      'update',
      help: 'Update all files without a valid license.',
    );
  }

  @override
  final String name = 'license-check';

  @override
  final String description =
      'Tests whether all plugins correctly include licenses.\n\n'
      'This command will have a non-zero exit code if all plugins don\'t contain licenses with the following rules:\n'
      '1. Every plugin must contain a LICENSE file in the root directory.\n'
      '2. Every LICENSE file must contain the copyright license with \'Flutter\' or \'Chromium\' as the author.\n'
      '3. All source code files must contain a license header at the top.\n'
      '4. The license header for every source file must contain the same author name as the LICENSE file in the plugin root directory.\n\n';

  static Iterable<File> _filterSourceCodeFiles(Directory dir) {
    // We don't add licenses to files with `.g.dart` because they are generated and don't require one.
    return dir
        .listSync(recursive: true, followLinks: false)
        .where((FileSystemEntity entity) => entity is File)
        .where((FileSystemEntity entity) =>
            entity.path.endsWith('.m') ||
            entity.path.endsWith('.h') ||
            entity.path.endsWith('.mm') ||
            entity.path.endsWith('.java') ||
            entity.path.endsWith('.dart') && !entity.path.endsWith('.g.dart'))
        .cast<File>();
  }

  static const List<String> _validAuthorNames = const <String>[
    'Chromium',
    'Flutter',
  ];

  static List<RegExp> _getValidLicenses(String author) => <RegExp>[
        RegExp(
            r'// Copyright 2\d{3} The '
            '$author '
            r'Authors. All rights reserved.\s*.'
            r'// Use of this source code is governed by a BSD-style license that can be\s*.'
            r'// found in the LICENSE file.\s*.',
            multiLine: true,
            dotAll: true),
        RegExp(
            r'// Copyright 2\d{3}, the '
            '$author '
            r'project authors.  Please see the AUTHORS file\s*.'
            r'// for details. All rights reserved. Use of this source code is governed by a\s*.'
            r'// BSD-style license that can be found in the LICENSE file.\s*.',
            multiLine: true,
            dotAll: true),
        RegExp(
            r'// Copyright 2\d{3} The '
            '$author '
            r'Authors. All rights reserved.\s*.'
            r'// Use of this source code is governed by a BSD-style\s*.'
            r'// license that can be found in the LICENSE file.\s*.',
            multiLine: true,
            dotAll: true),
      ];

  static String _getLicenseHeader(String author) {
    final int year = DateTime.now().year;
    return '// Copyright $year The $author Authors. All rights reserved.\n'
        '// Use of this source code is governed by a BSD-style license that can be\n'
        '// found in the LICENSE file.\n';
  }

  static String _getLicenseFile(String year, String author) {
    return '// Copyright $year The $author Authors. All rights reserved.\n'
        '//\n'
        '// Redistribution and use in source and binary forms, with or without\n'
        '// modification, are permitted provided that the following conditions are\n'
        '// met:\n'
        '//\n'
        '//    * Redistributions of source code must retain the above copyright\n'
        '// notice, this list of conditions and the following disclaimer.\n'
        '//    * Redistributions in binary form must reproduce the above\n'
        '// copyright notice, this list of conditions and the following disclaimer\n'
        '// in the documentation and/or other materials provided with the\n'
        '// distribution.\n'
        '//    * Neither the name of Google Inc. nor the names of its\n'
        '// contributors may be used to endorse or promote products derived from\n'
        '// this software without specific prior written permission.\n'
        '//\n'
        '// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS\n'
        '// "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT\n'
        '// LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR\n'
        '// A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT\n'
        '// OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,\n'
        '// SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT\n'
        '// LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,\n'
        '// DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY\n'
        '// THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT\n'
        '// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE\n'
        '// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.\n';
  }

  static String _noLicenseError(Directory pluginDir, String license) {
    return 'The following plugin doesn\'t contain a LICENSE file.\n'
        '${pluginDir.path}\n\n'
        'Please run `pub global run flutter_plugin_tools license-check --update`\n'
        'or add a LICENSE file containing: \n$license';
  }

  static String _invalidAuthorError(Directory pluginDir, String license) {
    return 'The following plugin doesn\'t contain a valid author (${_validAuthorNames.join(' or ')}) in the LICENSE file.\n'
        '${pluginDir.path}\n\n'
        'To create a valid license file, please run `pub global run flutter_plugin_tools license-check --update`\n'
        'or add a LICENSE file containing: \n$license';
  }

  static String _invalidLicenseError(Directory pluginDir, String license) {
    return 'The following plugin doesn\'t contain a valid license in the root LICENSE file.\n'
        '${pluginDir.path}\n\n'
        'To create a valid license file, please run `pub global run flutter_plugin_tools license-check --update`\n'
        'or add a LICENSE file containing: \n$license';
  }

  static void _outputInvalidLicenseHeaderError(
    Directory pluginDir,
    List<File> files,
    String license,
  ) {
    print(
      'The following plugin contains source files without a valid license header.\n'
      '${pluginDir.path.split('/').last}\n\n'
      'Please run `pub global run flutter_plugin_tools license-check --update`\n'
      'or add the following license to the beginning of each file below: \n\n$license',
    );

    for (File file in files) {
      print(file.path);
    }

    print('-' * 50);
  }

  static void _updateLicenseHeaders(List<File> files, String license) {
    for (File file in files) {
      final List<RegExp> licenses = _getValidLicenses('(Flutter|Chromium)');

      final bool hasALicense = licenses.any(
        (RegExp reg) => file.readAsStringSync().startsWith(reg),
      );

      if (hasALicense) {
        final StringBuffer buffer = StringBuffer();
        buffer.write(license);

        final List<String> lines = file.readAsLinesSync();
        for (int i = 3; i < lines.length; i++) {
          buffer.writeln(lines[i]);
        }

        file.writeAsStringSync(buffer.toString());
      } else {
        file.writeAsStringSync('$license\n${file.readAsStringSync()}');
      }
    }
  }

  static String _parseAuthor(File licenseFile) {
    if (!licenseFile.existsSync()) {
      return null;
    }

    final RegExp copyright = RegExp(r'Copyright 2\d{3}');

    for (String line in licenseFile.readAsLinesSync()) {
      if (line.contains(copyright)) {
        for (String name in _validAuthorNames) {
          if (line.contains(name)) {
            return name;
          }
        }
      }
    }

    return null;
  }

  static List<File> _getSourceCodeFiles(Directory pluginDir) {
    final List<File> sourceCodeFiles = <File>[];

    final Directory androidDir = Directory(
      path.join(pluginDir.path, 'android'),
    );
    final Directory iosDir = Directory(path.join(pluginDir.path, 'ios'));
    final Directory dartDir = Directory(path.join(pluginDir.path, 'lib'));
    final Directory testDir = Directory(path.join(pluginDir.path, 'test'));
    final Directory exampleDir = Directory(
      path.join(pluginDir.path, 'example/lib'),
    );

    if (androidDir.existsSync()) {
      sourceCodeFiles.addAll(_filterSourceCodeFiles(androidDir));
    }

    if (iosDir.existsSync()) {
      sourceCodeFiles.addAll(_filterSourceCodeFiles(iosDir));
    }

    if (testDir.existsSync()) {
      sourceCodeFiles.addAll(_filterSourceCodeFiles(testDir));
    }

    sourceCodeFiles.addAll(_filterSourceCodeFiles(dartDir));
    sourceCodeFiles.addAll(_filterSourceCodeFiles(exampleDir));

    return sourceCodeFiles;
  }

  // Returns whether root license is valid.
  bool _validateOrUpdateRootLicense(File licenseFile) {
    final RegExp validLicenseFilePattern = RegExp(
        _getLicenseFile(
          r'2\d{3}',
          '__author__',
        )
            .replaceAll('(', r'\(')
            .replaceAll(')', r'\)')
            .replaceAll('*', r'\*')
            .replaceAll('\n', '.')
            .replaceAll('__author__', '(${_validAuthorNames.join('|')})'),
        multiLine: true,
        dotAll: true);

    final String licenseFileAsString =
        licenseFile.existsSync() ? licenseFile.readAsStringSync() : null;

    if (licenseFile.existsSync() &&
        licenseFileAsString.contains(validLicenseFilePattern) &&
        _parseAuthor(licenseFile) != null) {
      return true;
    }

    final String validLicenseFile = _getLicenseFile(
      DateTime.now().year.toString(),
      'Flutter',
    );
    final bool outputError = argResults['print'];

    if (outputError && !licenseFile.existsSync()) {
      print(_noLicenseError(licenseFile.parent, validLicenseFile));
    } else if (outputError &&
        !licenseFileAsString.contains(validLicenseFilePattern)) {
      print(_invalidLicenseError(licenseFile.parent, validLicenseFile));
    } else if (outputError && _parseAuthor(licenseFile) == null) {
      print(_invalidAuthorError(licenseFile.parent, validLicenseFile));
    }

    if (argResults['update']) {
      licenseFile.writeAsStringSync(validLicenseFile);
    }

    return false;
  }

  // Returns whether all license headers are valid.
  bool _validateOrUpdateLicenseHeaders(Directory pluginDir, String author) {
    final List<RegExp> validLicenses = _getValidLicenses(author);

    final List<File> filesWithoutValidHeader = <File>[];
    for (File file in _getSourceCodeFiles(pluginDir)) {
      final bool hasValidLicense = validLicenses.any(
        (RegExp reg) => file.readAsStringSync().startsWith(reg),
      );

      if (!hasValidLicense) {
        filesWithoutValidHeader.add(file);
      }
    }

    if (filesWithoutValidHeader.isEmpty) {
      return true;
    }

    if (argResults['print']) {
      _outputInvalidLicenseHeaderError(
        pluginDir,
        filesWithoutValidHeader,
        _getLicenseHeader(author),
      );
    }

    if (argResults['update']) {
      _updateLicenseHeaders(filesWithoutValidHeader, _getLicenseHeader(author));
    }

    return false;
  }

  @override
  Future<Null> run() async {
    checkSharding();

    bool fail = false;
    await for (Directory pluginDir in getPlugins()) {
      final File licenseFile = File(path.join(pluginDir.path, 'LICENSE'));
      final String author = _parseAuthor(licenseFile) ?? 'Flutter';

      final bool hasValidRootLicense =
          _validateOrUpdateRootLicense(licenseFile);
      final bool hasValidLicenseHeaders =
          _validateOrUpdateLicenseHeaders(pluginDir, author);

      if (!hasValidRootLicense || !hasValidLicenseHeaders) {
        fail = true;
      }
    }

    if (fail && !argResults['update']) {
      throw ToolExit(64);
    } else if (!fail) {
      print(Colorize('All required files contain licenses!')..green());
    }
  }
}
