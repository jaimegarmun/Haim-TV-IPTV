import 'package:flutter/foundation.dart';
import 'package:open_tv/models/channel.dart';
import 'package:open_tv/models/filters.dart';
import 'package:open_tv/models/media_type.dart';
import 'package:open_tv/models/view_type.dart';
import 'package:open_tv/native_bridge.dart';
import 'package:open_tv/services/json_file.dart';

/// A snapshot of a channel saved in a folder. Channels are matched again by
/// source + name (+ url) when the folder is opened, because channel ids
/// change every time a source is refreshed.
class FolderItem {
  final int sourceId;
  final String name;
  final String? url;
  final MediaType mediaType;
  final String? image;

  const FolderItem({
    required this.sourceId,
    required this.name,
    required this.mediaType,
    this.url,
    this.image,
  });

  factory FolderItem.fromChannel(Channel channel) => FolderItem(
    sourceId: channel.sourceId,
    name: channel.name,
    url: channel.url,
    mediaType: channel.mediaType,
    image: channel.image,
  );

  bool matches(Channel channel) =>
      channel.sourceId == sourceId &&
      channel.name == name &&
      channel.mediaType == mediaType;

  Channel toChannel() => Channel(
    name: name,
    url: url,
    image: image,
    mediaType: mediaType,
    sourceId: sourceId,
    favorite: true,
  );

  Map<String, Object?> toJson() => {
    "source_id": sourceId,
    "name": name,
    "url": url,
    "media_type": mediaType.index,
    "image": image,
  };

  static FolderItem fromJson(Map<String, dynamic> json) => FolderItem(
    sourceId: (json["source_id"] as num).toInt(),
    name: json["name"] as String,
    url: json["url"] as String?,
    mediaType: MediaType.values[(json["media_type"] as num).toInt()],
    image: json["image"] as String?,
  );
}

class FavoriteFolder {
  final String id;
  String name;
  final List<FolderItem> items;

  FavoriteFolder({required this.id, required this.name, required this.items});

  Map<String, Object?> toJson() => {
    "id": id,
    "name": name,
    "items": items.map((i) => i.toJson()).toList(),
  };

  static FavoriteFolder fromJson(Map<String, dynamic> json) => FavoriteFolder(
    id: json["id"] as String,
    name: json["name"] as String,
    items: ((json["items"] as List?) ?? [])
        .map((i) => FolderItem.fromJson(i as Map<String, dynamic>))
        .toList(),
  );
}

/// User-created folders inside Favorites, stored in `favorite_folders.json`.
class FavoriteFoldersStore extends ChangeNotifier {
  static final FavoriteFoldersStore instance = FavoriteFoldersStore._();
  FavoriteFoldersStore._();

  final JsonFile _file = JsonFile("favorite_folders.json");
  final List<FavoriteFolder> _folders = [];

  List<FavoriteFolder> get folders => List.unmodifiable(_folders);

  Future<void> load() async {
    final data = await _file.read();
    if (data is! Map || data["folders"] is! List) return;
    _folders.clear();
    for (final raw in data["folders"] as List) {
      try {
        _folders.add(FavoriteFolder.fromJson(raw as Map<String, dynamic>));
      } catch (e) {
        debugPrint("Skipping invalid folder: $e");
      }
    }
    notifyListeners();
  }

  FavoriteFolder? byId(String id) {
    for (final folder in _folders) {
      if (folder.id == id) return folder;
    }
    return null;
  }

  Future<FavoriteFolder> create(String name) async {
    final folder = FavoriteFolder(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name.trim(),
      items: [],
    );
    _folders.add(folder);
    await _changed();
    return folder;
  }

  Future<void> rename(String id, String name) async {
    final folder = byId(id);
    if (folder == null) return;
    folder.name = name.trim();
    await _changed();
  }

  Future<void> delete(String id) async {
    _folders.removeWhere((f) => f.id == id);
    await _changed();
  }

  bool contains(String folderId, Channel channel) =>
      byId(folderId)?.items.any((i) => i.matches(channel)) ?? false;

  List<FavoriteFolder> foldersContaining(Channel channel) =>
      _folders.where((f) => f.items.any((i) => i.matches(channel))).toList();

  Future<void> add(String folderId, Channel channel) async {
    final folder = byId(folderId);
    if (folder == null || contains(folderId, channel)) return;
    folder.items.add(FolderItem.fromChannel(channel));
    await _changed();
  }

  Future<void> remove(String folderId, Channel channel) async {
    final folder = byId(folderId);
    if (folder == null) return;
    folder.items.removeWhere((i) => i.matches(channel));
    await _changed();
  }

  /// Finds the current channels for the items of [folderId]. Items whose
  /// channel no longer exists are returned as their saved snapshot.
  Future<List<Channel>> resolve(String folderId) async {
    final folder = byId(folderId);
    if (folder == null) return [];
    return Future.wait(folder.items.map(_resolveItem));
  }

  Future<Channel> _resolveItem(FolderItem item) async {
    try {
      final candidates = await NativeBridge.instance.getChannels(
        Filters(
          query: item.name,
          sourceIds: [item.sourceId],
          mediaTypes: [item.mediaType],
          viewType: ViewType.all,
        ),
      );
      final sameName = candidates.where((c) => c.name == item.name).toList();
      return sameName.where((c) => c.url == item.url).firstOrNull ??
          sameName.firstOrNull ??
          item.toChannel();
    } catch (e) {
      debugPrint("Failed to resolve folder item ${item.name}: $e");
      return item.toChannel();
    }
  }

  Future<void> _changed() async {
    notifyListeners();
    await _file.write({
      "version": 1,
      "folders": _folders.map((f) => f.toJson()).toList(),
    });
  }
}
