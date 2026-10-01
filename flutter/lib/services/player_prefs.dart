import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:open_tv/services/json_file.dart';

/// Player settings that are not part of the Rust settings: the volume to
/// restore on the next video and how live channels are buffered.
class PlayerPrefs extends ChangeNotifier {
  static final PlayerPrefs instance = PlayerPrefs._();
  PlayerPrefs._();

  final _file = JsonFile("player_prefs.json");
  Timer? _saveDebounce;

  double _volume = 100;
  bool _liveRewind = true;

  /// Volume of the desktop player, kept between videos and restarts.
  double get volume => _volume;

  /// Whether live channels keep what was already watched so it can be
  /// rewound. Turning it off plays live channels the simple way, which
  /// uses less memory on slow connections.
  bool get liveRewind => _liveRewind;

  Future<void> load() async {
    final data = await _file.read();
    if (data is! Map) return;
    final volume = data["volume"];
    if (volume is num) _volume = volume.toDouble().clamp(0, 100);
    final liveRewind = data["liveRewind"];
    if (liveRewind is bool) _liveRewind = liveRewind;
  }

  /// Called while the user changes the volume: saving is debounced.
  void setVolume(double volume) {
    final clamped = volume.clamp(0.0, 100.0);
    if (clamped == _volume) return;
    _volume = clamped;
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(seconds: 2), _save);
  }

  Future<void> setLiveRewind(bool enabled) async {
    _liveRewind = enabled;
    notifyListeners();
    await _save();
  }

  Future<void> _save() async {
    _saveDebounce?.cancel();
    await _file.write({"volume": _volume, "liveRewind": _liveRewind});
  }

  /// Writes a pending volume change right away (when leaving the player).
  Future<void> flush() async {
    if (_saveDebounce?.isActive ?? false) await _save();
  }
}
