import 'package:open_tv/l10n/l10n.dart';

enum ViewType { all, categories, favorites, history, settings }

String viewTypeToString(ViewType vw) {
  switch (vw) {
    case ViewType.all:
      return tr("All");
    case ViewType.categories:
      return tr("Categories");
    case ViewType.favorites:
      return tr("Favorites");
    case ViewType.history:
      return tr("History");
    default:
      return tr("All");
  }
}
