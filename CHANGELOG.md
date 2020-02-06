## v.0.0.32+6

- Ensure that Firebase Test Lab tests have a unique storage bucket for each package.

## v.0.0.32+5

- Remove --fail-fast and --silent from lint podspec command.

## v.0.0.32+4

- Update `publish-plugin` to use `flutter pub publish` instead of just `pub
  publish`. Enforces a `pub publish` command that matches the Dart SDK in the
  user's Flutter install.

## v.0.0.32+3

- Update Firebase Testlab deprecated test device. (Pixel 3 API 28 -> Pixel 4 API 29).

## v.0.0.32+2

- Runs pub get before building macos to avoid failures.

## v.0.0.32+1

- Default macOS example builds to false. Previously they were running whenever
  CI was itself running on macOS.

## v.0.0.32

- `analyze` now asserts that the global `analysis_options.yaml` is the only one
  by default. Individual directories can be excluded from this check with the
  new `--custom-analysis` flag.

## v.0.0.31+1

- Add --skip and --no-analyze flags to podspec command.

## v.0.0.31

- Add support for macos on `DriveExamplesCommand` and `BuildExamplesCommand`.

## v.0.0.30

- Adopt pedantic analysis options, fix firebase_test_lab_test.

## v.0.0.29

- Add a command to run pod lib lint on podspec files.

## v.0.0.28

- Increase Firebase test lab timeouts to 5 minutes.

## v.0.0.27

- Run tests with `--platform=chrome` for web plugins.

## v.0.0.26

- Add a command for publishing plugins to pub.

## v.0.0.25

- Update `DriveExamplesCommand` to use `ProcessRunner`.
- Make `DriveExamplesCommand` rely on `ProcessRunner` to determine if the test fails or not.
- Add simple tests for `DriveExamplesCommand`.

## v.0.0.24

- Gracefully handle pubspec.yaml files for new plugins.
- Additional unit testing.

## v.0.0.23

- Add a test case for transitive dependency solving in the
  `create_all_plugins_app` command.

## v.0.0.22

- Updated firebase-test-lab command with updated conventions for test locations.
- Updated firebase-test-lab to add an optional "device" argument.
- Updated version-check command to always compare refs instead of using the working copy.
- Added unit tests for the firebase-test-lab and version-check commands.
- Add ProcessRunner to mock running processes for testing.

## v.0.0.21

- Support the `--plugins` argument for federated plugins.

## v.0.0.20

- Support for finding federated plugins, where one directory contains
  multiple packages for different platform implementations.

## v.0.0.19+3

- Use `package:file` for file I/O.

## v.0.0.19+2

- Use java as language when calling `flutter create`.

## v.0.0.19+1

- Rename command for `CreateAllPluginsAppCommand`.

## v.0.0.19

- Use flutter create to build app testing plugin compilation.

## v.0.0.18+2

- Fix `.travis.yml` file name in `README.md`.

## v0.0.18+1

- Skip version check if it contains `publish_to: none`.

## v0.0.18

- Add option to exclude packages from generated pubspec command.

## v0.0.17+4

- Avoid trying to version-check pubspecs that are missing a version.

## v0.0.17+3

- version-check accounts for [pre-1.0 patch versions](https://github.com/flutter/flutter/issues/35412).

## v0.0.17+2

- Fix exception handling for version checker

## v0.0.17+1

- Fix bug where we used a flag instead of an option

## v0.0.17

- Add a command for checking the version number

## v0.0.16

- Add a command for generating `pubspec.yaml` for All Plugins app.

## v0.0.15

- Add a command for running driver tests of plugin examples.

## v0.0.14

- Check for dependencies->flutter instead of top level flutter node.

## v0.0.13

- Differentiate between Flutter and non-Flutter (but potentially Flutter consumed) Dart packages.
