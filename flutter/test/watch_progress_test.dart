import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_tv/services/watch_progress.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUpAll(() {
    tempDir = Directory.systemTemp.createTempSync('haimtv_progress_test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => tempDir.path,
        );
  });

  tearDownAll(() => tempDir.deleteSync(recursive: true));

  final store = WatchProgressStore.instance;
  const url = 'http://example.com/series/u/p/1.mkv';

  setUp(store.clear);

  test('formatSeconds', () {
    expect(formatSeconds(5), '00:05');
    expect(formatSeconds(754), '12:34');
    expect(formatSeconds(3723), '1:02:03');
  });

  test('resumes where it was left', () {
    store.update(url, 'Ep 1', 754, 2700);
    expect(store.resumePosition(url), 754);
    expect(store.isWatched(url), isFalse);
    expect(store.get(url)!.fraction, closeTo(754 / 2700, 0.001));
  });

  test('a few seconds is not worth resuming', () {
    store.update(url, 'Ep 1', 4, 2700);
    expect(store.resumePosition(url), isNull);
  });

  test('reaching the end credits marks as watched', () {
    store.update(url, 'Ep 1', 2650, 2700);
    expect(store.isWatched(url), isTrue);
    // Starts from the beginning next time.
    expect(store.resumePosition(url), isNull);
  });

  test('rewatching part of a watched episode keeps the tick', () {
    store.update(url, 'Ep 1', 2700, 2700);
    store.update(url, 'Ep 1', 600, 2700);
    expect(store.isWatched(url), isTrue);
    expect(store.resumePosition(url), 600);
  });

  test('manual mark as watched / unwatched', () {
    store.setWatched(url, 'Ep 1', true);
    expect(store.isWatched(url), isTrue);
    store.setWatched(url, 'Ep 1', false);
    expect(store.isWatched(url), isFalse);
  });

  test('is saved to watch_progress.json and loaded back', () async {
    store.update(url, 'Ep 1', 754, 2700, flush: true);
    await Future.delayed(const Duration(milliseconds: 300));
    final file = File('${tempDir.path}/watch_progress.json');
    expect(file.existsSync(), isTrue);
    final content = file.readAsStringSync();
    expect(content, contains('"position_text": "12:34"'));

    store.update(url, 'Ep 1', 10, 2700); // not flushed
    await store.load();
    expect(store.resumePosition(url), 754);
  });
}
