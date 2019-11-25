import 'dart:async';
import 'dart:io' as io;

import 'package:args/command_runner.dart';
import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:flutter_plugin_tools/src/common.dart';
import 'package:quiver/collection.dart';

final FileSystem mockFileSystem = MemoryFileSystem();
Directory mockPackagesDir;

/// Creates a mock packages directory in the mock file system.
///
/// If [parentDir] is set the mock packages dir will be creates as a child of
/// it. If not [mockFileSystem] will be used instead.
void initializeFakePackages({Directory parentDir}) {
  mockPackagesDir =
      (parentDir ?? mockFileSystem.currentDirectory).childDirectory('packages');
  mockPackagesDir.createSync();
}

/// Creates a plugin package with the given [name] in [mockPackagesDir].
Directory createFakePlugin(
  String name, {
  bool withSingleExample: false,
  List<String> withExamples: const <String>[],
  List<List<String>> withExtraFiles: const <List<String>>[],
  bool isFlutter: true,
}) {
  assert(!(withSingleExample && withExamples.isNotEmpty),
      'cannot pass withSingleExample and withExamples simultaneously');

  final Directory pluginDirectory = mockPackagesDir.childDirectory(name)
    ..createSync();
  createFakePubspec(pluginDirectory, isFlutter: isFlutter);

  if (withSingleExample) {
    final Directory exampleDir = pluginDirectory.childDirectory('example')
      ..createSync();
    createFakePubspec(exampleDir, isFlutter: isFlutter);
  } else if (withExamples.isNotEmpty) {
    final Directory exampleDir = pluginDirectory.childDirectory('example')
      ..createSync();
    for (String example in withExamples) {
      final Directory currentExample = exampleDir.childDirectory(example)
        ..createSync();
      createFakePubspec(currentExample, isFlutter: isFlutter);
    }
  }

  for (List<String> file in withExtraFiles) {
    final List<String> newFilePath = [pluginDirectory.path]..addAll(file);
    final File newFile =
        mockFileSystem.file(mockFileSystem.path.joinAll(newFilePath));
    newFile.createSync(recursive: true);
  }

  return pluginDirectory;
}

/// Creates a `pubspec.yaml` file with a flutter dependency.
void createFakePubspec(Directory parent,
    {bool isFlutter = true, bool includeVersion = false}) {
  parent.childFile('pubspec.yaml').createSync();
  String yaml = '''
name: fake_package
''';
  if (isFlutter) {
    yaml += '''
dependencies:
  flutter:
    sdk: flutter
''';
  }
  if (includeVersion) {
    yaml += '''
version: 0.0.1
publish_to: none # Hardcoded safeguard to prevent this from somehow being published by a broken test.
''';
  }
  parent.childFile('pubspec.yaml').writeAsStringSync(yaml);
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

/// A mock [ProcessRunner] which records process calls.
class RecordingProcessRunner extends ProcessRunner {
  final List<ProcessCall> recordedCalls = <ProcessCall>[];

  @override
  Future<int> runAndStream(
    String executable,
    List<String> args, {
    Directory workingDir,
    bool exitOnError = false,
  }) {
    recordedCalls.add(ProcessCall(executable, args, workingDir?.path));
    return Future<int>.value(0);
  }

  @override
  Future<io.ProcessResult> runAndExitOnError(
    String executable,
    List<String> args, {
    Directory workingDir,
  }) {
    recordedCalls.add(ProcessCall(executable, args, workingDir?.path));
    return Future<io.ProcessResult>.value(null);
  }
}

/// A recorded process call.
class ProcessCall {
  const ProcessCall(this.executable, this.args, this.workingDir);

  /// The executable that was called.
  final String executable;

  /// The arguments passed to [executable] in the call.
  final List<String> args;

  /// The working directory this process was called from.
  final String workingDir;

  bool operator ==(dynamic other) {
    if (other is! ProcessCall) return false;
    ProcessCall otherCall = other;
    return executable == otherCall.executable &&
        listsEqual(args, otherCall.args) &&
        workingDir == otherCall.workingDir;
  }

  String toString() {
    final List<String> command = [executable]..addAll(args);
    return '"${command.join(' ')}" in $workingDir';
  }
}
