## v.0.0.20

- Add test command that verifies whether all plugins have valid licenses.

## v.0.0.19+2

- Use java as language when calling `flutter create`.

## v.0.0.19+1

- Rename command for `CreateAllPluginsAppCommand`.

## v.0.0.19

- Use flutter create to build app testing plugin compilation.
>>>>>>> ab4eeb5944ceaa694cbcb8ed1af106e265952b6c

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
