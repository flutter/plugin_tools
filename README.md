# Flutter Plugin Tools

[![Build Status](https://travis-ci.org/flutter/plugin_tools.svg?branch=master)](https://travis-ci.org/flutter/plugin_tools)
[![pub package](https://img.shields.io/pub/v/flutter_plugin_tools.svg)](https://pub.dartlang.org/packages/flutter_plugin_tools)


Flutter Plugin Tools implements a CLI with various productivity tools for hosting multiple Flutter plugins in one github
repository. It is mainly used by the [flutter/plugins](https://github.com/flutter/plugins) and
[flutter/flutterfire](https://github.com/flutter/flutterfire) repositories. It was mainly written to facilitate
testing on Travis for these repositories (see [travis.yaml](https://github.com/flutter/plugins/blob/master/.travis.yml)).

As an example, Flutter Plugin Tools allows you to:

* Build all plugin example apps with one command
* Run the tests of all pluigns with one command
* Format all Dart, Java, and Objective-C code in the repository

## Installation

In order to use the tools you need to enable them once by running the following command:

```shell
$ pub global activate flutter_plugin_tools
```

## Requirements

To use all features of `flutter_plugin_tools` you'll need the following commands in your `PATH`:
* `flutter`
* `git`
* `pub` (recommended: version from `<path/to/flutter>/bin/cache/dart-sdk/bin`)
* `clang-format` version 5 (alternatively, you can provide the path via `--clang-format=`)

## Usage

```shell
$ pub global run flutter_plugin_tools <command>
```

Replace `<command>` with `help` to print a list of available commands.
