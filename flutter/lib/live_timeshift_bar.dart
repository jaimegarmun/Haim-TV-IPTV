import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart' as mk;
import 'package:open_tv/services/watch_progress.dart';

/// How much of a live channel mpv keeps so it can be rewound. media_kit
/// stores the demuxer cache on disk, so this does not use RAM.
const String liveTimeshiftBackBuffer = "2GiB";

/// Configures mpv so everything watched since opening a live channel can be
/// rewound. Must run before the stream is opened.
Future<void> enableLiveTimeshift(mk.NativePlayer player) async {
  await player.setProperty('cache', 'yes');
  await player.setProperty('demuxer-seekable-cache', 'yes');
  await player.setProperty('demuxer-max-back-bytes', liveTimeshiftBackBuffer);
}

/// Seek bar for live channels: goes from the oldest moment still cached to
/// the live edge, like mpv's own timeline.
class LiveTimeshiftBar extends StatefulWidget {
  final mk.Player player;
  const LiveTimeshiftBar({super.key, required this.player});

  @override
  State<LiveTimeshiftBar> createState() => _LiveTimeshiftBarState();
}

class _LiveTimeshiftBarState extends State<LiveTimeshiftBar> {
  /// Within this distance of the live edge the stream counts as "live".
  static const _liveTolerance = Duration(seconds: 6);

  Duration _start = Duration.zero;
  Duration _end = Duration.zero;
  Duration _position = Duration.zero;
  double? _dragging;
  Timer? _timer;
  final List<StreamSubscription> _subscriptions = [];

  @override
  void initState() {
    super.initState();
    _position = widget.player.state.position;
    _end = widget.player.state.buffer;
    _subscriptions.add(
      widget.player.stream.position.listen((p) {
        if (mounted) setState(() => _position = p);
      }),
    );
    _subscriptions.add(
      widget.player.stream.buffer.listen((b) {
        if (mounted && b > _end) setState(() => _end = b);
      }),
    );
    _refreshRange();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _refreshRange());
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final s in _subscriptions) {
      s.cancel();
    }
    super.dispose();
  }

  /// Reads the range mpv can still seek into from `demuxer-cache-state`.
  Future<void> _refreshRange() async {
    final platform = widget.player.platform;
    if (platform is! mk.NativePlayer) return;
    try {
      final raw = await platform.getProperty('demuxer-cache-state');
      if (raw.isEmpty) return;
      final data = jsonDecode(raw);
      final ranges = data is Map ? data['seekable-ranges'] : null;
      if (ranges is! List || ranges.isEmpty) return;
      final position = _position.inMilliseconds / 1000;
      // The range that contains the current position, else the last one.
      Map? best;
      for (final range in ranges) {
        if (range is! Map) continue;
        final start = (range['start'] as num?)?.toDouble();
        final end = (range['end'] as num?)?.toDouble();
        if (start == null || end == null) continue;
        best = range;
        if (position >= start && position <= end) break;
      }
      if (best == null || !mounted) return;
      setState(() {
        _start = _seconds(best!['start']);
        final end = _seconds(best['end']);
        if (end > _start) _end = end;
      });
    } catch (_) {
      // Older libmpv builds may not expose it; the buffer stream still works.
    }
  }

  static Duration _seconds(Object? value) =>
      Duration(milliseconds: (((value as num?) ?? 0) * 1000).round());

  bool get _atLiveEdge => _end - _position <= _liveTolerance;

  void _goLive() {
    final target = _end - const Duration(seconds: 1);
    widget.player.seek(target > _start ? target : _end);
  }

  @override
  Widget build(BuildContext context) {
    final startMs = _start.inMilliseconds.toDouble();
    var endMs = _end.inMilliseconds.toDouble();
    if (endMs <= startMs) endMs = startMs + 1;
    final value = (_dragging ?? _position.inMilliseconds.toDouble()).clamp(
      startMs,
      endMs,
    );
    final behind = Duration(milliseconds: (endMs - value).round());
    return Row(
      children: [
        SizedBox(
          width: 72,
          child: Text(
            _atLiveEdge && _dragging == null
                ? ""
                : "-${formatSeconds(behind.inSeconds)}",
            textAlign: TextAlign.right,
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              activeTrackColor: Colors.redAccent,
              inactiveTrackColor: Colors.white24,
              thumbColor: Colors.white,
              overlayShape: SliderComponentShape.noOverlay,
            ),
            child: Slider(
              min: startMs,
              max: endMs,
              value: value,
              onChanged: (v) => setState(() => _dragging = v),
              onChangeEnd: (v) {
                setState(() => _dragging = null);
                widget.player.seek(Duration(milliseconds: v.round()));
              },
            ),
          ),
        ),
        TextButton.icon(
          onPressed: _atLiveEdge ? null : _goLive,
          icon: Icon(
            Icons.circle,
            size: 12,
            color: _atLiveEdge ? Colors.red : Colors.grey,
          ),
          label: Text(
            "LIVE",
            style: TextStyle(
              color: _atLiveEdge ? Colors.white : Colors.white70,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
