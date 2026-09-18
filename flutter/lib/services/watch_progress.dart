import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:open_tv/services/json_file.dart';

class WatchProgress {
  final String name;
  final int positionSeconds;
  final int durationSeconds;
  final bool watched;
  final int updatedAt;

  const WatchProgress({
    required this.name,
    required this.positionSeconds,
    required this.durationSeconds,
    required this.watched,
    required this.updatedAt,
  });

  /// 0.0 - 1.0, or null when the duration is unknown.
  double? get fraction => durationSeconds > 0
      ? (positionSeconds / durationSeconds).clamp(0.0, 1.0)
      : null;

  Map<String, Object?> toJson() => {
    "name": name,
    "position": positionSeconds,
    "position_text": formatSeconds(positionSeconds),
    "duration": durationSeconds,
    "duration_text": formatSeconds(durationSeconds),
    "watched": watched,
    "updated_at": updatedAt,
  };

  static WatchProgress fromJson(Map<String, dynamic> json) => WatchProgress(
    name: json["name"] as String? ?? "",
    positionSeconds: (json["position"] as num?)?.toInt() ?? 0,
    durationSeconds: (json["duration"] as num?)?.toInt() ?? 0,
    watched: json["watched"] as bool? ?? false,
    updatedAt: (json["updated_at"] as num?)?.toInt() ?? 0,
  );
}

String formatSeconds(int totalSeconds) {
  final h = totalSeconds ~/ 3600;
  final m = (totalSeconds % 3600) ~/ 60;
  final s = totalSeconds % 60;
  final mm = m.toString().padLeft(2, '0');
  final ss = s.toString().padLeft(2, '0');
  return h > 0 ? "$h:$mm:$ss" : "$mm:$ss";
}

/// Remembers where each movie/episode was left and which ones were fully
/// watched. Stored in `watch_progress.json`, keyed by the stream URL because
/// channel ids are regenerated every time a source is refreshed.
class WatchProgressStore extends ChangeNotifier {
  static final WatchProgressStore instance = WatchProgressStore._();
  WatchProgressStore._();

  /// Considered fully watched past this fraction of the duration...
  static const double watchedThreshold = 0.92;

  /// ...or when fewer than this many seconds remain (end credits).
  static const int watchedRemainingSeconds = 120;

  /// Below this position there is nothing worth resuming.
  static const int minResumeSeconds = 10;

  final JsonFile _file = JsonFile("watch_progress.json");
  final Map<String, WatchProgress> _entries = {};
  Timer? _saveDebounce;

  Future<void> load() async {
    final data = await _file.read();
    if (data is! Map) return;
    final entries = data["entries"];
    if (entries is! Map) return;
    _entries.clear();
    entries.forEach((key, value) {
      if (key is String && value is Map<String, dynamic>) {
        _entries[key] = WatchProgress.fromJson(value);
      }
    });
    notifyListeners();
  }

  WatchProgress? get(String? url) => url == null ? null : _entries[url];

  bool isWatched(String? url) => get(url)?.watched ?? false;

  /// Where playback should start, or null to start from the beginning.
  int? resumePosition(String? url) {
    final entry = get(url);
    if (entry == null || entry.positionSeconds < minResumeSeconds) return null;
    return entry.positionSeconds;
  }

  void update(
    String? url,
    String name,
    int positionSeconds,
    int durationSeconds, {
    bool flush = false,
  }) {
    if (url == null || positionSeconds < 0) return;
    final previous = _entries[url];
    final duration = durationSeconds > 0
        ? durationSeconds
        : (previous?.durationSeconds ?? 0);
    final reachedEnd =
        duration > 0 &&
        (positionSeconds >= duration * watchedThreshold ||
            duration - positionSeconds <= watchedRemainingSeconds);
    // Once watched, it stays ticked (rewatching part of it keeps the tick);
    // only "Mark as unwatched" removes it.
    final watched = reachedEnd || (previous?.watched ?? false);
    _entries[url] = WatchProgress(
      name: name,
      positionSeconds: reachedEnd ? 0 : positionSeconds,
      durationSeconds: duration,
      watched: watched,
      updatedAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    );
    notifyListeners();
    _scheduleSave(flush);
  }

  void setWatched(String? url, String name, bool watched) {
    if (url == null) return;
    final previous = _entries[url];
    _entries[url] = WatchProgress(
      name: name,
      positionSeconds: 0,
      durationSeconds: previous?.durationSeconds ?? 0,
      watched: watched,
      updatedAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    );
    notifyListeners();
    _scheduleSave(true);
  }

  void clear() {
    _entries.clear();
    notifyListeners();
    _scheduleSave(true);
  }

  void _scheduleSave(bool flush) {
    _saveDebounce?.cancel();
    if (flush) {
      _save();
    } else {
      _saveDebounce = Timer(const Duration(seconds: 2), _save);
    }
  }

  Future<void> _save() {
    return _file.write({
      "version": 1,
      "entries": _entries.map((key, value) => MapEntry(key, value.toJson())),
    });
  }
}
