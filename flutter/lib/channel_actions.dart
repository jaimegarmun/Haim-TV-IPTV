import 'package:flutter/material.dart';
import 'package:open_tv/error.dart';
import 'package:open_tv/home.dart';
import 'package:open_tv/memory.dart';
import 'package:open_tv/models/channel.dart';
import 'package:open_tv/models/filters.dart';
import 'package:open_tv/models/home_manager.dart';
import 'package:open_tv/models/media_type.dart';
import 'package:open_tv/models/node.dart';
import 'package:open_tv/models/node_type.dart';
import 'package:open_tv/models/view_type.dart';
import 'package:open_tv/native_bridge.dart';
import 'package:open_tv/services/download_manager.dart';
import 'package:open_tv/services/favorite_folders.dart';
import 'package:open_tv/services/watch_progress.dart';

/// Same page size as the Rust search.
const int nativePageSize = 36;

/// Loads every page of [filters]. The Rust side stores the page in a u8, so
/// never go past [maxPages].
Future<List<Channel>> getAllChannels(
  Filters filters, {
  int maxPages = 250,
}) async {
  final all = <Channel>[];
  for (var page = 1; page <= maxPages; page++) {
    filters.page = page;
    final channels = await NativeBridge.instance.getChannels(filters);
    all.addAll(channels);
    if (channels.length < nativePageSize) break;
  }
  return all;
}

/// Opens a category, series or season the same way the main list does.
void openNode(
  BuildContext context,
  Node node, {
  required bool tvMode,
  List<int>? sourceIds,
}) {
  final filters = Filters(viewType: ViewType.all, sourceIds: sourceIds);
  if (node.type == NodeType.category) filters.groupId = node.id;
  if (node.type == NodeType.series) filters.seriesId = node.id;
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => Home(
        home: HomeManager(node: node, filters: filters),
        tvMode: tvMode,
      ),
    ),
  );
}

Future<void> _toggleFavorite(BuildContext context, Channel channel) async {
  await Error.tryAsyncNoLoading(() async {
    await NativeBridge.instance.favorite(channel.id!, !channel.favorite);
    channel.favorite = !channel.favorite;
  }, context);
  if (context.mounted) {
    Error.showSuccess(
      context,
      channel.favorite ? "Added to favorites" : "Removed from favorites",
    );
  }
}

/// Asks for a folder name. Returns null when cancelled.
Future<String?> askFolderName(
  BuildContext context, {
  String title = "New folder",
  String initial = "",
}) {
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(hintText: "Folder name"),
        onSubmitted: (value) => Navigator.of(context).pop(value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text("Cancel"),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(controller.text),
          child: const Text("Save"),
        ),
      ],
    ),
  ).then((value) => value?.trim().isEmpty ?? true ? null : value!.trim());
}

Future<void> _addToFolder(BuildContext context, Channel channel) async {
  final store = FavoriteFoldersStore.instance;
  final choice = await showDialog<String>(
    context: context,
    builder: (context) => SimpleDialog(
      title: const Text("Add to folder"),
      children: [
        for (final (index, folder) in store.folders.indexed)
          ListTile(
            autofocus: index == 0,
            leading: Icon(
              store.contains(folder.id, channel)
                  ? Icons.check_box
                  : Icons.folder,
            ),
            title: Text(folder.name),
            onTap: () => Navigator.of(context).pop(folder.id),
          ),
        ListTile(
          autofocus: store.folders.isEmpty,
          leading: const Icon(Icons.create_new_folder),
          title: const Text("New folder..."),
          onTap: () => Navigator.of(context).pop(""),
        ),
      ],
    ),
  );
  if (choice == null || !context.mounted) return;
  var folderId = choice;
  if (folderId.isEmpty) {
    final name = await askFolderName(context);
    if (name == null) return;
    folderId = (await store.create(name)).id;
  }
  await store.add(folderId, channel);
  // Folders live in Favorites, so make sure it is a favorite too.
  if (!channel.favorite && channel.id != null && context.mounted) {
    await Error.tryAsyncNoLoading(() async {
      await NativeBridge.instance.favorite(channel.id!, true);
      channel.favorite = true;
    }, context);
  }
  if (context.mounted) {
    Error.showSuccess(context, "Added to ${store.byId(folderId)?.name}");
  }
}

Future<void> downloadEpisode(BuildContext context, Channel channel) async {
  final info = seasonInfo[channel.seasonId];
  final added = await DownloadManager.instance.enqueue(
    channel,
    seriesName: seriesNames[info?.seriesId ?? channel.seriesId],
    seasonName: info?.name,
  );
  if (context.mounted) {
    Error.showSuccess(
      context,
      added ? "Download queued: ${channel.name}" : "Already in downloads",
    );
  }
}

Future<int> _downloadSeason(
  Channel season, {
  required int seriesId,
  required String? seriesName,
  required List<int> sourceIds,
}) async {
  final episodes = await getAllChannels(
    Filters(
      viewType: ViewType.all,
      seriesId: seriesId,
      seasonId: season.id,
      sourceIds: sourceIds,
    ),
  );
  var added = 0;
  for (final episode in episodes) {
    if (await DownloadManager.instance.enqueue(
      episode,
      seriesName: seriesName,
      seasonName: season.name,
    )) {
      added++;
    }
  }
  return added;
}

Future<void> downloadSeason(BuildContext context, Channel season) async {
  final seriesId = season.seriesId ?? seasonInfo[season.id]?.seriesId;
  if (seriesId == null) return;
  await Error.tryAsync(
    () async {
      final sources = season.sourceId > 0
          ? [season.sourceId]
          : await NativeBridge.instance.getEnabledSourcesMinimal();
      final added = await _downloadSeason(
        season,
        seriesId: seriesId,
        seriesName: seriesNames[seriesId],
        sourceIds: sources,
      );
      if (context.mounted) {
        Error.showSuccess(context, "$added episodes queued for download");
      }
    },
    context,
    null,
    true,
    false,
  );
}

Future<void> downloadSeries(BuildContext context, Channel series) async {
  final seriesId = int.tryParse(series.url ?? "");
  if (seriesId == null) return;
  seriesNames[seriesId] = series.name;
  await Error.tryAsync(
    () async {
      await NativeBridge.instance.getEpisodes(
        seriesId,
        series.sourceId,
        series.image,
      );
      refreshedSeries.add(seriesId);
      final seasons = await getAllChannels(
        Filters(
          viewType: ViewType.all,
          seriesId: seriesId,
          sourceIds: [series.sourceId],
        ),
      );
      var added = 0;
      for (final season in seasons) {
        seasonInfo[season.id!] = (seriesId: seriesId, name: season.name);
        added += await _downloadSeason(
          season,
          seriesId: seriesId,
          seriesName: series.name,
          sourceIds: [series.sourceId],
        );
      }
      if (context.mounted) {
        Error.showSuccess(context, "$added episodes queued for download");
      }
    },
    context,
    null,
    true,
    false,
  );
}

/// The long-press menu of a channel tile.
///
/// [folderId] is set when the tile is shown inside a favorites folder.
/// [onChanged] is called after anything that may change how lists look.
Future<void> showChannelOptions(
  BuildContext context,
  Channel channel, {
  String? folderId,
  VoidCallback? onChanged,
}) async {
  final isPlayable =
      channel.mediaType != MediaType.group &&
      channel.mediaType != MediaType.season;
  final download = DownloadManager.instance.find(channel.url);
  final watched = WatchProgressStore.instance.isWatched(channel.url);

  final actions = <(IconData, String, Future<void> Function())>[
    if (isPlayable && channel.id != null)
      (
        channel.favorite ? Icons.star_border : Icons.star,
        channel.favorite ? "Remove from favorites" : "Add to favorites",
        () => _toggleFavorite(context, channel),
      ),
    if (isPlayable)
      (
        Icons.create_new_folder,
        "Add to folder...",
        () => _addToFolder(context, channel),
      ),
    if (folderId != null)
      (
        Icons.folder_off,
        "Remove from this folder",
        () => FavoriteFoldersStore.instance.remove(folderId, channel),
      ),
    if (DownloadManager.canDownload(channel) && download == null)
      (Icons.download, "Download", () => downloadEpisode(context, channel)),
    if (download != null &&
        (download.status == DownloadStatus.downloading ||
            download.status == DownloadStatus.queued))
      (
        Icons.pause,
        "Pause download",
        () => DownloadManager.instance.pause(download.url),
      ),
    if (download != null &&
        (download.status == DownloadStatus.paused ||
            download.status == DownloadStatus.failed))
      (
        Icons.play_arrow,
        "Resume download",
        () => DownloadManager.instance.resume(download.url),
      ),
    if (download != null)
      (
        Icons.delete,
        "Delete download",
        () => DownloadManager.instance.remove(download.url),
      ),
    if (channel.mediaType == MediaType.serie)
      (
        Icons.download,
        "Download entire series",
        () => downloadSeries(context, channel),
      ),
    if (channel.mediaType == MediaType.season)
      (
        Icons.download,
        "Download season",
        () => downloadSeason(context, channel),
      ),
    if (channel.mediaType == MediaType.movie)
      (
        watched ? Icons.remove_done : Icons.check_circle,
        watched ? "Mark as unwatched" : "Mark as watched",
        () async => WatchProgressStore.instance.setWatched(
          channel.url,
          channel.name,
          !watched,
        ),
      ),
  ];
  if (actions.isEmpty) return;

  final selected = await showDialog<int>(
    context: context,
    builder: (context) => SimpleDialog(
      title: Text(channel.name, maxLines: 2, overflow: TextOverflow.ellipsis),
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
  if (selected == null || !context.mounted) return;
  await actions[selected].$3();
  onChanged?.call();
}
