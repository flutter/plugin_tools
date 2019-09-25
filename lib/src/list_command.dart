// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:file/file.dart' as fs;

import 'common.dart';

class ListCommand extends PluginCommand {
  ListCommand(fs.Directory packagesDir, fs.FileSystem fileSystem)
      : super(packagesDir, fileSystem) {
    argParser.addOption(
      _type,
      defaultsTo: _plugin,
      allowed: <String>[_plugin, _example, _package, _file],
      help: 'What type of file system content to list.',
    );
  }

  static const String _type = 'type';
  static const String _plugin = 'plugin';
  static const String _example = 'example';
  static const String _package = 'package';
  static const String _file = 'file';

  @override
  final String name = 'list';

  @override
  final String description = 'Lists packages or files';

  @override
  Future<Null> run() async {
    checkSharding();
    switch (argResults[_type]) {
      case _plugin:
        await for (fs.Directory package in getPlugins()) {
          print(package.path);
        }
        break;
      case _example:
        await for (fs.Directory package in getExamples()) {
          print(package.path);
        }
        break;
      case _package:
        await for (fs.Directory package in getPackages()) {
          print(package.path);
        }
        break;
      case _file:
        await for (fs.File file in getFiles()) {
          print(file.path);
        }
        break;
    }
  }
}
