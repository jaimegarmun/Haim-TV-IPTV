import 'package:flutter/material.dart';
import 'package:open_tv/back_navigation.dart';
import 'package:open_tv/side_margins.dart';
import 'package:open_tv/channel_actions.dart';
import 'package:open_tv/channel_grid_view.dart';
import 'package:open_tv/error.dart';
import 'package:open_tv/folder_tile.dart';
import 'package:open_tv/home.dart';
import 'package:open_tv/models/channel.dart';
import 'package:open_tv/models/filters.dart';
import 'package:open_tv/models/home_manager.dart';
import 'package:open_tv/models/media_type.dart';
import 'package:open_tv/models/view_type.dart';
import 'package:open_tv/native_bridge.dart';
import 'package:open_tv/services/channel_grouping.dart';

/// Result of sorting the live categories and channels into folders. Kept for
/// the whole session so going back to this screen is instant.
class _LiveIndex {
  final List<int> sourceIds;
  final Map<Country, List<Channel>> groupsByCountry = {};
  final List<Channel> otherGroups = [];
  final List<Brand> brandsFound = [];
  bool brandsDone = false;
  _LiveIndex(this.sourceIds);
}

_LiveIndex? _cachedIndex;

/// TV "Live TV" screen: automatic folders by network (Movistar, RTVE...) and
/// by country, grouped into world regions.
class TvLiveFolders extends StatefulWidget {
  const TvLiveFolders({super.key});

  @override
  State<TvLiveFolders> createState() => _TvLiveFoldersState();
}

class _TvLiveFoldersState extends State<TvLiveFolders> {
  _LiveIndex? index;
  bool loadingGroups = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool force = false}) async {
    final sourceIds = await NativeBridge.instance.getEnabledSourcesMinimal();
    final cached = _cachedIndex;
    if (!force &&
        cached != null &&
        cached.sourceIds.join(",") == sourceIds.join(",")) {
      setState(() {
        index = cached;
        loadingGroups = false;
      });
      if (!cached.brandsDone) _detectBrands(cached);
      return;
    }
    final newIndex = _LiveIndex(sourceIds);
    _cachedIndex = newIndex;
    setState(() {
      index = newIndex;
      loadingGroups = true;
    });
    if (!mounted) return;
    await Error.tryAsyncNoLoading(() async {
      final groups = await getAllChannels(
        Filters(
          viewType: ViewType.categories,
          mediaTypes: [MediaType.livestream],
          sourceIds: sourceIds,
        ),
      );
      for (final group in groups) {
        final country = detectCountry(group.name);
        if (country == null) {
          newIndex.otherGroups.add(group);
        } else {
          newIndex.groupsByCountry.putIfAbsent(country, () => []).add(group);
        }
      }
    }, context);
    if (!mounted) return;
    setState(() => loadingGroups = false);
    await _detectBrands(newIndex);
  }

  /// A network gets a folder when at least one live channel matches it.
  Future<void> _detectBrands(_LiveIndex target) async {
    final pending = brands
        .where((b) => !target.brandsFound.contains(b))
        .toList();
    const workers = 6;
    var next = 0;
    Future<void> worker() async {
      while (next < pending.length) {
        final brand = pending[next++];
        if (await _brandHasChannels(brand, target.sourceIds)) {
          target.brandsFound.add(brand);
          target.brandsFound.sort(
            (a, b) => brands.indexOf(a).compareTo(brands.indexOf(b)),
          );
          if (mounted && index == target) setState(() {});
        }
      }
    }

    await Future.wait(List.generate(workers, (_) => worker()));
    target.brandsDone = true;
    if (mounted && index == target) setState(() {});
  }

  static Future<bool> _brandHasChannels(
    Brand brand,
    List<int> sourceIds,
  ) async {
    for (final term in brand.terms) {
      try {
        final channels = await NativeBridge.instance.getChannels(
          _liveSearch(term, sourceIds),
        );
        if (channels.any((c) => brand.matches(c.name))) return true;
      } catch (e) {
        debugPrint("Brand search '$term' failed: $e");
      }
    }
    return false;
  }

  static Filters _liveSearch(String term, List<int> sourceIds) => Filters(
    query: term,
    viewType: ViewType.all,
    mediaTypes: [MediaType.livestream],
    sourceIds: sourceIds,
  );

  static Future<List<Channel>> _brandChannels(
    Brand brand,
    List<int> sourceIds,
  ) async {
    final results = <int, Channel>{};
    for (final term in brand.terms) {
      final channels = await getAllChannels(
        _liveSearch(term, sourceIds),
        maxPages: 30,
      );
      for (final channel in channels) {
        if (channel.id != null && brand.matches(channel.name)) {
          results[channel.id!] = channel;
        }
      }
    }
    final list = results.values.toList();
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  void _openBrand(Brand brand) {
    final sourceIds = index!.sourceIds;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChannelGridView(
          title: brand.name,
          tvMode: true,
          loader: () => _brandChannels(brand, sourceIds),
        ),
      ),
    );
  }

  void _openGroups(String title, List<Channel> groups) {
    final sorted = [...groups]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChannelGridView(
          title: title,
          tvMode: true,
          loader: () async => sorted,
        ),
      ),
    );
  }

  void _openHome(ViewType viewType) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Home(
          tvMode: true,
          home: HomeManager(
            filters: Filters(
              viewType: viewType,
              mediaTypes: [MediaType.livestream],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final index = this.index;
    return Scaffold(
      appBar: tvBackAppBar(context, title: "Live TV"),
      body: SafeArea(
        minimum: sideMarginInsets(context),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FolderSection(
                title: "Live TV",
                children: [
                  FolderTile(
                    autofocus: true,
                    title: "All channels",
                    icon: Icons.live_tv,
                    color: Colors.blue.shade700,
                    onTap: () => _openHome(ViewType.all),
                  ),
                  FolderTile(
                    title: "All categories",
                    icon: Icons.dashboard,
                    color: Colors.deepPurple,
                    onTap: () => _openHome(ViewType.categories),
                  ),
                  FolderTile(
                    title: "Rescan folders",
                    icon: Icons.refresh,
                    color: Colors.blueGrey.shade700,
                    onTap: () => _load(force: true),
                  ),
                ],
              ),
              if (index != null) ..._buildBrandSection(index),
              if (loadingGroups)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (index != null)
                ..._buildCountrySections(index),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildBrandSection(_LiveIndex index) {
    return [
      FolderSection(
        title: "Networks",
        children: [
          for (final brand in index.brandsFound)
            FolderTile(
              title: brand.name,
              icon: Icons.tv,
              color: Color(brand.color),
              onTap: () => _openBrand(brand),
            ),
        ],
      ),
      if (!index.brandsDone)
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 10),
              Text("Looking for networks..."),
            ],
          ),
        ),
    ];
  }

  List<Widget> _buildCountrySections(_LiveIndex index) {
    final sections = <Widget>[];
    for (final region in WorldRegion.values) {
      final entries =
          index.groupsByCountry.entries
              .where((e) => e.key.region == region)
              .toList()
            ..sort((a, b) => b.value.length.compareTo(a.value.length));
      if (entries.isEmpty) continue;
      sections.add(
        FolderSection(
          title: region.label,
          children: [
            for (final entry in entries)
              FolderTile(
                title: entry.key.name,
                subtitle: entry.value.length == 1
                    ? "1 category"
                    : "${entry.value.length} categories",
                emoji: entry.key.flag,
                color: _regionColor(region),
                onTap: () => _openGroups(entry.key.name, entry.value),
              ),
          ],
        ),
      );
    }
    if (index.otherGroups.isNotEmpty) {
      sections.add(
        FolderSection(
          title: "Other",
          children: [
            FolderTile(
              title: "Other categories",
              subtitle: "${index.otherGroups.length} categories",
              icon: Icons.folder,
              color: Colors.grey.shade700,
              onTap: () => _openGroups("Other categories", index.otherGroups),
            ),
          ],
        ),
      );
    }
    return sections;
  }

  static Color _regionColor(WorldRegion region) {
    switch (region) {
      case WorldRegion.europe:
        return const Color(0xFF1565C0);
      case WorldRegion.latinAmerica:
        return const Color(0xFF2E7D32);
      case WorldRegion.northAmerica:
        return const Color(0xFFC62828);
      case WorldRegion.arabic:
        return const Color(0xFF6A1B9A);
      case WorldRegion.africa:
        return const Color(0xFFEF6C00);
      case WorldRegion.asia:
        return const Color(0xFFAD1457);
      case WorldRegion.oceania:
        return const Color(0xFF00838F);
    }
  }
}
