import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as path;

import 'common.dart';

class LicenseCheckCommand extends PluginCommand {
  LicenseCheckCommand(Directory packagesDir) : super(packagesDir);

  // Update _license when this is updated.
  static final RegExp _licenseRegExp = RegExp(
    r'// Copyright 2\d{3} The Chromium Authors. All rights reserved.\n'
    r'// Use of this source code is governed by a BSD-style license that can be\n'
    r'// found in the LICENSE file.\n',
  );

  // Update _licenseRegExp when this is updated.
  static String get _license {
    final int year = DateTime.now().year;
    return '// Copyright $year The Chromium Authors. All rights reserved.\n'
        '// Use of this source code is governed by a BSD-style license that can be\n'
        '// found in the LICENSE file.\n';
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
      print('Some files don\'t contain a license.');
      print(
        'Please add the following license to the beginning of each file below: \n$_license',
      );
      for (File file in failingFiles) {
        print(file.path);
      }
      throw new ToolExit(1);
    }

    print('All required files contain liscenses!');
  }
}
