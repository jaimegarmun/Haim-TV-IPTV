import 'package:open_tv/l10n/l10n.dart';

class Validators {
  static String? notEmpty(String? value) {
    if (value == null || value.isEmpty) {
      return tr("This field is required");
    }
    return null;
  }
}
