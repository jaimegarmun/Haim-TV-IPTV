import 'package:flutter/material.dart';
import 'package:open_tv/back_navigation.dart';
import 'package:open_tv/side_margins.dart';
import 'package:open_tv/channel_actions.dart';
import 'package:open_tv/channel_grid_view.dart';
import 'package:open_tv/confirm_delete.dart';
import 'package:open_tv/folder_tile.dart';
import 'package:open_tv/held_key_guard.dart';
import 'package:open_tv/services/favorite_folders.dart';

/// Opens the channels of a user folder.
void openFavoriteFolder(
  BuildContext context,
  FavoriteFolder folder, {
  required bool tvMode,
}) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => ChannelGridView(
        title: folder.name,
        tvMode: tvMode,
        folderId: folder.id,
        emptyMessage:
            "This folder is empty.\nHold a channel and choose \"Add to folder...\".",
        loader: () => FavoriteFoldersStore.instance.resolve(folder.id),
      ),
    ),
  );
}

/// Rename / delete menu of a user folder.
Future<void> showFolderOptions(
  BuildContext context,
  FavoriteFolder folder,
) async {
  final store = FavoriteFoldersStore.instance;
  final choice = await showHeldKeySafeDialog<int>(
    context: context,
    builder: (context) => SimpleDialog(
      title: Text(folder.name),
      children: [
        ListTile(
          autofocus: true,
          leading: const Icon(Icons.edit),
          title: const Text("Rename"),
          onTap: () => Navigator.of(context).pop(0),
        ),
        ListTile(
          leading: const Icon(Icons.delete),
          title: const Text("Delete folder"),
          onTap: () => Navigator.of(context).pop(1),
        ),
      ],
    ),
  );
  if (!context.mounted) return;
  if (choice == 0) {
    final name = await askFolderName(
      context,
      title: "Rename folder",
      initial: folder.name,
    );
    if (name != null) await store.rename(folder.id, name);
  } else if (choice == 1) {
    await showDialog(
      context: context,
      builder: (_) => ConfirmDelete(
        name: folder.name,
        type: "the folder",
        confirm: () => store.delete(folder.id),
      ),
    );
  }
}

Future<void> createFavoriteFolder(BuildContext context) async {
  final name = await askFolderName(context);
  if (name != null) await FavoriteFoldersStore.instance.create(name);
}

/// A folder shown inside the favorites list, styled like a channel tile.
/// With [folder] null it is the "New folder" tile.
class FavoriteFolderCard extends StatelessWidget {
  final FavoriteFolder? folder;
  final bool tvMode;
  final bool autofocus;
  const FavoriteFolderCard({
    super.key,
    required this.folder,
    required this.tvMode,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    final folder = this.folder;
    final theme = Theme.of(context);
    final count = folder?.items.length ?? 0;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: theme.colorScheme.surfaceContainer,
      child: InkWell(
        autofocus: autofocus,
        borderRadius: BorderRadius.circular(12),
        onTap: folder == null
            ? () => createFavoriteFolder(context)
            : () => openFavoriteFolder(context, folder, tvMode: tvMode),
        onLongPress: folder == null
            ? null
            : () => showFolderOptions(context, folder),
        onSecondaryTap: folder == null
            ? null
            : () => showFolderOptions(context, folder),
        child: Row(
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: Icon(
                folder == null ? Icons.create_new_folder : Icons.folder,
                size: 52,
                color: folder == null ? Colors.grey : Colors.amber.shade600,
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      folder?.name ?? "New folder",
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: theme.textTheme.titleMedium?.fontSize,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (folder != null)
                      Text(
                        count == 1 ? "1 item" : "$count items",
                        style: theme.textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
            ),
            if (folder != null)
              const Padding(
                padding: EdgeInsets.only(right: 8),
                child: Icon(Icons.chevron_right, color: Colors.grey),
              ),
          ],
        ),
      ),
    );
  }
}

/// TV favorites: all favorites plus the user's own folders.
class FavoritesHub extends StatelessWidget {
  /// Opens the classic favorites list (All / Live / Vods / Series).
  final VoidCallback openAllFavorites;
  const FavoritesHub({super.key, required this.openAllFavorites});

  static const _folderColors = [
    Color(0xFF1E88E5),
    Color(0xFF8E24AA),
    Color(0xFF00897B),
    Color(0xFFE53935),
    Color(0xFF6D4C41),
    Color(0xFF3949AB),
    Color(0xFFF4511E),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: tvBackAppBar(context, title: "Favorites"),
      body: SafeArea(
        minimum: sideMarginInsets(context),
        child: ListenableBuilder(
          listenable: FavoriteFoldersStore.instance,
          builder: (context, _) {
            final folders = FavoriteFoldersStore.instance.folders;
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FolderSection(
                    title: "Favorites",
                    children: [
                      FolderTile(
                        autofocus: true,
                        title: "All favorites",
                        icon: Icons.star,
                        color: Colors.orange.shade700,
                        onTap: openAllFavorites,
                      ),
                      FolderTile(
                        title: "New folder",
                        icon: Icons.create_new_folder,
                        color: Colors.blueGrey.shade700,
                        onTap: () => createFavoriteFolder(context),
                      ),
                    ],
                  ),
                  FolderSection(
                    title: "My folders",
                    children: [
                      for (final (index, folder) in folders.indexed)
                        FolderTile(
                          title: folder.name,
                          subtitle: folder.items.length == 1
                              ? "1 item"
                              : "${folder.items.length} items",
                          icon: Icons.folder,
                          color: _folderColors[index % _folderColors.length],
                          onTap: () =>
                              openFavoriteFolder(context, folder, tvMode: true),
                          onLongPress: () => showFolderOptions(context, folder),
                        ),
                    ],
                  ),
                  if (folders.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        "Create a folder, then hold select on any channel and choose \"Add to folder...\".",
                      ),
                    ),
                  if (folders.isNotEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        "Hold select on a folder to rename or delete it.",
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
