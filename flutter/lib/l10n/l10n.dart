import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/foundation.dart';
import 'package:open_tv/l10n/es.dart';
import 'package:open_tv/services/json_file.dart';

enum AppLanguage { system, en, es }

/// The language of the interface. English is the source language: every
/// text in the code is written in English and passed through [tr].
class L10n extends ChangeNotifier {
  static final L10n instance = L10n._();
  L10n._();

  final _file = JsonFile("language.json");
  AppLanguage _language = AppLanguage.system;

  AppLanguage get language => _language;

  /// The language actually shown ("en" or "es").
  String get code {
    switch (_language) {
      case AppLanguage.en:
        return "en";
      case AppLanguage.es:
        return "es";
      case AppLanguage.system:
        final system = PlatformDispatcher.instance.locale.languageCode;
        return system == "es" ? "es" : "en";
    }
  }

  Future<void> load() async {
    final data = await _file.read();
    if (data is Map) {
      _language = AppLanguage.values.firstWhere(
        (l) => l.name == data["language"],
        orElse: () => AppLanguage.system,
      );
    }
  }

  Future<void> setLanguage(AppLanguage language) async {
    _language = language;
    notifyListeners();
    await _file.write({"language": language.name});
  }
}

/// Translates an English text into the current language. Placeholders like
/// `{name}` are replaced with [args].
///
/// A text missing from the translations is shown in English.
String tr(String english, [Map<String, Object?> args = const {}]) {
  var text = english;
  if (L10n.instance.code == "es") text = esTranslations[english] ?? english;
  args.forEach((key, value) => text = text.replaceAll("{$key}", "$value"));
  return text;
}

/// "1 item" / "3 items": [one] and [many] may use `{count}`.
String trPlural(int count, String one, String many) =>
    tr(count == 1 ? one : many, {"count": count});
