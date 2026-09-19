import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_tv/channel_actions.dart';
import 'package:open_tv/memory.dart';
import 'package:open_tv/models/channel.dart';
import 'package:open_tv/services/download_manager.dart';
import 'package:open_tv/services/source_names.dart';
import 'package:open_tv/services/watch_progress.dart';
import 'package:open_tv/error.dart';
import 'package:open_tv/models/media_type.dart';
import 'package:open_tv/models/node.dart';
import 'package:open_tv/models/node_type.dart';
import 'package:open_tv/native_bridge.dart';
import 'package:open_tv/player.dart';
import 'package:open_tv/exo_player.dart';
import 'dart:io' show Platform;

class ChannelTile extends StatefulWidget {
  final Channel channel;
  final BuildContext parentContext;
  final Function(Node node) setNode;
  final VoidCallback? onFocusNavbar;
  final VoidCallback onSelect;
  final bool autofocus;

  /// Set when the tile is shown inside a favorites folder.
  final String? folderId;

  /// Called after the long-press menu changed something (e.g. removed the
  /// channel from a folder) so the parent list can reload.
  final VoidCallback? onChanged;
  const ChannelTile({
    super.key,
    required this.channel,
    required this.setNode,
    required this.parentContext,
    required this.onSelect,
    this.onFocusNavbar,
    this.autofocus = false,
    this.folderId,
    this.onChanged,
  });

  @override
  State<ChannelTile> createState() => _ChannelTileState();
}

class _ChannelTileState extends State<ChannelTile> {
  static final _selectionKeys = {
    LogicalKeyboardKey.select,
    LogicalKeyboardKey.enter,
    LogicalKeyboardKey.numpadEnter,
  };

  final FocusNode _focusNode = FocusNode();
  final _statesController = WidgetStatesController();
  Timer? _longPressTimer;
  bool _longPressTriggered = false;
  bool _selectKeyDown = false;
  InteractiveInkFeature? _inkFeature;
  BuildContext? _innerContext;

  @override
  void initState() {
    super.initState();
    _focusNode.onKeyEvent = _handleKeyEvent;
    _focusNode.addListener(_handleFocusChange);
  }

  void _showSplash() {
    final context = _innerContext;
    if (context == null) return;
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    _inkFeature?.cancel();

    final theme = Theme.of(context);
    final splashFactory = theme.splashFactory;

    _inkFeature = splashFactory.create(
      controller: Material.of(context),
      referenceBox: renderBox,
      position: renderBox.size.center(Offset.zero),
      color: theme.splashColor,
      textDirection: Directionality.of(context),
      containedInkWell: true,
      rectCallback: () => Offset.zero & renderBox.size,
      borderRadius: BorderRadius.circular(12),
    );
  }

  void _confirmSplash() {
    _inkFeature?.confirm();
    _inkFeature = null;
  }

  void _cancelSplash() {
    _inkFeature?.cancel();
    _inkFeature = null;
  }

  void _handleFocusChange() {
    if (!_focusNode.hasFocus) {
      _longPressTimer?.cancel();
      _longPressTriggered = false;
      _selectKeyDown = false;
      _cancelSplash();
      _statesController.update(WidgetState.pressed, false);
    }
    setState(() {});
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.arrowRight) {
      if (!FocusScope.of(context).focusInDirection(TraversalDirection.right)) {
        widget.onFocusNavbar?.call();
      }
      return KeyEventResult.handled;
    }

    if (_selectionKeys.contains(event.logicalKey)) {
      if (event is KeyDownEvent) {
        _selectKeyDown = true;
        // The release of a previous hold may have gone to the options menu.
        _longPressTriggered = false;
        _longPressTimer?.cancel();
        _statesController.update(WidgetState.pressed, true);
        _showSplash();
        _longPressTimer = Timer(const Duration(milliseconds: 500), () {
          _longPressTriggered = true;
          _confirmSplash();
          _statesController.update(WidgetState.pressed, false);
          showOptions();
        });
      } else if (event is KeyUpEvent) {
        if (!_selectKeyDown) {
          return KeyEventResult.handled;
        }
        _selectKeyDown = false;
        _longPressTimer?.cancel();
        _statesController.update(WidgetState.pressed, false);
        _confirmSplash();
        if (!_longPressTriggered) {
          play();
        }
        _longPressTriggered = false;
      }
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  void dispose() {
    _longPressTimer?.cancel();
    _cancelSplash();
    _statesController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> showOptions() async {
    await showChannelOptions(
      context,
      widget.channel,
      folderId: widget.folderId,
      onChanged: () {
        if (mounted) setState(() {});
        widget.onChanged?.call();
      },
    );
    if (mounted) _focusNode.requestFocus();
  }

  Future<int?> _handleSeries() async {
    if (widget.channel.url?.isEmpty == true) {
      if (context.mounted) {
        Error.handleError(context, "Invalid series: series ID is null");
      }
      return null;
    }
    final seriesId = int.tryParse(widget.channel.url!);
    if (seriesId == null) {
      if (context.mounted) {
        Error.handleError(
          context,
          "Invalid series: series ID is not a valid number",
        );
      }
      return null;
    }
    seriesNames[seriesId] = widget.channel.name;
    await Error.tryAsync(
      () async {
        await NativeBridge.instance.getEpisodes(
          seriesId,
          widget.channel.sourceId,
          widget.channel.image,
        );
        refreshedSeries.add(seriesId);
      },
      widget.parentContext,
      null,
      true,
      false,
    );
    return seriesId;
  }

  Future<void> play() async {
    widget.onSelect();
    late final int? seriesId;
    if (widget.channel.mediaType == MediaType.serie) {
      seriesId = await _handleSeries();
      if (seriesId == null) return;
    }
    if (widget.channel.mediaType == MediaType.season &&
        widget.channel.id != null) {
      seasonInfo[widget.channel.id!] = (
        seriesId: widget.channel.seriesId,
        name: widget.channel.name,
      );
    }

    if (widget.channel.mediaType == MediaType.group ||
        widget.channel.mediaType == MediaType.serie ||
        widget.channel.mediaType == MediaType.season) {
      widget.setNode(
        Node(
          id:
              widget.channel.mediaType == MediaType.group ||
                  widget.channel.mediaType == MediaType.season
              ? widget.channel.id!
              : seriesId!,
          name: widget.channel.name,
          type: fromMediaType(widget.channel.mediaType),
        ),
      );
    } else {
      var settings = await NativeBridge.instance.getSettings();
      if (widget.channel.id != null) {
        NativeBridge.instance.addLastWatched(widget.channel.id!);
      }
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => Platform.isAndroid
              ? ExoPlayerScreen(channel: widget.channel, settings: settings)
              : Player(channel: widget.channel, settings: settings),
        ),
      );
      if (mounted) _focusNode.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: _focusNode.hasFocus ? 8.0 : 2.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: Builder(
        builder: (innerContext) {
          _innerContext = innerContext;
          return InkWell(
            focusNode: _focusNode,
            autofocus: widget.autofocus,
            statesController: _statesController,
            borderRadius: BorderRadius.circular(12),
            onLongPress: showOptions,
            onSecondaryTap: showOptions,
            onTap: () async => await play(),
            child: Stack(
              children: [
                Positioned.fill(child: _buildContent(context)),
                if (widget.channel.mediaType == MediaType.movie)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _buildProgressBar(),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Partially watched movies/episodes get a thin progress bar.
  Widget _buildProgressBar() {
    return ListenableBuilder(
      listenable: WatchProgressStore.instance,
      builder: (context, _) {
        final progress = WatchProgressStore.instance.get(widget.channel.url);
        final fraction = progress?.fraction;
        if (progress == null ||
            progress.watched ||
            fraction == null ||
            progress.positionSeconds < WatchProgressStore.minResumeSeconds) {
          return const SizedBox.shrink();
        }
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(12),
          ),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 4,
            backgroundColor: Colors.white12,
            color: Colors.redAccent,
          ),
        );
      },
    );
  }

  /// Watched tick and download state, shown before opening the item.
  Widget _buildStatusIcons() {
    if (widget.channel.mediaType != MediaType.movie) {
      return const SizedBox.shrink();
    }
    return ListenableBuilder(
      listenable: Listenable.merge([
        WatchProgressStore.instance,
        DownloadManager.instance,
      ]),
      builder: (context, _) {
        final watched = WatchProgressStore.instance.isWatched(
          widget.channel.url,
        );
        final download = DownloadManager.instance.find(widget.channel.url);
        final icons = <Widget>[
          if (download != null) _downloadIcon(download),
          if (watched)
            const Tooltip(
              message: "Watched",
              child: Icon(Icons.check_circle, size: 25, color: Colors.green),
            ),
        ];
        if (icons.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: icons,
          ),
        );
      },
    );
  }

  Widget _downloadIcon(DownloadItem download) {
    switch (download.status) {
      case DownloadStatus.completed:
        return const Tooltip(
          message: "Downloaded",
          child: Icon(Icons.download_done, size: 22, color: Colors.lightBlue),
        );
      case DownloadStatus.downloading:
        return SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            value: download.fraction,
          ),
        );
      case DownloadStatus.queued:
        return const Icon(Icons.schedule, size: 20, color: Colors.grey);
      case DownloadStatus.paused:
        return const Icon(Icons.pause_circle, size: 20, color: Colors.grey);
      case DownloadStatus.failed:
        return const Icon(Icons.error, size: 20, color: Colors.redAccent);
    }
  }

  /// Which account (source) the channel comes from.
  Widget _buildSourceName(BuildContext context) {
    return ListenableBuilder(
      listenable: SourceNames.instance,
      builder: (context, _) {
        final name = SourceNames.instance.nameOf(widget.channel.sourceId);
        if (name == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Row(
            children: [
              const Icon(Icons.account_circle, size: 14, color: Colors.grey),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildContent(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: Container(
            padding: const EdgeInsets.all(8.0),
            child: Center(
              child: widget.channel.image != null
                  ? CachedNetworkImage(
                      imageUrl: widget.channel.image!,
                      memCacheHeight: 300,
                      memCacheWidth: 300,
                      fit: BoxFit.contain,
                      errorWidget: (_, __, ___) =>
                          const Icon(Icons.tv, size: 45, color: Colors.grey),
                    )
                  : const Icon(Icons.tv, size: 45, color: Colors.grey),
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.channel.name,
                  textAlign: TextAlign.left,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: Theme.of(
                      context,
                    ).textTheme.titleMedium?.fontSize!,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                _buildSourceName(context),
              ],
            ),
          ),
        ),
        _buildStatusIcons(),
        if (widget.channel.favorite)
          const Padding(
            padding: EdgeInsets.only(right: 8.0),
            child: Center(
              child: Icon(Icons.star, size: 25, color: Colors.amber),
            ),
          ),
      ],
    );
  }
}
