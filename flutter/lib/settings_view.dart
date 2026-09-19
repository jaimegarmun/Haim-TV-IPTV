import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:open_tv/back_navigation.dart';
import 'package:open_tv/native_bridge.dart';
import 'package:open_tv/l10n/l10n.dart';
import 'package:open_tv/services/download_manager.dart';
import 'package:open_tv/services/source_names.dart';
import 'package:open_tv/services/update_checker.dart';
import 'package:open_tv/update_dialog.dart';
import 'package:open_tv/side_margins.dart';
import 'package:open_tv/bottom_nav.dart';
import 'package:open_tv/confirm_delete.dart';
import 'package:open_tv/models/filters.dart';
import 'package:open_tv/select_dialog.dart';
import 'package:open_tv/edit_dialog.dart';
import 'package:open_tv/home.dart';
import 'package:open_tv/loading.dart';
import 'package:open_tv/models/home_manager.dart';
import 'package:open_tv/models/id_data.dart';
import 'package:open_tv/models/settings.dart';
import 'package:open_tv/models/source.dart';
import 'package:open_tv/models/source_type.dart';
import 'package:open_tv/models/sort_type.dart';
import 'package:open_tv/models/view_type.dart';
import 'package:open_tv/error.dart';
import 'package:open_tv/setup.dart';
import 'package:open_tv/tv_home.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsView extends StatefulWidget {
  final bool tvMode;

  const SettingsView({super.key, this.tvMode = false});

  @override
  State<SettingsView> createState() => _SettingsState();
}

class _SettingsState extends State<SettingsView> {
  Settings settings = Settings();
  List<Source> sources = [];
  bool loading = true;
  bool checkUpdatesOnStart = true;
  @override
  void initState() {
    super.initState();
    initAsync();
  }

  Future<void> initAsync() async {
    var results = await Future.wait([
      NativeBridge.instance.getSettings(),
      NativeBridge.instance.getSources(),
      UpdateChecker.instance.isCheckOnStartEnabled(),
    ]);
    setState(() {
      settings = results[0] as Settings;
      sources = results[1] as List<Source>;
      checkUpdatesOnStart = results[2] as bool;
      loading = false;
    });
  }

  Future<void> checkForUpdatesNow() async {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(tr("Checking for updates..."))));
    final release = await UpdateChecker.instance.checkNow();
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    if (release == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr("You have the latest version"))),
      );
      return;
    }
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => UpdateDialog(release: release),
    );
    // "Don't show again" may have been chosen.
    final enabled = await UpdateChecker.instance.isCheckOnStartEnabled();
    if (mounted) setState(() => checkUpdatesOnStart = enabled);
  }

  void updateView(ViewType view) {
    if (view != ViewType.settings) {
      Navigator.pushAndRemoveUntil(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => Home(
            tvMode: widget.tvMode,
            home: HomeManager(filters: Filters(viewType: view)),
          ),
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
          transitionsBuilder: (context, animation, secondaryAnimation, child) =>
              child,
        ),
        (route) => false,
      );
    }
  }

  Future<void> showEditDialog(BuildContext context, final Source source) async {
    await showDialog(
      barrierDismissible: true,
      context: context,
      builder: (builder) => EditDialog(
        source: source,
        afterSave: reloadSources,
        parentContext: context,
      ),
    );
  }

  Future<void> _showDefaultViewDialog(BuildContext context) async {
    showDialog(
      barrierDismissible: true,
      context: context,
      builder: (BuildContext context) {
        return SelectDialog(
          title: tr("Default view"),
          data: ViewType.values
              .take(4)
              .map((x) => IdData(id: x.index, data: viewTypeToString(x)))
              .toList(),
          action: (view) {
            setState(() {
              settings.defaultView = ViewType.values[view];
              updateSettings();
            });
            Navigator.of(context).pop();
          },
        );
      },
    );
  }

  static String _languageName(AppLanguage language) {
    switch (language) {
      case AppLanguage.system:
        return tr("System language");
      case AppLanguage.en:
        return "English";
      case AppLanguage.es:
        return "Español";
    }
  }

  Future<void> _showLanguageDialog(BuildContext context) async {
    showDialog(
      barrierDismissible: true,
      context: context,
      builder: (BuildContext context) {
        return SelectDialog(
          title: tr("Language"),
          data: AppLanguage.values
              .map((x) => IdData(id: x.index, data: _languageName(x)))
              .toList(),
          action: (index) async {
            Navigator.of(context).pop();
            final language = AppLanguage.values[index];
            if (language == L10n.instance.language) return;
            await L10n.instance.setLanguage(language);
            if (mounted) _reopenInNewLanguage();
          },
        );
      },
    );
  }

  /// Rebuilds every screen so all texts use the new language, and comes
  /// back to Settings.
  void _reopenInNewLanguage() {
    final navigator = Navigator.of(context);
    if (widget.tvMode) {
      navigator.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const TvHome()),
        (route) => false,
      );
      navigator.push(
        MaterialPageRoute(builder: (_) => const SettingsView(tvMode: true)),
      );
    } else {
      navigator.pushAndRemoveUntil(
        PageRouteBuilder(
          pageBuilder: (_, _, _) => const SettingsView(),
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        ),
        (route) => false,
      );
    }
  }

  Future<void> _showDefaultSortDialog(BuildContext context) async {
    showDialog(
      barrierDismissible: true,
      context: context,
      builder: (BuildContext context) {
        return SelectDialog(
          title: tr("Default sort"),
          data: SortType.values
              .map((x) => IdData(id: x.index, data: sortTypeToString(x)))
              .toList(),
          action: (sort) {
            setState(() {
              settings.defaultSort = SortType.values[sort];
              updateSettings();
            });
            Navigator.of(context).pop();
          },
        );
      },
    );
  }

  Future<void> toggleSource(Source source) async {
    await Error.tryAsyncNoLoading(
      () async => await NativeBridge.instance.setSourceEnabled(
        source.id!,
        !source.enabled,
      ),
      context,
    );
    await reloadSources();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          !source.enabled ? tr("Source enabled") : tr("Source disabled"),
        ),
        duration: const Duration(milliseconds: 500),
      ),
    );
  }

  Widget getSource(Source source) {
    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 5,
      ), // Spacing around the tile
      elevation: 5,
      child: ListTile(
        leading: Icon(source.enabled ? Icons.tv : Icons.tv_off),
        horizontalTitleGap: 25,
        onLongPress: () => toggleSource(source),
        contentPadding: const EdgeInsets.only(left: 20),
        title: Text(source.name),
        subtitle: Text(
          source.enabled
              ? source.sourceType.label
              : tr("{type} · Disabled (hidden, not deleted)", {
                  "type": source.sourceType.label,
                }),
        ),
        trailing: Row(
          mainAxisSize:
              MainAxisSize.min, // Ensures the row takes up minimal space
          children: [
            Tooltip(
              message: source.enabled
                  ? tr("Disable (hide its channels)")
                  : tr("Enable"),
              child: Switch(
                value: source.enabled,
                onChanged: (_) => toggleSource(source),
              ),
            ),
            Offstage(
              offstage: source.sourceType == SourceType.m3u,
              child: IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () async {
                  await Error.tryAsync(
                    () async {
                      await NativeBridge.instance.refreshSource(source);
                    },
                    context,
                    tr("Source has been refreshed successfully"),
                  );
                },
              ),
            ),
            Offstage(
              offstage: source.sourceType == SourceType.m3u || widget.tvMode,
              child: IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () async => await showEditDialog(context, source),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () async => await showConfirmDeleteDialog(source),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> showConfirmDeleteDialog(Source source) async {
    await showDialog(
      barrierDismissible: true,
      context: context,
      builder: (builder) => ConfirmDelete(
        type: tr("the source"),
        name: source.name,
        confirm: () async {
          await Error.tryAsync(
            () async => await NativeBridge.instance.deleteSource(source.id!),
            context,
            tr("Successfully deleted source"),
          );
          await reloadSources();
          if (!mounted) return;
          if (sources.isEmpty) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder: (context) => Setup(tvMode: widget.tvMode),
              ),
              (route) => false,
            );
          }
        },
      ),
    );
  }

  Future<void> reloadSources() async {
    await Error.tryAsyncNoLoading(
      () async => sources = await NativeBridge.instance.getSources(),
      context,
    );
    await SourceNames.instance.load();
    setState(() {
      sources;
    });
  }

  Future<void> _chooseDownloadFolder() async {
    final manager = DownloadManager.instance;
    final path = await FilePicker.platform.getDirectoryPath(
      dialogTitle: tr("Choose the download folder"),
      initialDirectory: await manager.currentDirectory(),
    );
    if (path == null || !mounted) return;
    await Error.tryAsync(
      () => manager.setDirectory(path),
      context,
      tr("New downloads will be saved in {path}", {"path": path}),
      false,
    );
  }

  Future<void> _resetDownloadFolder() async {
    await Error.tryAsync(
      () => DownloadManager.instance.setDirectory(null),
      context,
      tr("Downloads will be saved in the default folder"),
      false,
    );
  }

  Future<void> _openDownloadFolder() async {
    final path = await DownloadManager.instance.currentDirectory();
    await Directory(path).create(recursive: true);
    await launchUrl(Uri.directory(path));
  }

  Widget _buildDownloadFolderTile() {
    return ListenableBuilder(
      listenable: DownloadManager.instance,
      builder: (context, _) {
        final custom = DownloadManager.instance.customDirectory;
        return FutureBuilder<String>(
          future: DownloadManager.instance.currentDirectory(),
          builder: (context, snapshot) => ListTile(
            title: Text(tr("Download folder")),
            subtitle: Text(
              "${snapshot.data ?? "..."}${custom == null ? "  ${tr("(default)")}" : ""}",
            ),
            onTap: _chooseDownloadFolder,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (Platform.isWindows || Platform.isLinux || Platform.isMacOS)
                  IconButton(
                    tooltip: tr("Open folder"),
                    icon: const Icon(Icons.folder_open),
                    onPressed: _openDownloadFolder,
                  ),
                IconButton(
                  tooltip: tr("Change folder"),
                  icon: const Icon(Icons.edit),
                  onPressed: _chooseDownloadFolder,
                ),
                if (custom != null)
                  IconButton(
                    tooltip: tr("Use the default folder"),
                    icon: const Icon(Icons.restore),
                    onPressed: _resetDownloadFolder,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> updateSettings() async {
    await Error.tryAsyncNoLoading(
      () async => await NativeBridge.instance.updateSettings(settings),
      context,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.tvMode ? tvBackAppBar(context) : null,
      body: Visibility(
        visible: !loading,
        child: Loading(
          child: SafeArea(
            minimum: sideMarginInsets(context),
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(vertical: 10),
              child: ListView(
                children: [
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.only(left: 10),
                    child: Text(
                      tr("Settings"),
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ListTile(
                    leading: const Icon(Icons.language),
                    title: Text(tr("Language")),
                    subtitle: Text(_languageName(L10n.instance.language)),
                    onTap: () => _showLanguageDialog(context),
                  ),
                  ListTile(
                    title: Text(tr("Default view")),
                    subtitle: Text(viewTypeToString(settings.defaultView)),
                    onTap: () async => await _showDefaultViewDialog(context),
                  ),
                  ListTile(
                    title: Text(tr("Default sort")),
                    subtitle: Text(sortTypeToString(settings.defaultSort)),
                    onTap: () async => await _showDefaultSortDialog(context),
                  ),
                  ListTile(
                    title: Text(tr("Force TV Mode")),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Switch(
                          value: settings.forceTVMode,
                          onChanged: (bool value) {
                            setState(() {
                              settings.forceTVMode = value;
                            });
                            updateSettings();
                          },
                        ),
                      ],
                    ),
                  ),
                  ListTile(
                    title: Text(tr("Low latency livestreams")),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Switch(
                          value: settings.lowLatency,
                          onChanged: (bool value) {
                            setState(() {
                              settings.lowLatency = value;
                            });
                            updateSettings();
                          },
                        ),
                      ],
                    ),
                  ),
                  ListTile(
                    title: Text(tr("Refresh sources on start")),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Switch(
                          value: settings.refreshOnStart,
                          onChanged: (bool value) {
                            setState(() {
                              settings.refreshOnStart = value;
                            });
                            updateSettings();
                          },
                        ),
                      ],
                    ),
                  ),
                  ListTile(
                    title: Text(tr("Show livestreams")),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Switch(
                          value: settings.showLivestreams,
                          onChanged: (bool value) {
                            setState(() {
                              settings.showLivestreams = value;
                            });
                            updateSettings();
                          },
                        ),
                      ],
                    ),
                  ),
                  ListTile(
                    title: Text(tr("Show movies")),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Switch(
                          value: settings.showMovies,
                          onChanged: (bool value) {
                            setState(() {
                              settings.showMovies = value;
                            });
                            updateSettings();
                          },
                        ),
                      ],
                    ),
                  ),
                  ListTile(
                    title: Text(tr("Show series")),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Switch(
                          value: settings.showSeries,
                          onChanged: (bool value) {
                            setState(() {
                              settings.showSeries = value;
                            });
                            updateSettings();
                          },
                        ),
                      ],
                    ),
                  ),
                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.only(left: 10),
                    child: Text(
                      tr("Updates"),
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  ListTile(
                    title: Text(tr("Check for updates on start")),
                    trailing: Switch(
                      value: checkUpdatesOnStart,
                      onChanged: (bool value) {
                        setState(() => checkUpdatesOnStart = value);
                        UpdateChecker.instance.setCheckOnStart(value);
                      },
                    ),
                  ),
                  ListTile(
                    title: Text(tr("Check for updates now")),
                    trailing: const Icon(Icons.system_update),
                    onTap: checkForUpdatesNow,
                  ),
                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.only(left: 10),
                    child: Text(
                      tr("Downloads"),
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  _buildDownloadFolderTile(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Text(
                      tr(
                        "Only new downloads use the new folder; existing ones stay where they are.",
                      ),
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 10),
                        child: Text(
                          tr("Sources"),
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            onPressed: () async => await Error.tryAsync(
                              () async =>
                                  await NativeBridge.instance.refreshAll(),
                              context,
                              tr("Successfully refreshed all sources"),
                            ),
                            icon: const Icon(Icons.refresh),
                          ),
                          IconButton(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => Setup(
                                  showAppBar: true,
                                  tvMode: widget.tvMode,
                                ),
                              ),
                            ),
                            icon: const Icon(Icons.add),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ...sources.map(getSource),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: !widget.tvMode
          ? BottomNav(
              updateViewMode: updateView,
              startingView: ViewType.settings,
              tvMode: widget.tvMode,
            )
          : null,
    );
  }
}
