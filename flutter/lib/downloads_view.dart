import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:open_tv/back_navigation.dart';
import 'package:open_tv/side_margins.dart';
import 'package:open_tv/confirm_delete.dart';
import 'package:open_tv/exo_player.dart';
import 'package:open_tv/held_key_guard.dart';
import 'package:open_tv/l10n/l10n.dart';
import 'package:open_tv/native_bridge.dart';
import 'package:open_tv/player.dart';
import 'package:open_tv/services/download_manager.dart';
import 'package:open_tv/services/watch_progress.dart';

/// Downloaded movies and episodes. Works offline.
class DownloadsView extends StatelessWidget {
  final bool tvMode;
  const DownloadsView({super.key, this.tvMode = false});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr("Downloads")),
        automaticallyImplyLeading: showBackArrow(tvMode),
      ),
      body: SafeArea(
        minimum: sideMarginInsets(context),
        child: ListenableBuilder(
          listenable: Listenable.merge([
            DownloadManager.instance,
            WatchProgressStore.instance,
          ]),
          builder: (context, _) {
            final items = DownloadManager.instance.items;
            if (items.isEmpty) {
              return Center(
                child: Focus(
                  autofocus: true,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      tr(
                        "No downloads yet.\nHold a movie or episode (or long-press it) and choose \"Download\".",
                      ),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ),
              );
            }
            return ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: _buildGroups(context, items),
            );
          },
        ),
      ),
    );
  }

  List<Widget> _buildGroups(BuildContext context, List<DownloadItem> items) {
    final movies = items.where((i) => !i.isEpisode).toList();
    final bySeries = <String, List<DownloadItem>>{};
    for (final item in items.where((i) => i.isEpisode)) {
      bySeries.putIfAbsent(item.seriesName ?? tr("Series"), () => []).add(item);
    }
    var first = true;
    Widget tile(DownloadItem item) {
      final widget = _DownloadTile(item: item, autofocus: first);
      first = false;
      return widget;
    }

    return [
      if (movies.isNotEmpty) ...[
        _header(context, tr("Movies")),
        for (final item in movies) tile(item),
      ],
      for (final entry in bySeries.entries) ...[
        _header(context, entry.key),
        for (final season in _bySeason(entry.value).entries) ...[
          if (season.key.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 16, 0),
              child: Text(
                season.key,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
          for (final item in season.value) tile(item),
        ],
      ],
    ];
  }

  Map<String, List<DownloadItem>> _bySeason(List<DownloadItem> items) {
    final map = <String, List<DownloadItem>>{};
    for (final item in items) {
      map.putIfAbsent(item.seasonName ?? "", () => []).add(item);
    }
    for (final list in map.values) {
      list.sort((a, b) => (a.episodeNum ?? 0).compareTo(b.episodeNum ?? 0));
    }
    return map;
  }

  Widget _header(BuildContext context, String title) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
    child: Text(title, style: Theme.of(context).textTheme.titleLarge),
  );
}

class _DownloadTile extends StatelessWidget {
  final DownloadItem item;
  final bool autofocus;
  const _DownloadTile({required this.item, this.autofocus = false});

  String _statusText() {
    final size = item.totalBytes > 0
        ? "${formatBytes(item.receivedBytes)} / ${formatBytes(item.totalBytes)}"
        : formatBytes(item.receivedBytes);
    switch (item.status) {
      case DownloadStatus.completed:
        final progress = WatchProgressStore.instance.get(item.url);
        final watched = progress?.watched ?? false;
        final resume = WatchProgressStore.instance.resumePosition(item.url);
        return [
          formatBytes(item.totalBytes),
          if (watched) tr("Watched"),
          if (resume != null)
            tr("Resume at {time}", {"time": formatSeconds(resume)}),
        ].join(" · ");
      case DownloadStatus.downloading:
        final pct = item.fraction != null
            ? " (${(item.fraction! * 100).toStringAsFixed(0)}%)"
            : "";
        return tr("Downloading {size}", {"size": "$size$pct"});
      case DownloadStatus.queued:
        return tr("Waiting...");
      case DownloadStatus.paused:
        return tr("Paused · {size}", {"size": size});
      case DownloadStatus.failed:
        return tr("Failed: {error}", {
          "error": item.error ?? tr("unknown error"),
        });
    }
  }

  IconData _icon() {
    switch (item.status) {
      case DownloadStatus.completed:
        return WatchProgressStore.instance.isWatched(item.url)
            ? Icons.check_circle
            : Icons.play_circle;
      case DownloadStatus.downloading:
        return Icons.downloading;
      case DownloadStatus.queued:
        return Icons.schedule;
      case DownloadStatus.paused:
        return Icons.pause_circle;
      case DownloadStatus.failed:
        return Icons.error;
    }
  }

  Future<void> _play(BuildContext context) async {
    final settings = await NativeBridge.instance.getSettings();
    if (!context.mounted) return;
    final channel = item.toChannel();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Platform.isAndroid
            ? ExoPlayerScreen(channel: channel, settings: settings)
            : Player(channel: channel, settings: settings),
      ),
    );
  }

  Future<void> _showActions(BuildContext context) async {
    final manager = DownloadManager.instance;
    final actions = <(IconData, String, VoidCallback)>[
      if (item.status == DownloadStatus.completed)
        (Icons.play_arrow, tr("Play"), () => _play(context)),
      if (item.status == DownloadStatus.downloading ||
          item.status == DownloadStatus.queued)
        (Icons.pause, tr("Pause"), () => manager.pause(item.url)),
      if (item.status == DownloadStatus.paused ||
          item.status == DownloadStatus.failed)
        (
          Icons.play_arrow,
          tr("Resume download"),
          () => manager.resume(item.url),
        ),
      if (item.status == DownloadStatus.completed)
        (
          WatchProgressStore.instance.isWatched(item.url)
              ? Icons.remove_done
              : Icons.check_circle,
          WatchProgressStore.instance.isWatched(item.url)
              ? tr("Mark as unwatched")
              : tr("Mark as watched"),
          () => WatchProgressStore.instance.setWatched(
            item.url,
            item.name,
            !WatchProgressStore.instance.isWatched(item.url),
          ),
        ),
      (
        Icons.delete,
        tr("Delete"),
        () => showDialog(
          context: context,
          builder: (_) => ConfirmDelete(
            name: item.name,
            type: "the download",
            confirm: () => manager.remove(item.url),
          ),
        ),
      ),
    ];
    final selected = await showHeldKeySafeDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(item.name, maxLines: 2, overflow: TextOverflow.ellipsis),
        children: [
          for (final (index, action) in actions.indexed)
            ListTile(
              autofocus: index == 0,
              leading: Icon(action.$1),
              title: Text(action.$2),
              onTap: () => Navigator.of(context).pop(index),
            ),
        ],
      ),
    );
    if (selected != null && context.mounted) actions[selected].$3();
  }

  @override
  Widget build(BuildContext context) {
    final showBar =
        item.status == DownloadStatus.downloading ||
        item.status == DownloadStatus.paused;
    return GestureDetector(
      onSecondaryTap: () => _showActions(context),
      child: _buildTile(context, showBar),
    );
  }

  Widget _buildTile(BuildContext context, bool showBar) {
    return ListTile(
      autofocus: autofocus,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      leading: Icon(
        _icon(),
        size: 32,
        color: item.status == DownloadStatus.failed ? Colors.redAccent : null,
      ),
      title: Text(item.name, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_statusText(), maxLines: 2, overflow: TextOverflow.ellipsis),
          if (showBar)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: LinearProgressIndicator(value: item.fraction),
            ),
        ],
      ),
      onTap: () => item.status == DownloadStatus.completed
          ? _play(context)
          : _showActions(context),
      onLongPress: () => _showActions(context),
      trailing: IconButton(
        icon: const Icon(Icons.more_vert),
        onPressed: () => _showActions(context),
      ),
    );
  }
}
