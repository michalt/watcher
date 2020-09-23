// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('windows')

import 'package:test/test.dart';
import 'package:watcher/src/directory_watcher/windows.dart';
import 'package:watcher/watcher.dart';

import 'shared.dart';
import '../utils.dart';

void main() {
  setUp(() {
    watcherFactory = (dir) => WindowsDirectoryWatcher(dir);
  });

  // TODO(grouma) - renable when https://github.com/dart-lang/sdk/issues/31760
  // is resolved.
  group('Shared Tests:', () {
    sharedTests();
  }, skip: 'SDK issue see - https://github.com/dart-lang/sdk/issues/31760');

  test('DirectoryWatcher creates a WindowsDirectoryWatcher on Windows', () {
    expect(DirectoryWatcher('.'), TypeMatcher<WindowsDirectoryWatcher>());
  });

  test('non recursive watch works', () async {
    watcherFactory = (dir) => WindowsDirectoryWatcher(dir, recursive: true);

    // Make some pre-existing files.
    createDir('a');
    createDir('a/b');

    await startWatcher(path: 'a');

    // These two should not trigger an event.
    writeFile('a/b/x.txt');
    writeFile('a/b/y.txt');
    // But this one should.
    writeFile('a/z.txt');

    await expectAddEvent('a/z.txt');
  });
}
