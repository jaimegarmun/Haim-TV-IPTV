import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:open_tv/error.dart';
import 'package:open_tv/models/channel.dart';
import 'package:open_tv/models/channel_http_headers.dart';
import 'package:open_tv/models/media_type.dart';
import 'package:open_tv/models/settings.dart';
import 'package:open_tv/native_bridge.dart';
import 'package:open_tv/services/download_manager.dart';
import 'package:open_tv/services/watch_progress.dart';
import 'package:open_tv/l10n/l10n.dart';

class ExoPlayerScreen extends StatefulWidget {
  final Channel channel;
  final Settings settings;
  const ExoPlayerScreen({
    super.key,
    required this.channel,
    required this.settings,
  });

  @override
  State<ExoPlayerScreen> createState() => _ExoPlayerScreenState();
}

class _ExoPlayerScreenState extends State<ExoPlayerScreen> {
  static const _viewType = "io.github.jaimegarmun.haimtv/exoplayer";

  MethodChannel? _channel;
  bool _exiting = false;
  bool _ready = false;
  Map<String, dynamic> _creationParams = const {};
  Timer? _progressTimer;

  /// Finished download of this channel, played instead of the stream.
  late final String? _localFile = DownloadManager.instance.localFileFor(
    widget.channel.url,
  );

  bool get _isLive => widget.channel.mediaType == MediaType.livestream;
  bool get _isMovie => widget.channel.mediaType == MediaType.movie;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _init();
  }

  Future<void> _init() async {
    final ChannelHttpHeaders? headers =
        _localFile != null || widget.channel.id == null
        ? null
        : (await Error.tryAsyncNoLoading(() async {
            return await NativeBridge.instance.getChannelHeaders(
              widget.channel.id!,
            );
          }, context)).data;
    final seconds = _isMovie ? await _startSeconds() : null;
    if (!mounted) return;
    setState(() {
      _creationParams = {
        "url": _localFile != null
            ? Uri.file(_localFile).toString()
            : widget.channel.url,
        "isLive": _isLive,
        "startPositionMs": (seconds ?? 0) * 1000,
        "title": widget.channel.name,
        "referer": headers?.referrer,
        "origin": headers?.httpOrigin,
        "userAgent": headers?.userAgent,
        "language": L10n.instance.code,
      };
      _ready = true;
    });
  }

  Future<int?> _startSeconds() async {
    final store = WatchProgressStore.instance;
    if (store.get(widget.channel.url) != null) {
      return store.resumePosition(widget.channel.url);
    }
    // Positions saved before watch_progress.json existed.
    if (widget.channel.id == null) return null;
    return (await Error.tryAsyncNoLoading(() async {
      return await NativeBridge.instance.getMoviePosition(widget.channel.id!);
    }, context)).data;
  }

  void _onPlatformViewCreated(int id) {
    _channel = MethodChannel("io.github.jaimegarmun.haimtv/exoplayer_$id");
    _channel!.setMethodCallHandler((call) async {
      if (call.method == "onBack") {
        _onExit();
      }
      return null;
    });
    if (_isMovie) {
      // Saves progress regularly so it survives the app being killed.
      _progressTimer = Timer.periodic(
        const Duration(seconds: 15),
        (_) => _saveProgress(),
      );
    }
  }

  Future<int?> _saveProgress({bool flush = false}) async {
    if (_channel == null) return null;
    try {
      final posMs = await _channel!.invokeMethod<int>("getPosition") ?? 0;
      final durationMs = await _channel!.invokeMethod<int>("getDuration") ?? 0;
      if (posMs <= 0) return null;
      WatchProgressStore.instance.update(
        widget.channel.url,
        widget.channel.name,
        posMs ~/ 1000,
        durationMs ~/ 1000,
        flush: flush,
      );
      return posMs ~/ 1000;
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    super.dispose();
  }

  Future<void> _onExit() async {
    if (_exiting) return;
    _exiting = true;
    _progressTimer?.cancel();
    if (_isMovie) {
      final seconds = await _saveProgress(flush: true);
      if (seconds != null && widget.channel.id != null) {
        try {
          await NativeBridge.instance.setMoviePosition(
            widget.channel.id!,
            seconds,
          );
        } catch (_) {}
      }
    }
    if (!mounted) return;
    Navigator.of(context).pop();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _onExit();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: _ready ? _buildPlatformView() : const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildPlatformView() {
    return PlatformViewLink(
      viewType: _viewType,
      surfaceFactory: (context, controller) {
        return AndroidViewSurface(
          controller: controller as AndroidViewController,
          gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{},
          hitTestBehavior: PlatformViewHitTestBehavior.opaque,
        );
      },
      onCreatePlatformView: (params) {
        final controller = PlatformViewsService.initExpensiveAndroidView(
          id: params.id,
          viewType: _viewType,
          layoutDirection: TextDirection.ltr,
          creationParams: _creationParams,
          creationParamsCodec: const StandardMessageCodec(),
          onFocus: () => params.onFocusChanged(true),
        );
        controller.addOnPlatformViewCreatedListener(
          params.onPlatformViewCreated,
        );
        controller.addOnPlatformViewCreatedListener(_onPlatformViewCreated);
        controller.create();
        return controller;
      },
    );
  }
}
