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
      'Checks that all plugin java/dart/.m files include license at the top of the file.';

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
        RegExp(r'// Copyright 2\d{3} The '
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
        '// found in the LICENSE file.\n\n';
  }

  static String _getLicenseFile(String author) {
    final int year = DateTime.now().year;
    return '// Copyright $year The $author Authors. All rights reserved.'
        '//'
        '// Redistribution and use in source and binary forms, with or without'
        '// modification, are permitted provided that the following conditions are'
        '// met:'
        '//'
        '//    * Redistributions of source code must retain the above copyright'
        '// notice, this list of conditions and the following disclaimer.'
        '//    * Redistributions in binary form must reproduce the above'
        '// copyright notice, this list of conditions and the following disclaimer'
        '// in the documentation and/or other materials provided with the'
        '// distribution.'
        '//    * Neither the name of Google Inc. nor the names of its'
        '// contributors may be used to endorse or promote products derived from'
        '// this software without specific prior written permission.'
        '//'
        '// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS'
        '// "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT'
        '// LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR'
        '// A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT'
        '// OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,'
        '// SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT'
        '// LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,'
        '// DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY'
        '// THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT'
        '// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE'
        '// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.';
  }

  void _outputNoLicenseError(List<Directory> pluginDirs, String license) {
    print('The following plugins don\'t contain a valid LICENSE file.');

    for (Directory dir in pluginDirs) {
      print(dir.path);
    }

    print(
        'Please run `pub global run flutter_plugin_tools license-check --update`\n'
        'or add a LICENSE file containing: \n$license');
  }

  void _outputInvalidLicenseHeaderError(
      Directory pluginDir, List<File> files, String license) {
    print(
      'The ${pluginDir.path.split('/').last} plugin contains source files without a valid license header.',
    );

    print(
      'Please run `pub global run flutter_plugin_tools license-check --update`\n'
      'or add the following license to the beginning of each file below: \n$license',
    );

    for (File file in files) {
      print(file.path);
    }
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
    final List<String> validNames = <String>['Chromium', 'Flutter'];

    for (String name in validNames) {
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
        if (argResults['print']) {
          _outputInvalidLicenseHeaderError(
            pluginDir,
            filesWithoutValidHeader,
            _getLicenseHeader('author'),
          );
        }

        if (argResults['update']) {
          _updateLicenseHeaders(
            filesWithoutValidHeader,
            _getLicenseHeader('author'),
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

    print('All required files contain licenses!');
  }
}
