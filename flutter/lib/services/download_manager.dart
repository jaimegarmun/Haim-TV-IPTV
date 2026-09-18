import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:open_tv/models/channel.dart';
import 'package:open_tv/models/media_type.dart';
import 'package:open_tv/native_bridge.dart';
import 'package:open_tv/services/json_file.dart';
import 'package:path_provider/path_provider.dart';

enum DownloadStatus { queued, downloading, paused, completed, failed }

class DownloadItem {
  /// The original stream URL. Used as the key, and to find the local copy
  /// when the same movie/episode is played from anywhere in the app.
  final String url;
  final String name;
  final String localPath;
  final MediaType mediaType;
  final String? image;
  final int sourceId;
  final int? channelId;
  final int? seriesId;
  final String? seriesName;
  final int? seasonId;
  final String? seasonName;
  final int? episodeNum;
  final String? referrer;
  final String? origin;
  final String? userAgent;
  final int createdAt;
  DownloadStatus status;
  int receivedBytes;
  int totalBytes;
  String? error;

  DownloadItem({
    required this.url,
    required this.name,
    required this.localPath,
    required this.mediaType,
    required this.sourceId,
    required this.createdAt,
    this.image,
    this.channelId,
    this.seriesId,
    this.seriesName,
    this.seasonId,
    this.seasonName,
    this.episodeNum,
    this.referrer,
    this.origin,
    this.userAgent,
    this.status = DownloadStatus.queued,
    this.receivedBytes = 0,
    this.totalBytes = 0,
    this.error,
  });

  bool get isEpisode => seriesName != null || seasonId != null;

  double? get fraction =>
      totalBytes > 0 ? (receivedBytes / totalBytes).clamp(0.0, 1.0) : null;

  String get partPath => "$localPath.part";

  /// A channel that plays this download. The original URL is kept so the
  /// player finds the local file and watch progress stays shared.
  Channel toChannel() => Channel(
    id: channelId,
    name: name,
    url: url,
    image: image,
    mediaType: MediaType.movie,
    sourceId: sourceId,
    favorite: false,
    seriesId: seriesId,
    seasonId: seasonId,
    episodeNum: episodeNum,
  );

  Map<String, Object?> toJson() => {
    "url": url,
    "name": name,
    "local_path": localPath,
    "media_type": mediaType.index,
    "image": image,
    "source_id": sourceId,
    "channel_id": channelId,
    "series_id": seriesId,
    "series_name": seriesName,
    "season_id": seasonId,
    "season_name": seasonName,
    "episode_num": episodeNum,
    "referrer": referrer,
    "origin": origin,
    "user_agent": userAgent,
    "created_at": createdAt,
    "status": status.name,
    "received_bytes": receivedBytes,
    "total_bytes": totalBytes,
    "error": error,
  };

  static DownloadItem fromJson(Map<String, dynamic> json) => DownloadItem(
    url: json["url"] as String,
    name: json["name"] as String? ?? "",
    localPath: json["local_path"] as String,
    mediaType: MediaType.values[(json["media_type"] as num?)?.toInt() ?? 1],
    image: json["image"] as String?,
    sourceId: (json["source_id"] as num?)?.toInt() ?? 0,
    channelId: (json["channel_id"] as num?)?.toInt(),
    seriesId: (json["series_id"] as num?)?.toInt(),
    seriesName: json["series_name"] as String?,
    seasonId: (json["season_id"] as num?)?.toInt(),
    seasonName: json["season_name"] as String?,
    episodeNum: (json["episode_num"] as num?)?.toInt(),
    referrer: json["referrer"] as String?,
    origin: json["origin"] as String?,
    userAgent: json["user_agent"] as String?,
    createdAt: (json["created_at"] as num?)?.toInt() ?? 0,
    status: DownloadStatus.values.firstWhere(
      (s) => s.name == json["status"],
      orElse: () => DownloadStatus.queued,
    ),
    receivedBytes: (json["received_bytes"] as num?)?.toInt() ?? 0,
    totalBytes: (json["total_bytes"] as num?)?.toInt() ?? 0,
    error: json["error"] as String?,
  );
}

class _Cancelled implements Exception {}

/// Downloads movies and episodes for offline viewing.
///
/// Downloads run one at a time: most IPTV providers only allow a single
/// simultaneous connection per account. Interrupted downloads resume from
/// where they stopped (HTTP Range) the next time the app is open.
class DownloadManager extends ChangeNotifier {
  static final DownloadManager instance = DownloadManager._();
  DownloadManager._();

  static const String _defaultUserAgent = "Haim TV";
  static const int _maxAttempts = 5;

  final JsonFile _file = JsonFile("downloads.json");

  /// Set when the app data folder was moved (see data_migration.dart), so
  /// saved download paths inside it can be updated.
  (String, String)? movedDataFolder;
  final List<DownloadItem> _items = [];
  bool _processing = false;
  HttpClient? _activeClient;
  DownloadItem? _activeItem;
  DateTime _lastNotify = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastSave = DateTime.fromMillisecondsSinceEpoch(0);

  List<DownloadItem> get items => List.unmodifiable(_items);

  /// Folder chosen by the user in Settings, or null for the default one.
  String? _customDirectory;
  String? get customDirectory => _customDirectory;

  /// Where downloads go unless the user picks another folder.
  static Future<String> defaultDirectory() async {
    final base = await getApplicationSupportDirectory();
    return "${base.path}${Platform.pathSeparator}downloads";
  }

  /// The folder new downloads are saved to.
  Future<String> currentDirectory() async =>
      _customDirectory ?? await defaultDirectory();

  /// Changes where new downloads are saved; null restores the default.
  /// Existing downloads stay where they are. Throws if the folder cannot be
  /// written to.
  Future<void> setDirectory(String? path) async {
    if (path != null) {
      final dir = Directory(path);
      await dir.create(recursive: true);
      final probe = File(
        "${dir.path}${Platform.pathSeparator}.haim_tv_write_test",
      );
      try {
        await probe.writeAsString("ok", flush: true);
        await probe.delete();
      } on FileSystemException catch (e) {
        throw FileSystemException(
          "Haim TV can't save files in this folder. Choose another one.",
          path,
          e.osError,
        );
      }
    }
    _customDirectory = path;
    notifyListeners();
    await _save();
  }

  Future<void> load() async {
    final data = await _file.read();
    if (data is Map) {
      final dir = data["download_dir"];
      _customDirectory = dir is String && dir.isNotEmpty
          ? _relocate(dir)
          : null;
    }
    if (data is Map && data["items"] is List) {
      _items.clear();
      for (final raw in data["items"] as List) {
        try {
          final json = Map<String, dynamic>.from(raw as Map);
          if (json["local_path"] is String) {
            json["local_path"] = _relocate(json["local_path"] as String);
          }
          final item = DownloadItem.fromJson(json);
          if (item.status == DownloadStatus.downloading) {
            item.status = DownloadStatus.queued;
          }
          if (item.status == DownloadStatus.completed &&
              !File(item.localPath).existsSync()) {
            continue;
          }
          _items.add(item);
        } catch (e) {
          debugPrint("Skipping invalid download entry: $e");
        }
      }
      notifyListeners();
    }
    if (movedDataFolder != null) await _save();
    unawaited(_processQueue());
  }

  String _relocate(String path) {
    final moved = movedDataFolder;
    if (moved == null) return path;
    final (from, to) = moved;
    return path.toLowerCase().startsWith(from.toLowerCase())
        ? to + path.substring(from.length)
        : path;
  }

  DownloadItem? find(String? url) {
    if (url == null) return null;
    for (final item in _items) {
      if (item.url == url) return item;
    }
    return null;
  }

  /// Path of the finished local copy of [url], if there is one.
  String? localFileFor(String? url) {
    final item = find(url);
    if (item == null || item.status != DownloadStatus.completed) return null;
    return File(item.localPath).existsSync() ? item.localPath : null;
  }

  static bool canDownload(Channel channel) =>
      channel.mediaType == MediaType.movie &&
      channel.url != null &&
      (channel.url!.startsWith("http://") ||
          channel.url!.startsWith("https://"));

  /// Queues [channel]. Returns false if it was already downloaded or queued.
  Future<bool> enqueue(
    Channel channel, {
    String? seriesName,
    String? seasonName,
  }) async {
    if (!canDownload(channel) || find(channel.url) != null) return false;
    final headers = channel.id == null
        ? null
        : await NativeBridge.instance
              .getChannelHeaders(channel.id!)
              .catchError((_) => null);
    final item = DownloadItem(
      url: channel.url!,
      name: channel.name,
      localPath: await _localPathFor(channel),
      mediaType: channel.mediaType,
      image: channel.image,
      sourceId: channel.sourceId,
      channelId: channel.id,
      seriesId: channel.seriesId,
      seriesName: seriesName,
      seasonId: channel.seasonId,
      seasonName: seasonName,
      episodeNum: channel.episodeNum,
      referrer: headers?.referrer,
      origin: headers?.httpOrigin,
      userAgent: headers?.userAgent,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    _items.add(item);
    notifyListeners();
    await _save();
    unawaited(_processQueue());
    return true;
  }

  Future<void> pause(String url) async {
    final item = find(url);
    if (item == null) return;
    if (item.status == DownloadStatus.queued ||
        item.status == DownloadStatus.downloading) {
      item.status = DownloadStatus.paused;
      if (_activeItem == item) _abortActive();
      notifyListeners();
      await _save();
    }
  }

  Future<void> resume(String url) async {
    final item = find(url);
    if (item == null) return;
    if (item.status == DownloadStatus.paused ||
        item.status == DownloadStatus.failed) {
      item.status = DownloadStatus.queued;
      item.error = null;
      notifyListeners();
      await _save();
      unawaited(_processQueue());
    }
  }

  Future<void> remove(String url) async {
    final item = find(url);
    if (item == null) return;
    _items.remove(item);
    if (_activeItem == item) _abortActive();
    notifyListeners();
    await _save();
    // Let the aborted transfer close its file handle first (Windows locks
    // open files).
    for (var i = 0; i < 50 && _activeItem == item; i++) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
    await _deleteFiles(item);
  }

  void _abortActive() {
    _activeClient?.close(force: true);
  }

  Future<void> _deleteFiles(DownloadItem item) async {
    for (final path in [item.localPath, item.partPath]) {
      try {
        final file = File(path);
        if (await file.exists()) await file.delete();
      } catch (e) {
        debugPrint("Failed to delete $path: $e");
      }
    }
  }

  Future<void> _processQueue() async {
    if (_processing) return;
    _processing = true;
    try {
      while (true) {
        final next = _items
            .where((i) => i.status == DownloadStatus.queued)
            .firstOrNull;
        if (next == null) break;
        await _download(next);
      }
    } finally {
      _processing = false;
    }
  }

  Future<void> _download(DownloadItem item) async {
    item.status = DownloadStatus.downloading;
    item.error = null;
    _activeItem = item;
    notifyListeners();
    await _save();
    for (var attempt = 1; attempt <= _maxAttempts; attempt++) {
      try {
        await _transfer(item);
        item.status = DownloadStatus.completed;
        break;
      } on _Cancelled {
        break;
      } catch (e) {
        if (!_isActive(item)) break;
        debugPrint("Download attempt $attempt of ${item.name} failed: $e");
        if (attempt == _maxAttempts) {
          item.status = DownloadStatus.failed;
          item.error = e.toString();
        } else {
          await Future.delayed(Duration(seconds: 2 * attempt));
          if (!_isActive(item)) break;
        }
      }
    }
    _activeItem = null;
    _activeClient = null;
    notifyListeners();
    if (_items.contains(item)) await _save();
  }

  bool _isActive(DownloadItem item) =>
      _items.contains(item) && item.status == DownloadStatus.downloading;

  Future<void> _transfer(DownloadItem item) async {
    final part = File(item.partPath);
    await part.parent.create(recursive: true);
    var existing = await part.exists() ? await part.length() : 0;

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 20)
      ..autoUncompress = false;
    _activeClient = client;
    try {
      final request = await client.getUrl(Uri.parse(item.url));
      request.followRedirects = true;
      request.maxRedirects = 10;
      request.headers.set(
        HttpHeaders.userAgentHeader,
        (item.userAgent?.isNotEmpty ?? false)
            ? item.userAgent!
            : _defaultUserAgent,
      );
      if (item.referrer?.isNotEmpty ?? false) {
        request.headers.set("Referer", item.referrer!);
      }
      if (item.origin?.isNotEmpty ?? false) {
        request.headers.set("Origin", item.origin!);
      }
      if (existing > 0) {
        request.headers.set(HttpHeaders.rangeHeader, "bytes=$existing-");
      }
      final response = await request.close();

      if (response.statusCode == HttpStatus.requestedRangeNotSatisfiable &&
          existing > 0) {
        // The partial file already holds everything.
        await response.drain<void>();
        await _finish(item, part);
        return;
      }
      final append = response.statusCode == HttpStatus.partialContent;
      if (!append && response.statusCode != HttpStatus.ok) {
        await response.drain<void>();
        throw HttpException("Server answered HTTP ${response.statusCode}");
      }
      if (!append) existing = 0;
      item.receivedBytes = existing;
      item.totalBytes = response.contentLength > 0
          ? existing + response.contentLength
          : 0;
      notifyListeners();

      final sink = part.openWrite(
        mode: append ? FileMode.writeOnlyAppend : FileMode.writeOnly,
      );
      try {
        await for (final chunk in response) {
          if (!_isActive(item)) throw _Cancelled();
          sink.add(chunk);
          item.receivedBytes += chunk.length;
          _onProgress();
        }
      } finally {
        await sink.flush();
        await sink.close();
      }
      if (!_isActive(item)) throw _Cancelled();
      if (item.totalBytes > 0 && item.receivedBytes < item.totalBytes) {
        throw const HttpException("Connection closed before the end");
      }
      await _finish(item, part);
    } catch (e) {
      if (!_isActive(item)) throw _Cancelled();
      rethrow;
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _finish(DownloadItem item, File part) async {
    final target = File(item.localPath);
    if (await target.exists()) await target.delete();
    await part.rename(item.localPath);
    item.receivedBytes = await target.length();
    item.totalBytes = item.receivedBytes;
  }

  void _onProgress() {
    final now = DateTime.now();
    if (now.difference(_lastNotify) > const Duration(milliseconds: 500)) {
      _lastNotify = now;
      notifyListeners();
    }
    if (now.difference(_lastSave) > const Duration(seconds: 10)) {
      _lastSave = now;
      _save();
    }
  }

  Future<void> _save() {
    return _file.write({
      "version": 1,
      "download_dir": _customDirectory,
      "items": _items.map((i) => i.toJson()).toList(),
    });
  }

  Future<String> _localPathFor(Channel channel) async {
    final sep = Platform.pathSeparator;
    final dir = Directory(await currentDirectory());
    if (!await dir.exists()) await dir.create(recursive: true);
    final uri = Uri.tryParse(channel.url!);
    final lastSegment = uri?.pathSegments.lastOrNull ?? "";
    final dot = lastSegment.lastIndexOf(".");
    var extension = dot >= 0 ? lastSegment.substring(dot + 1) : "";
    if (!RegExp(r"^[A-Za-z0-9]{2,4}$").hasMatch(extension)) extension = "mp4";
    var safeName = channel.name
        .replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F]'), "_")
        .trim();
    if (safeName.length > 80) safeName = safeName.substring(0, 80);
    if (safeName.isEmpty) safeName = "video";
    final unique = channel.url!.hashCode.toUnsigned(32).toRadixString(16);
    return "${dir.path}$sep${safeName}_$unique.$extension";
  }
}

String formatBytes(int bytes) {
  if (bytes <= 0) return "0 B";
  const units = ["B", "KB", "MB", "GB", "TB"];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  return "${value.toStringAsFixed(unit == 0 ? 0 : 1)} ${units[unit]}";
}
