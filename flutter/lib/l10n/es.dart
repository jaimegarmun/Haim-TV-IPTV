import 'package:open_tv/l10n/es_browse.dart';
import 'package:open_tv/l10n/es_core.dart';
import 'package:open_tv/l10n/es_setup_player.dart';

/// Spanish texts, keyed by the English text used in the code. Split by area
/// so each file stays readable.
final Map<String, String> esTranslations = {
  ...esCore,
  ...esBrowse,
  ...esSetupPlayer,
};
