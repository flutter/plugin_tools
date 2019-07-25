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

  static final RegExp _licenseRegExp = RegExp(
      r'// Copyright 2017 The Chromium Authors. All rights reserved.\n'
      r'// Use of this source code is governed by a BSD-style license that can be\n'
      r'// found in the LICENSE file.\n');

  static final String _license =
      '// Copyright 2017 The Chromium Authors. All rights reserved.\n'
      '// Use of this source code is governed by a BSD-style license that can be\n'
      '// found in the LICENSE file.\n';

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

  void printFiles(List<File> files) {
    print('Some files don\'t contain a license.');
    print(
      'Please add the following license to the beginning of each file below: \n$_license',
    );

    for (File file in files) {
      print(file.path);
    }
  }

  void update(List<File> files) {
    for (File file in files) {
      final List<RegExp> licenseRegExps = <RegExp>[
        RegExp(
            r'// Copyright 2\d{3} The (Flutter|Chromium) Authors. All rights reserved.\s*\n'
            r'// Use of this source code is governed by a BSD-style license that can be\s*\n'
            r'// found in the LICENSE file.\s*\n'),
        RegExp(
            r'// Copyright 2\d{3}, the (Flutter|Chromium) project authors.  Please see the AUTHORS file\s*\n'
            r'// for details. All rights reserved. Use of this source code is governed by a\s*\n'
            r'// BSD-style license that can be found in the LICENSE file.\s*\n'),
        RegExp(
            r'// Copyright 2\d{3} The (Flutter|Chromium) Authors. All rights reserved.\s*\n'
            r'// Use of this source code is governed by a BSD-style\s*\n'
            r'// license that can be found in the LICENSE file.\s*\n'),
      ];

      final bool hasALicense = licenseRegExps.any(
        (RegExp reg) => file.readAsStringSync().startsWith(reg),
      );

      if (hasALicense) {
        final StringBuffer buffer = StringBuffer();
        buffer.write(_license);

        final List<String> lines = file.readAsLinesSync();
        for (int i = 3; i < lines.length; i++) {
          buffer.writeln(lines[i]);
        }

        file.writeAsStringSync(buffer.toString());
      } else {
        file.writeAsStringSync('$_license\n${file.readAsStringSync()}');
      }
    }
  }

  @override
  Future<Null> run() async {
    checkSharding();

    final List<File> failingFiles = <File>[];
    await for (Directory plugin in getPlugins()) {
      final List<File> pluginFiles = <File>[];

      final Directory androidDir = Directory(path.join(plugin.path, 'android'));
      final Directory iosDir = Directory(path.join(plugin.path, 'ios'));
      final Directory dartDir = Directory(path.join(plugin.path, 'lib'));
      final Directory testDir = Directory(path.join(plugin.path, 'test'));
      final Directory exampleDir = Directory(
        path.join(plugin.path, 'example/lib'),
      );

      pluginFiles.addAll(_getFilesWhere(androidDir, _isAndroidFile));
      pluginFiles.addAll(_getFilesWhere(iosDir, _isIosFile));
      pluginFiles.addAll(_getFilesWhere(dartDir, _isDartFile));
      pluginFiles.addAll(_getFilesWhere(exampleDir, _isDartFile));
      if (testDir.existsSync()) {
        pluginFiles.addAll(_getFilesWhere(testDir, _isDartFile));
      }

      for (File file in pluginFiles) {
        if (!file.readAsStringSync().startsWith(_licenseRegExp)) {
          failingFiles.add(file);
        }
      }
    }

    if (failingFiles.isNotEmpty) {
      if (argResults['print']) {
        printFiles(failingFiles);
      }
      if (argResults['update']) {
        update(failingFiles);
      }

      throw new ToolExit(1);
    }

    print('All required files contain licenses!');
  }
}
