import 'package:flutter/material.dart';
import 'package:open_tv/back_navigation.dart';
import 'package:open_tv/downloads_view.dart';
import 'package:open_tv/favorites_hub.dart';
import 'package:open_tv/home.dart';
import 'package:open_tv/menu_tile.dart';
import 'package:open_tv/models/filters.dart';
import 'package:open_tv/models/home_manager.dart';
import 'package:open_tv/models/media_type.dart';
import 'package:open_tv/models/view_type.dart';
import 'package:open_tv/settings_view.dart';
import 'package:open_tv/tv_live_folders.dart';
import 'package:open_tv/update_dialog.dart';
import 'package:open_tv/utils.dart';

class TvHome extends StatefulWidget {
  final bool nested;
  final ViewType? previousViewType;
  const TvHome({super.key, this.nested = false, this.previousViewType});

  @override
  State<TvHome> createState() => _TvHomeState();
}

class _TvHomeState extends State<TvHome> {
  @override
  void initState() {
    super.initState();
    if (!widget.nested) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await Utils.maybeShowWhatsNew(context);
        if (mounted) await maybeOfferUpdate(context);
      });
    }
  }

  void navigateHome(Filters filters) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            Home(home: HomeManager(filters: filters), tvMode: true),
      ),
    );
  }

  void navNested(ViewType viewType) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => TvHome(nested: true, previousViewType: viewType),
      ),
    );
  }

  void navPage(Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (context) => page));
  }

  void navSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const SettingsView(tvMode: true)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.nested ? tvBackAppBar(context) : null,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Wrap(
              alignment: WrapAlignment.center,
              children: widget.nested ? getMediaTypeSelectNested() : getHome(),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> getMediaTypeSelectNested() {
    return [
      MenuTile(
        autofocus: true,
        icon: Icons.list,
        label: "All",
        color: const LinearGradient(
          colors: [Colors.blueGrey, Colors.blue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        onTap: () => navigateHome(
          Filters(
            viewType: widget.previousViewType!,
            mediaTypes: [
              MediaType.livestream,
              MediaType.movie,
              MediaType.serie,
            ],
          ),
        ),
      ),
      MenuTile(
        icon: Icons.live_tv,
        label: "Live",
        color: const LinearGradient(
          colors: [Colors.amber, Colors.deepOrange],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        onTap: () => navigateHome(
          Filters(
            viewType: widget.previousViewType!,
            mediaTypes: [MediaType.livestream],
          ),
        ),
      ),
      MenuTile(
        icon: Icons.movie,
        label: "Vods",
        color: LinearGradient(
          colors: [Colors.red, Colors.red.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        onTap: () => navigateHome(
          Filters(
            viewType: widget.previousViewType!,
            mediaTypes: [MediaType.movie],
          ),
        ),
      ),
      MenuTile(
        icon: Icons.local_movies,
        label: "Series",
        color: const LinearGradient(
          colors: [Colors.purple, Colors.deepPurple],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        onTap: () => navigateHome(
          Filters(
            viewType: widget.previousViewType!,
            mediaTypes: [MediaType.serie],
          ),
        ),
      ),
    ];
  }

  List<Widget> getHome() {
    return [
      MenuTile(
        autofocus: true,
        icon: Icons.live_tv,
        label: "Live TV",
        color: const LinearGradient(
          colors: [Colors.red, Colors.deepOrange],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        onTap: () => navPage(const TvLiveFolders()),
      ),
      MenuTile(
        icon: Icons.tv,
        label: "Channels",
        color: const LinearGradient(
          colors: [Colors.blueGrey, Colors.blue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        onTap: () => navNested(ViewType.all),
      ),
      MenuTile(
        icon: Icons.dashboard,
        label: "Categories",
        color: const LinearGradient(
          colors: [Colors.purple, Colors.deepPurple],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        onTap: () => navNested(ViewType.categories),
      ),
      MenuTile(
        icon: Icons.star,
        label: "Favorites",
        color: LinearGradient(
          colors: [Colors.orange.shade700, Colors.amber.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        onTap: () => navPage(
          FavoritesHub(openAllFavorites: () => navNested(ViewType.favorites)),
        ),
      ),
      MenuTile(
        icon: Icons.history,
        label: "History",
        color: LinearGradient(
          colors: [Colors.teal.shade700, Colors.green.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        onTap: () => navNested(ViewType.history),
      ),
      MenuTile(
        icon: Icons.download_for_offline,
        label: "Downloads",
        color: LinearGradient(
          colors: [Colors.indigo.shade700, Colors.lightBlue.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        onTap: () => navPage(const DownloadsView(tvMode: true)),
      ),
      MenuTile(
        icon: Icons.settings,
        label: "Settings",
        color: LinearGradient(
          colors: [Colors.blueGrey.shade800, Colors.blueGrey.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        onTap: () => navSettings(),
      ),
    ];
  }
}
