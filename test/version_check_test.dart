import "package:test/test.dart";

import "package:flutter_plugin_tools/src/version_check_command.dart";
import 'package:pub_semver/pub_semver.dart';

void testAllowedVersion(
  String masterVersion,
  String headVersion, {
  bool allowed = true,
  NextVersionType nextVersionType,
}) {
  final Version master = Version.parse(masterVersion);
  final Version head = Version.parse(headVersion);
  final Map<Version, NextVersionType> allowedVersions =
      getAllowedNextVersions(master, head);
  if (allowed) {
    expect(allowedVersions, contains(head));
    if (nextVersionType != null) {
      expect(allowedVersions[head], equals(nextVersionType));
    }
  } else {
    expect(allowedVersions, isNot(contains(head)));
  }
}

void main() {
  group("Pre 1.0", () {
    test("nextVersion allows patch version", () {
      testAllowedVersion("0.12.0", "0.12.0+1",
          nextVersionType: NextVersionType.PATCH);
      testAllowedVersion("0.12.0+4", "0.12.0+5",
          nextVersionType: NextVersionType.PATCH);
    });

    test("nextVersion does not allow jumping patch", () {
      testAllowedVersion("0.12.0", "0.12.0+2", allowed: false);
      testAllowedVersion("0.12.0+2", "0.12.0+4", allowed: false);
    });

    test("nextVersion does not allow going back", () {
      testAllowedVersion("0.12.0", "0.11.0", allowed: false);
      testAllowedVersion("0.12.0+2", "0.12.0+1", allowed: false);
      testAllowedVersion("0.12.0+1", "0.12.0", allowed: false);
    });

    test("nextVersion allows minor version", () {
      testAllowedVersion("0.12.0", "0.12.1",
          nextVersionType: NextVersionType.MINOR);
      testAllowedVersion("0.12.0+4", "0.12.1",
          nextVersionType: NextVersionType.MINOR);
    });

    test("nextVersion does not allow jumping minor", () {
      testAllowedVersion("0.12.0", "0.12.2", allowed: false);
      testAllowedVersion("0.12.0+2", "0.12.3", allowed: false);
    });
  });

  group("Releasing 1.0", () {
    test("nextVersion allows releasing 1.0", () {
      testAllowedVersion("0.12.0", "1.0.0",
          nextVersionType: NextVersionType.BREAKING_MAJOR);
      testAllowedVersion("0.12.0+4", "1.0.0",
          nextVersionType: NextVersionType.BREAKING_MAJOR);
    });

    test("nextVersion does not allow jumping major", () {
      testAllowedVersion("0.12.0", "2.0.0", allowed: false);
      testAllowedVersion("0.12.0+4", "2.0.0", allowed: false);
    });

    test("nextVersion does not allow un-releasing", () {
      testAllowedVersion("1.0.0", "0.12.0+4", allowed: false);
      testAllowedVersion("1.0.0", "0.12.0", allowed: false);
    });
  });

  group("Post 1.0", () {
    test("nextVersion allows patch jumps", () {
      testAllowedVersion("1.0.1", "1.0.2",
          nextVersionType: NextVersionType.PATCH);
      testAllowedVersion("1.0.0", "1.0.1",
          nextVersionType: NextVersionType.PATCH);
    });

    test("nextVersion does not allow build jumps", () {
      testAllowedVersion("1.0.1", "1.0.1+1", allowed: false);
      testAllowedVersion("1.0.0+5", "1.0.0+6", allowed: false);
    });

    test("nextVersion does not allow skipping patches", () {
      testAllowedVersion("1.0.1", "1.0.3", allowed: false);
      testAllowedVersion("1.0.0", "1.0.6", allowed: false);
    });

    test("nextVersion allows minor version jumps", () {
      testAllowedVersion("1.0.1", "1.1.0",
          nextVersionType: NextVersionType.MINOR);
      testAllowedVersion("1.0.0", "1.1.0",
          nextVersionType: NextVersionType.MINOR);
    });

    test("nextVersion does not allow skipping minor versions", () {
      testAllowedVersion("1.0.1", "1.2.0", allowed: false);
      testAllowedVersion("1.1.0", "1.3.0", allowed: false);
    });

    test("nextVersion allows breaking changes", () {
      testAllowedVersion("1.0.1", "2.0.0",
          nextVersionType: NextVersionType.BREAKING_MAJOR);
      testAllowedVersion("1.0.0", "2.0.0",
          nextVersionType: NextVersionType.BREAKING_MAJOR);
    });

    test("nextVersion does not allow skipping major versions", () {
      testAllowedVersion("1.0.1", "3.0.0", allowed: false);
      testAllowedVersion("1.1.0", "2.3.0", allowed: false);
    });
  });
}
