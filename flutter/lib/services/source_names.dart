import 'package:flutter/foundation.dart';
import 'package:open_tv/native_bridge.dart';

/// Names of the configured sources (accounts), so each channel tile can show
/// which account it comes from.
class SourceNames extends ChangeNotifier {
  static final SourceNames instance = SourceNames._();
  SourceNames._();

  Map<int, String> _names = {};

  String? nameOf(int sourceId) => _names[sourceId];

  Future<void> load() async {
    try {
      final sources = await NativeBridge.instance.getSources();
      _names = {
        for (final source in sources)
          if (source.id != null) source.id!: source.name,
      };
      notifyListeners();
    } catch (e) {
      debugPrint("Failed to load source names: $e");
    }
  }
}
