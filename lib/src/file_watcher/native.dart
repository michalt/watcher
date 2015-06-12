// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library watcher.file_watcher.native;

import 'dart:async';
import 'dart:io';

import '../file_watcher.dart';
import '../resubscribable.dart';
import '../utils.dart';
import '../watch_event.dart';

/// Uses the native file system notifications to watch for filesystem events.
///
/// Single-file notifications are much simpler than those for multiple files, so
/// this doesn't need to be split out into multiple OS-specific classes.
class NativeFileWatcher extends ResubscribableWatcher implements FileWatcher {
  NativeFileWatcher(String path)
      : super(path, () => new _NativeFileWatcher(path));
}

class _NativeFileWatcher implements FileWatcher, ManuallyClosedWatcher {
  final String path;

  Stream<WatchEvent> get events => _eventsController.stream;
  final _eventsController = new StreamController<WatchEvent>.broadcast();

  bool get isReady => _readyCompleter.isCompleted;

  Future get ready => _readyCompleter.future;
  final _readyCompleter = new Completer();

  StreamSubscription _subscription;

  _NativeFileWatcher(this.path) {
    _listen();

    // We don't need to do any initial set-up, so we're ready immediately after
    // being listened to.
    _readyCompleter.complete();
  }

  void _listen() {
    // Batch the events together so that we can dedup them.
    _subscription = new File(path).watch()
        .transform(new BatchedStreamTransformer<FileSystemEvent>())
        .listen(_onBatch, onError: _eventsController.addError, onDone: _onDone);
  }

  void _onBatch(List<FileSystemEvent> batch) {
    if (batch.any((event) => event.type == FileSystemEvent.DELETE)) {
      // If the file is deleted, the underlying stream will close. We handle
      // emitting our own REMOVE event in [_onDone].
      return;
    }

    _eventsController.add(new WatchEvent(ChangeType.MODIFY, path));
  }

  _onDone() async {
    // If the file exists now, it was probably removed and quickly replaced;
    // this can happen for example when another file is moved on top of it.
    // Re-subscribe and report a modify event.
    if (await new File(path).exists()) {
      _eventsController.add(new WatchEvent(ChangeType.MODIFY, path));
      _listen();
    } else {
      _eventsController.add(new WatchEvent(ChangeType.REMOVE, path));
      close();
    }
  }

  void close() {
    if (_subscription != null) _subscription.cancel();
    _subscription = null;
    _eventsController.close();
  }
}
