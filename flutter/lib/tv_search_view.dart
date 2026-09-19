import 'dart:async';

import 'package:flutter/material.dart';
import 'package:open_tv/back_navigation.dart';
import 'package:open_tv/channel_actions.dart';
import 'package:open_tv/channel_tile.dart';
import 'package:open_tv/error.dart';
import 'package:open_tv/held_key_guard.dart';
import 'package:open_tv/l10n/l10n.dart';
import 'package:open_tv/models/channel.dart';
import 'package:open_tv/models/filters.dart';
import 'package:open_tv/models/media_type.dart';
import 'package:open_tv/models/view_type.dart';
import 'package:open_tv/native_bridge.dart';
import 'package:open_tv/qwerty_keyboard.dart';
import 'package:open_tv/side_margins.dart';

/// TV search: the QWERTY keyboard on the left, results on the right. Results
/// update while typing.
class TvSearchView extends StatefulWidget {
  const TvSearchView({super.key});

  @override
  State<TvSearchView> createState() => _TvSearchViewState();
}

class _TvSearchViewState extends State<TvSearchView> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _debounce;
  List<Channel> _results = [];
  bool _searching = false;
  bool _reachedMax = true;
  bool _loadingMore = false;
  late final Filters _filters = Filters(
    viewType: ViewType.all,
    mediaTypes: [MediaType.livestream, MediaType.movie, MediaType.serie],
  );

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _search);
  }

  Future<void> _search() async {
    final query = _controller.text.trim();
    if (query.isEmpty) {
      setState(() {
        _results = [];
        _reachedMax = true;
      });
      return;
    }
    setState(() => _searching = true);
    _filters.sourceIds ??= await NativeBridge.instance
        .getEnabledSourcesMinimal();
    if (!mounted) return;
    _filters
      ..query = query
      ..page = 1;
    final result = await Error.tryAsyncNoLoading(
      () => NativeBridge.instance.getChannels(_filters),
      context,
    );
    if (!mounted || _controller.text.trim() != query) return;
    final channels = result.data ?? [];
    setState(() {
      _results = channels;
      _reachedMax = channels.length < nativePageSize;
      _searching = false;
    });
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
  }

  Future<void> _onScroll() async {
    if (_reachedMax ||
        _loadingMore ||
        _scrollController.position.pixels <
            _scrollController.position.maxScrollExtent * 0.75) {
      return;
    }
    _loadingMore = true;
    final query = _filters.query;
    _filters.page++;
    final result = await Error.tryAsyncNoLoading(
      () => NativeBridge.instance.getChannels(_filters),
      context,
    );
    _loadingMore = false;
    if (!mounted || _filters.query != query) return;
    final channels = result.data ?? [];
    setState(() {
      _results.addAll(channels);
      _reachedMax = channels.length < nativePageSize;
    });
  }

  void _toggleMediaType(MediaType type) {
    final current = _filters.mediaTypes ?? [];
    final selected = current.contains(type)
        ? current.where((t) => t != type).toList()
        : [...current, type];
    if (selected.isEmpty) return;
    setState(() => _filters.mediaTypes = selected);
    _search();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: tvBackAppBar(context, title: tr("Search")),
      body: SafeArea(
        minimum: sideMarginInsets(context),
        // OK may still be held from the menu tile that opened this page.
        child: HeldKeyGuard(child: LayoutBuilder(
          builder: (context, constraints) {
            final keyboard = _buildKeyboardPanel();
            if (constraints.maxWidth >= 800) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SingleChildScrollView(child: keyboard),
                  Expanded(
                    child: _buildResults(
                      constraints.maxWidth - qwertyKeyboardWidth - 24,
                    ),
                  ),
                ],
              );
            }
            return Column(
              children: [
                keyboard,
                Expanded(child: _buildResults(constraints.maxWidth)),
              ],
            );
          },
          ),
        ),
      ),
    );
  }

  Widget _buildKeyboardPanel() {
    const types = [
      (MediaType.livestream, Icons.live_tv, "Channels"),
      (MediaType.movie, Icons.movie, "Movies"),
      (MediaType.serie, Icons.local_movies, "Series"),
    ];
    final selected = _filters.mediaTypes ?? [];
    return Padding(
      padding: const EdgeInsets.all(12),
      child: SizedBox(
        width: qwertyKeyboardWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            KeyboardTextDisplay(
              controller: _controller,
              hint: tr("Search channels, movies and series"),
            ),
            const SizedBox(height: 12),
            QwertyKeyboard(controller: _controller, onChanged: _onChanged),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                for (final (type, icon, label) in types)
                  FilterChip(
                    avatar: Icon(icon, size: 18),
                    label: Text(tr(label)),
                    selected: selected.contains(type),
                    showCheckmark: false,
                    onSelected: (_) => _toggleMediaType(type),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResults(double width) {
    if (_searching && _results.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_results.isEmpty) {
      return Center(
        child: Text(
          _controller.text.trim().isEmpty
              ? tr("Type to search")
              : tr("No results"),
          style: Theme.of(context).textTheme.titleMedium,
        ),
      );
    }
    final crossAxisCount = (width / 350).floor().clamp(1, 2);
    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(12),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisExtent: 100,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
      ),
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final channel = _results[index];
        return ChannelTile(
          key: ValueKey("${channel.sourceId}-${channel.id}-${channel.name}"),
          channel: channel,
          parentContext: context,
          onSelect: () {},
          setNode: (node) => openNode(
            context,
            node,
            tvMode: true,
            sourceIds: channel.sourceId > 0 ? [channel.sourceId] : null,
          ),
        );
      },
    );
  }
}
