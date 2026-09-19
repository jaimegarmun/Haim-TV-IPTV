import 'package:open_tv/l10n/l10n.dart';

enum SortType { alphabeticalAsc, alphabeticalDesc, provider }

String sortTypeToString(SortType sort) {
  switch (sort) {
    case SortType.alphabeticalAsc:
      return tr("Alphabetical ASC");
    case SortType.alphabeticalDesc:
      return tr("Alphabetical DESC");
    case SortType.provider:
      return tr("Provider");
  }
}
