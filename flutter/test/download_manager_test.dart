import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_tv/models/channel.dart';
import 'package:open_tv/models/media_type.dart';
import 'package:open_tv/services/download_manager.dart';

/// Serves [data], honours Range requests, and drops the connection halfway
/// through the first full request to simulate a network cut.
Future<HttpServer> startServer(Uint8List data, List<String?> ranges) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  var cutDone = false;
  server.listen((request) async {
    final range = request.headers.value(HttpHeaders.rangeHeader);
    ranges.add(range);
    final response = request.response;
    if (!cutDone && range == null) {
      cutDone = true;
      final socket = await response.detachSocket(writeHeaders: false);
      socket.write(
        'HTTP/1.1 200 OK\r\nContent-Length: ${data.length}\r\n'
        'Connection: close\r\n\r\n',
      );
      socket.add(data.sublist(0, data.length ~/ 2));
      await socket.flush();
      socket.destroy();
      return;
    }
    var start = 0;
    if (range != null) {
      start = int.parse(RegExp(r'bytes=(\d+)-').firstMatch(range)!.group(1)!);
      response.statusCode = HttpStatus.partialContent;
      response.headers.set(
        HttpHeaders.contentRangeHeader,
        'bytes $start-${data.length - 1}/${data.length}',
      );
    }
    response.contentLength = data.length - start;
    response.add(data.sublist(start));
    await response.close();
  });
  return server;
}

Future<void> waitFor(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 30));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) fail('Timed out');
    await Future.delayed(const Duration(milliseconds: 50));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUpAll(() {
    // The test binding blocks real HTTP; this test needs a local server.
    HttpOverrides.global = null;
    tempDir = Directory.systemTemp.createTempSync('haimtv_download_test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => tempDir.path,
        );
  });

  tearDownAll(() => tempDir.deleteSync(recursive: true));

  Channel movie(String url, String name) => Channel(
    name: name,
    url: url,
    mediaType: MediaType.movie,
    sourceId: 1,
    favorite: false,
  );

  test('the download folder can be changed and is remembered', () async {
    final manager = DownloadManager.instance;
    final defaultDir = await DownloadManager.defaultDirectory();
    expect(await manager.currentDirectory(), defaultDir);

    final custom = '${tempDir.path}${Platform.pathSeparator}Mis descargas';
    await manager.setDirectory(custom);
    expect(await manager.currentDirectory(), custom);
    expect(Directory(custom).existsSync(), isTrue);

    // Survives an app restart.
    await Future.delayed(const Duration(milliseconds: 300));
    await manager.load();
    expect(manager.customDirectory, custom);

    await manager.setDirectory(null);
    expect(await manager.currentDirectory(), defaultDir);
  });

  test('only movies/episodes with an http url can be downloaded', () {
    expect(DownloadManager.canDownload(movie('http://a/b.mp4', 'x')), isTrue);
    expect(
      DownloadManager.canDownload(
        Channel(
          name: 'live',
          url: 'http://a/b.ts',
          mediaType: MediaType.livestream,
          sourceId: 1,
          favorite: false,
        ),
      ),
      isFalse,
    );
    expect(DownloadManager.canDownload(movie('/local/file.mp4', 'x')), isFalse);
  });

  test(
    'downloads, resumes after a cut connection and is found offline',
    () async {
      final data = Uint8List.fromList(
        List.generate(300 * 1024, (i) => (i * 7) % 256),
      );
      final ranges = <String?>[];
      final server = await startServer(data, ranges);
      final url = 'http://127.0.0.1:${server.port}/movie/u/p/42.mkv';
      final manager = DownloadManager.instance;
      await manager.load();

      expect(await manager.enqueue(movie(url, 'Película: Test/1')), isTrue);
      expect(await manager.enqueue(movie(url, 'dup')), isFalse);

      await waitFor(() {
        final status = manager.find(url)?.status;
        return status == DownloadStatus.completed ||
            status == DownloadStatus.failed;
      });
      final item = manager.find(url)!;
      expect(item.status, DownloadStatus.completed, reason: item.error);
      expect(item.localPath, endsWith('.mkv'));

      // The second request continued from the bytes already on disk.
      expect(ranges.first, isNull);
      expect(ranges.last, 'bytes=${data.length ~/ 2}-');

      final local = manager.localFileFor(url);
      expect(local, isNotNull);
      expect(File(local!).readAsBytesSync(), data);
      expect(File(item.partPath).existsSync(), isFalse);

      // Survives an app restart.
      await Future.delayed(const Duration(milliseconds: 300));
      await manager.load();
      expect(manager.localFileFor(url), local);

      await manager.remove(url);
      expect(manager.find(url), isNull);
      expect(File(local).existsSync(), isFalse);
      await server.close(force: true);
    },
  );
}
