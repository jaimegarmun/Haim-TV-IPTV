import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_tv/back_navigation.dart';
import 'package:open_tv/side_margins.dart';
import 'package:open_tv/channel_actions.dart';
import 'package:open_tv/channel_tile.dart';
import 'package:open_tv/error.dart';
import 'package:open_tv/l10n/l10n.dart';
import 'package:open_tv/loading.dart';
import 'package:open_tv/models/channel.dart';
import 'package:open_tv/qwerty_keyboard.dart';
import 'package:open_tv/services/channel_grouping.dart';

/// A full list of channels produced by [loader], shown with the same tiles
/// as the main list. Used by folders (favorites folders, networks, countries).
class ChannelGridView extends StatefulWidget {
  final String title;
  final Future<List<Channel>> Function() loader;
  final bool tvMode;
  final String emptyMessage;

  /// Set when showing a favorites folder, enables "Remove from this folder".
  final String? folderId;

  const ChannelGridView({
    super.key,
    required this.title,
    required this.loader,
    required this.tvMode,
    this.emptyMessage = "Nothing here yet",
    this.folderId,
  });

  @override
  State<ChannelGridView> createState() => _ChannelGridViewState();
}

class _ChannelGridViewState extends State<ChannelGridView> {
  List<Channel>? channels;

  /// The channels matching the search, or all of them when not searching.
  List<Channel> matches = [];

  /// Channel names normalized once, so typing only normalizes the query.
  List<String> normalizedNames = [];

  int focusedIndex = 0;
  String query = "";
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  final _clearFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _searchFocusNode.onKeyEvent = _handleSearchKey;
    load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _clearFocusNode.dispose();
    super.dispose();
  }

  Future<void> load() async {
    final result = await Error.tryAsyncNoLoading(widget.loader, context);
    if (!mounted) return;
    setState(() {
      channels = result.data ?? [];
      normalizedNames = channels!.map((c) => normalizeName(c.name)).toList();
      _applyQuery();
    });
  }

  /// Filters the already loaded channels, never calls the backend again.
  void _applyQuery() {
    final all = channels ?? [];
    final normalizedQuery = normalizeName(query);
    if (normalizedQuery.isEmpty) {
      matches = all;
      return;
    }
    matches = [
      for (var i = 0; i < all.length; i++)
        if (normalizedNames[i].contains(normalizedQuery)) all[i],
    ];
  }

  void _onQueryChanged(String value) {
    setState(() {
      query = value;
      focusedIndex = 0;
      _applyQuery();
    });
  }

  void _clearSearch() {
    _searchController.clear();
    _onQueryChanged("");
    _searchFocusNode.requestFocus();
  }

  bool _focusGridBelow() =>
      FocusScope.of(context).focusInDirection(TraversalDirection.down);

  Future<void> _openTvKeyboard() async {
    final typed = await showKeyboardInput(
      context,
      initial: _searchController.text,
      hint: tr("Search in this folder"),
    );
    if (typed == null || !mounted) return;
    _searchController.text = typed;
    _onQueryChanged(typed);
    // Wait for the filtered grid before moving the focus into it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusGridBelow();
    });
  }

  KeyEventResult _handleSearchKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (widget.tvMode &&
        (key == LogicalKeyboardKey.select ||
            key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.numpadEnter)) {
      _openTvKeyboard();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown && _focusGridBelow()) {
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight && query.isNotEmpty) {
      _clearFocusNode.requestFocus();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        automaticallyImplyLeading: showBackArrow(widget.tvMode),
      ),
      body: Loading(
        child: SafeArea(
          minimum: sideMarginInsets(context),
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    final channels = this.channels;
    if (channels == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (channels.isEmpty) {
      return Center(
        child: Focus(
          autofocus: true,
          child: Text(
            tr(widget.emptyMessage),
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
      );
    }
    return Column(
      children: [
        _buildSearchField(),
        if (query.isNotEmpty && matches.isNotEmpty) _buildMatchCount(),
        Expanded(child: matches.isEmpty ? _buildNoResults() : _buildGrid()),
      ],
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        // On TV the QWERTY keyboard replaces the system one (often
        // alphabetical on TVs).
        readOnly: widget.tvMode,
        onTap: widget.tvMode ? _openTvKeyboard : null,
        textInputAction: TextInputAction.search,
        onEditingComplete: _focusGridBelow,
        onChanged: _onQueryChanged,
        decoration: InputDecoration(
          hintText: tr("Search in this folder"),
          prefixIcon: const Icon(Icons.search),
          filled: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          suffixIcon: query.isEmpty
              ? null
              : IconButton(
                  focusNode: _clearFocusNode,
                  tooltip: tr("Clear search"),
                  onPressed: _clearSearch,
                  icon: const Icon(Icons.close),
                ),
        ),
      ),
    );
  }

  Widget _buildMatchCount() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          trPlural(matches.length, "1 match", "{count} matches"),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    );
  }

  Widget _buildNoResults() {
    return Center(
      child: Text(
        tr("No results"),
        style: Theme.of(context).textTheme.titleMedium,
      ),
    );
  }

  Widget _buildGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = (constraints.maxWidth / 350).floor().clamp(1, 3);
        return GridView.builder(
          padding: const EdgeInsets.all(10),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisExtent: 100,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
          ),
          itemCount: matches.length,
          itemBuilder: (context, index) {
            final channel = matches[index];
            return ChannelTile(
              key: ValueKey(
                "${channel.sourceId}-${channel.id}-${channel.name}",
              ),
              channel: channel,
              parentContext: context,
              autofocus: index == focusedIndex,
              onSelect: () => focusedIndex = index,
              folderId: widget.folderId,
              onChanged: widget.folderId != null ? load : null,
              setNode: (node) => openNode(
                context,
                node,
                tvMode: widget.tvMode,
                sourceIds: channel.sourceId > 0 ? [channel.sourceId] : null,
              ),
            );
          },
        );
      },
    );
  }
}
