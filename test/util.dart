import 'dart:async';
import 'dart:io' as io;

import 'package:args/command_runner.dart';
import 'package:file/file.dart';
import 'package:file/memory.dart';

final FileSystem mockFileSystem = MemoryFileSystem();
Directory mockPackagesDir;

/// Creates a mock packages directory in the mock file system.
void initializeFakePackages() {
  mockPackagesDir = mockFileSystem.currentDirectory.childDirectory('packages');
  mockPackagesDir.createSync();
}

/// Creates a plugin package with the given [name] under the mock packages
/// directory.
void createFakePlugin(
  String name, {
  bool withSingleExample: false,
  List<String> withExamples: const <String>[],
}) {
  assert(!(withSingleExample && withExamples.isNotEmpty),
      'cannot pass withSingleExample and withExamples simultaneously');

  final Directory pluginDirectory = mockPackagesDir.childDirectory(name)
    ..createSync();
  createFakePubspec(pluginDirectory);

  if (withSingleExample) {
    final Directory exampleDir = pluginDirectory.childDirectory('example')
      ..createSync();
    createFakePubspec(exampleDir);
  } else if (withExamples.isNotEmpty) {
    final Directory exampleDir = pluginDirectory.childDirectory('example')
      ..createSync();
    for (String example in withExamples) {
      final Directory currentExample = exampleDir.childDirectory(example)
        ..createSync();
      createFakePubspec(currentExample);
    }
  }
}

/// Creates a `pubspec.yaml` file with a flutter dependency.
void createFakePubspec(Directory parent) {
  parent.childFile('pubspec.yaml').createSync();
  parent.childFile('pubspec.yaml').writeAsStringSync('''
name: fake_package
dependencies:
  flutter:
    sdk: flutter
''');
}

/// Cleans up the mock packages directory, making it an empty directory again.
void cleanupPackages() {
  mockPackagesDir.listSync().forEach((FileSystemEntity entity) {
    entity.deleteSync(recursive: true);
  });
}

/// Run the command [runner] with the given [args] and return
/// what was printed.
Future<List<String>> runCapturingPrint(
    CommandRunner runner, List<String> args) async {
  final List<String> prints = <String>[];
  final ZoneSpecification spec = ZoneSpecification(
    print: (_, __, ___, String message) {
      prints.add(message);
    },
  );
  await Zone.current
      .fork(specification: spec)
      .run<Future<void>>(() => runner.run(args));

  return prints;
}
