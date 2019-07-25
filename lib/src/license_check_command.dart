import 'dart:async';
import 'dart:io';

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
      'Checks that all plugins correctly contains include licenses.\n'
      'This check enforces the following rules:\n'
      '1. Every plugin must contain a LICENSE file in root directory.\n'
      "2. Every LICENSE file must contain the string 'Flutter' or 'Chromium' in the first line.\n"
      '3. All code source files must contain a license header at the top.\n'
      '4. The license header for every source file must contain the same author name as the LICENSE file in the root directory.\n';

  bool _isAndroidFile(FileSystemEntity entity) =>
      entity is File && entity.path.endsWith('.java');

  bool _isDartFile(FileSystemEntity entity) =>
      entity is File &&
      !entity.path.endsWith('.g.dart') &&
      entity.path.endsWith('.dart');

  bool _isIosFile(FileSystemEntity entity) =>
      entity is File &&
      (entity.path.endsWith('.m') || entity.path.endsWith('.h'));

  Iterable<File> _getFilesWhere(
    Directory dir,
    bool Function(FileSystemEntity entity) where,
  ) {
    return dir
        .listSync(recursive: true, followLinks: false)
        .where(where)
        .cast<File>();
  }

  static const List<String> _validAuthorNames = const <String>[
    'Chromium',
    'Flutter',
  ];

  static List<RegExp> _getValidLicenses(String author) => <RegExp>[
        RegExp(r'// Copyright 2\d{3} The '
            '$author'
            r' Authors. All rights reserved.\s*\n'
            r'// Use of this source code is governed by a BSD-style license that can be\s*\n'
            r'// found in the LICENSE file.\s*\n'),
        RegExp(r'// Copyright 2\d{3}, the '
            '$author'
            r' project authors.  Please see the AUTHORS file\s*\n'
            r'// for details. All rights reserved. Use of this source code is governed by a\s*\n'
            r'// BSD-style license that can be found in the LICENSE file.\s*\n'),
        RegExp(r'// Copyright 2\d{3} The '
            '$author'
            r' Authors. All rights reserved.\s*\n'
            r'// Use of this source code is governed by a BSD-style\s*\n'
            r'// license that can be found in the LICENSE file.\s*\n'),
      ];

  static String _getLicenseHeader(String author) {
    final int year = DateTime.now().year;
    return '// Copyright $year The $author Authors. All rights reserved.\n'
        '// Use of this source code is governed by a BSD-style license that can be\n'
        '// found in the LICENSE file.\n';
  }

  static String _getLicenseFile(String author) {
    final int year = DateTime.now().year;
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

  void _outputNoLicenseError(List<Directory> pluginDirs, String license) {
    print('The following plugins don\'t contain a valid LICENSE file.\n');

    for (Directory dir in pluginDirs) {
      print(dir.path.split('/').last);
    }

    print(
        '\nPlease run `pub global run flutter_plugin_tools license-check --update`\n'
        'or add a LICENSE file containing: \n$license');
  }

  void _outputInvalidLicenseHeaderError(
      Directory pluginDir, List<File> files, String license) {
    print(
      'The ${pluginDir.path.split('/').last} plugin contains source files without a valid license header.',
    );

    print(
      'Please run `pub global run flutter_plugin_tools license-check --update`\n'
      'or add the following license to the beginning of each file below: \n\n$license',
    );

    for (File file in files) {
      print(file.path);
    }

    print('-' * 50);
  }

  void _updateLicenseHeaders(List<File> files, String license) {
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

  String _parseAuthor(String string) {
    for (String name in _validAuthorNames) {
      if (string.contains(name)) {
        return name;
      }
    }

    return null;
  }

  @override
  Future<Null> run() async {
    checkSharding();

    final List<Directory> pluginsWithoutLicenseFile = <Directory>[];
    bool fail = false;
    await for (Directory pluginDir in getPlugins()) {
      final List<File> pluginFiles = <File>[];

      final File licenseFile = File(path.join(pluginDir.path, 'LICENSE'));
      if (!licenseFile.existsSync()) {
        pluginsWithoutLicenseFile.add(pluginDir);
        continue;
      }

      final String topLicenseLine = licenseFile.readAsLinesSync()[0];
      final String author = _parseAuthor(topLicenseLine);

      if (author == null) {
        pluginsWithoutLicenseFile.add(pluginDir);
        continue;
      }

      final Directory androidDir =
          Directory(path.join(pluginDir.path, 'android'));
      final Directory iosDir = Directory(path.join(pluginDir.path, 'ios'));
      final Directory dartDir = Directory(path.join(pluginDir.path, 'lib'));
      final Directory testDir = Directory(path.join(pluginDir.path, 'test'));
      final Directory exampleDir = Directory(
        path.join(pluginDir.path, 'example/lib'),
      );

      pluginFiles.addAll(_getFilesWhere(androidDir, _isAndroidFile));
      pluginFiles.addAll(_getFilesWhere(iosDir, _isIosFile));
      pluginFiles.addAll(_getFilesWhere(dartDir, _isDartFile));
      pluginFiles.addAll(_getFilesWhere(exampleDir, _isDartFile));
      if (testDir.existsSync()) {
        pluginFiles.addAll(_getFilesWhere(testDir, _isDartFile));
      }

      final List<File> filesWithoutValidHeader = <File>[];
      for (File file in pluginFiles) {
        final bool hasValidLicense = _getValidLicenses(author).any(
          (RegExp reg) => file.readAsStringSync().startsWith(reg),
        );

        if (!hasValidLicense) {
          filesWithoutValidHeader.add(file);
        }
      }

      if (filesWithoutValidHeader.isNotEmpty) {
        fail = true;
        if (argResults['print']) {
          _outputInvalidLicenseHeaderError(
            pluginDir,
            filesWithoutValidHeader,
            _getLicenseHeader(author),
          );
        }

        if (argResults['update']) {
          _updateLicenseHeaders(
            filesWithoutValidHeader,
            _getLicenseHeader(author),
          );
        }
      }
    }

    if (pluginsWithoutLicenseFile.isNotEmpty) {
      if (argResults['print']) {
        _outputNoLicenseError(
          pluginsWithoutLicenseFile,
          _getLicenseFile('Flutter'),
        );
      }

      if (argResults['update']) {
        for (Directory dir in pluginsWithoutLicenseFile) {
          final File licenseFile = File(path.join(dir.path, 'LICENSE'));
          licenseFile.writeAsStringSync(_getLicenseFile('Flutter'));
        }
      }
    }

    if (pluginsWithoutLicenseFile.isNotEmpty || fail) {
      throw ToolExit(1);
    }

    print('All required files contain licenses!');
  }
}
