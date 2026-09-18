import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// A short message shown over the video, e.g. the volume or a seek.
class OsdEvent {
  final IconData icon;
  final String text;
  final Alignment alignment;
  const OsdEvent(this.icon, this.text, this.alignment);
}

/// YouTube-like translucent indicator for volume and seek feedback. It fades
/// out on its own shortly after the last event.
class PlayerOsd extends StatefulWidget {
  final ValueListenable<OsdEvent?> events;
  const PlayerOsd({super.key, required this.events});

  @override
  State<PlayerOsd> createState() => _PlayerOsdState();
}

class _PlayerOsdState extends State<PlayerOsd> {
  static const _visibleFor = Duration(milliseconds: 800);

  OsdEvent? _event;
  bool _visible = false;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    widget.events.addListener(_onEvent);
  }

  @override
  void dispose() {
    widget.events.removeListener(_onEvent);
    _hideTimer?.cancel();
    super.dispose();
  }

  void _onEvent() {
    final event = widget.events.value;
    if (event == null) return;
    setState(() {
      _event = event;
      _visible = true;
    });
    _hideTimer?.cancel();
    _hideTimer = Timer(_visibleFor, () {
      if (mounted) setState(() => _visible = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final event = _event;
    if (event == null) return const SizedBox.shrink();
    return IgnorePointer(
      child: Align(
        alignment: event.alignment,
        child: AnimatedOpacity(
          opacity: _visible ? 1 : 0,
          duration: Duration(milliseconds: _visible ? 80 : 300),
          child: Container(
            margin: const EdgeInsets.all(48),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(event.icon, color: Colors.white, size: 28),
                const SizedBox(width: 10),
                Text(
                  event.text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
