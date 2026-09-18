import 'package:flutter/material.dart';
import 'package:open_tv/back_navigation.dart';
import 'package:open_tv/side_margins.dart';
import 'package:open_tv/channel_actions.dart';
import 'package:open_tv/channel_tile.dart';
import 'package:open_tv/error.dart';
import 'package:open_tv/loading.dart';
import 'package:open_tv/models/channel.dart';

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
  int focusedIndex = 0;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final result = await Error.tryAsyncNoLoading(widget.loader, context);
    if (!mounted) return;
    setState(() => channels = result.data ?? []);
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
            widget.emptyMessage,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
      );
    }
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
          itemCount: channels.length,
          itemBuilder: (context, index) {
            final channel = channels[index];
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
