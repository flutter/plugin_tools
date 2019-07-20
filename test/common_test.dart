import "package:test/test.dart";

import "package:flutter_plugin_tools/src/common.dart";

void main() {
  group("runAndStream", () {
    test("monitors stderr", () async {
      bool hasStderr = false;
      int exitCode = await runAndStream('ls', <String>[],
          onStderr: (_) => hasStderr = true);
      expect(hasStderr, false);
      exitCode = await runAndStream('ls', <String>['--asdf'],
          onStderr: (_) => hasStderr = true);
      expect(hasStderr, true);
    });
  });
}
