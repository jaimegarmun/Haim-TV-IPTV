import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:open_tv/models/channel.dart';
import 'package:open_tv/models/id_data.dart';
import 'package:open_tv/models/media_type.dart';
import 'package:media_kit/media_kit.dart' as mk;
import 'package:media_kit_video/media_kit_video.dart' as mkvideo;
import 'package:open_tv/models/settings.dart';
import 'package:open_tv/native_bridge.dart';
import 'package:open_tv/select_dialog.dart';
import 'package:open_tv/error.dart';
import 'package:flutter/gestures.dart'
    show kBackMouseButton, kForwardMouseButton;
import 'package:open_tv/live_timeshift_bar.dart';
import 'package:open_tv/memory.dart';
import 'package:open_tv/player_osd.dart';
import 'package:open_tv/services/download_manager.dart';
import 'package:open_tv/services/watch_progress.dart';

class Player extends StatefulWidget {
  final Channel channel;
  final Settings settings;
  const Player({super.key, required this.channel, required this.settings});
  @override
  State<StatefulWidget> createState() => _PlayerState();
}

class _PlayerState extends State<Player> {
  late mk.Player player = mk.Player();
  late mkvideo.VideoController videoController = mkvideo.VideoController(
    player,
  );
  late final GlobalKey<VideoState> key = GlobalKey<VideoState>();
  bool exiting = false;
  bool fill = false;
  List<StreamSubscription> subscriptions = [];
  DateTime _lastProgressSave = DateTime.now();
  final ValueNotifier<OsdEvent?> osd = ValueNotifier(null);
  double _volumeBeforeMute = 100;

  /// Finished download of this channel, played instead of the stream.
  late final String? localFile = DownloadManager.instance.localFileFor(
    widget.channel.url,
  );

  bool get _isMovie => widget.channel.mediaType == MediaType.movie;

  @override
  void initState() {
    super.initState();
    videoPlayerOpen = true;
    mk.MediaKit.ensureInitialized();
    initAsync();
  }

  Future<void> initAsync() async {
    player.setPlaylistMode(mk.PlaylistMode.none);
    await setMpvOptions();
    final seconds = _isMovie ? await _startSeconds() : null;
    await _startPlayback(seconds != null ? Duration(seconds: seconds) : null);
    subscriptions.add(
      player.stream.completed.listen((completed) {
        if (!completed) return;
        if (_isMovie) {
          final duration = player.state.duration.inSeconds;
          WatchProgressStore.instance.update(
            widget.channel.url,
            widget.channel.name,
            duration,
            duration,
            flush: true,
          );
        }
        onDisconnect();
      }),
    );
    if (_isMovie) {
      subscriptions.add(player.stream.position.listen(_onPosition));
    }
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

  /// Saves progress regularly so it survives the app being killed.
  void _onPosition(Duration position) {
    if (exiting || position.inSeconds <= 0) return;
    final now = DateTime.now();
    if (now.difference(_lastProgressSave) < const Duration(seconds: 10)) {
      return;
    }
    _lastProgressSave = now;
    WatchProgressStore.instance.update(
      widget.channel.url,
      widget.channel.name,
      position.inSeconds,
      player.state.duration.inSeconds,
    );
  }

  Future<void> setMpvOptions() async {
    if (player.platform is mk.NativePlayer) {
      final nativePlayer = player.platform as mk.NativePlayer;
      if (widget.channel.mediaType == MediaType.livestream) {
        if (widget.settings.lowLatency) {
          await nativePlayer.setProperty('profile', 'low-latency');
        } else {
          await enableLiveTimeshift(nativePlayer);
        }
      }
    }
  }

  /// Live channels can be paused and rewound, unless low latency mode
  /// disabled the cache.
  bool get _liveTimeshift =>
      widget.channel.mediaType == MediaType.livestream &&
      !widget.settings.lowLatency;

  void onDisconnect() async {
    if (!mounted || exiting) return;
    if (widget.channel.mediaType == MediaType.livestream) {
      debugPrint("Live stream dropped/error. Attempting to reconnect...");
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted || exiting) return;
      await _startPlayback(null);
    }
  }

  Future<void> _startPlayback(Duration? startPosition) async {
    while (true) {
      if (!mounted || exiting) return;
      try {
        final headers = localFile != null || widget.channel.id == null
            ? null
            : (await Error.tryAsyncNoLoading(() async {
                return await NativeBridge.instance.getChannelHeaders(
                  widget.channel.id!,
                );
              }, context)).data;
        await player.open(
          mk.Media(
            localFile ?? widget.channel.url!,
            start: startPosition,
            httpHeaders: headers != null
                ? {
                    if (headers.referrer != null) "Referer": headers.referrer!,
                    if (headers.httpOrigin != null)
                      "Origin": headers.httpOrigin!,
                    if (headers.userAgent != null)
                      "User-Agent": headers.userAgent!,
                  }
                : null,
          ),
        );
        if (Platform.isAndroid || Platform.isIOS) {
          await key.currentState?.enterFullscreen();
        }
        return;
      } catch (e) {
        debugPrint("Playback failed: $e. Retrying in 2s...");
        await Future.delayed(const Duration(seconds: 2));
      }
    }
  }

  @override
  void dispose() {
    for (final s in subscriptions) s.cancel();
    videoPlayerOpen = false;
    osd.dispose();
    player.dispose();
    super.dispose();
  }

  Future<void> openSubtitlesModal() async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => SelectDialog(
        title: "Select subtitles",
        action: (id) async {
          player.setSubtitleTrack(player.state.tracks.subtitle[id]);
          Navigator.of(context).pop();
        },
        data: player.state.tracks.subtitle
            .asMap()
            .entries
            .map(
              (entry) => IdData(
                id: entry.key,
                data: entry.value.language != null
                    ? "${entry.value.language} - ${entry.value.id}"
                    : entry.value.id,
              ),
            )
            .toList(),
      ),
    );
  }

  Future<void> openAudioModal() async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => SelectDialog(
        title: "Select audio",
        action: (id) async {
          player.setAudioTrack(player.state.tracks.audio[id]);
          Navigator.of(context).pop();
        },
        data: player.state.tracks.audio
            .asMap()
            .entries
            .map(
              (entry) => IdData(
                id: entry.key,
                data:
                    entry.value.title ?? entry.value.language ?? entry.value.id,
              ),
            )
            .toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        onExit();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: MaterialVideoControlsTheme(
          normal: getThemeData(context),
          fullscreen: getThemeData(context),
          child: MaterialDesktopVideoControlsTheme(
            normal: getDesktopThemeData(context),
            fullscreen: getDesktopThemeData(context),
            child: Video(
              key: key,
              controller: videoController,
              onExitFullscreen: (Platform.isAndroid || Platform.isIOS)
                  ? () async => onExit()
                  : defaultExitNativeFullscreen,
              controls: buildControls,
            ),
          ),
        ),
      ),
    );
  }

  void onExit() async {
    if (exiting) return;
    exiting = true;
    if (_isMovie) {
      WatchProgressStore.instance.update(
        widget.channel.url,
        widget.channel.name,
        player.state.position.inSeconds,
        player.state.duration.inSeconds,
        flush: true,
      );
      if (widget.channel.id != null) {
        NativeBridge.instance.setMoviePosition(
          widget.channel.id!,
          player.state.position.inSeconds,
        );
      }
    }
    if (key.currentState!.isFullscreen()) {
      await key.currentState!.exitFullscreen();
    }
    if (!mounted) return;
    Navigator.of(context).pop();
    if (Platform.isAndroid || Platform.isIOS) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  void seekBy(Duration offset) {
    final duration = player.state.duration;
    var target = player.state.position + offset;
    if (target < Duration.zero) target = Duration.zero;
    if (duration > Duration.zero && target > duration) target = duration;
    player.seek(target);
  }

  /// Live channels without the timeshift cache cannot seek.
  bool get _canSeek =>
      widget.channel.mediaType != MediaType.livestream || _liveTimeshift;

  /// Seeks and shows the feedback on the side of the screen, like YouTube.
  void seekWithOsd(int seconds) {
    if (!_canSeek) return;
    seekBy(Duration(seconds: seconds));
    osd.value = OsdEvent(
      seconds < 0 ? Icons.fast_rewind : Icons.fast_forward,
      "${seconds.abs()} s",
      seconds < 0 ? Alignment.centerLeft : Alignment.centerRight,
    );
  }

  void changeVolumeWithOsd(double delta) {
    final volume = (player.state.volume + delta).clamp(0.0, 100.0);
    player.setVolume(volume);
    if (volume > 0) _volumeBeforeMute = volume;
    _showVolume(volume);
  }

  void toggleMute() {
    final volume = player.state.volume > 0 ? 0.0 : _volumeBeforeMute;
    player.setVolume(volume);
    _showVolume(volume);
  }

  void _showVolume(double volume) {
    osd.value = OsdEvent(
      volume == 0
          ? Icons.volume_off
          : volume < 50
          ? Icons.volume_down
          : Icons.volume_up,
      "${volume.round()}%",
      Alignment.topCenter,
    );
  }

  void togglePlayWithOsd() {
    player.playOrPause();
    osd.value = OsdEvent(
      player.state.playing ? Icons.pause : Icons.play_arrow,
      player.state.playing ? "Pause" : "Play",
      Alignment.center,
    );
  }

  /// Desktop keyboard shortcuts (they replace media_kit's defaults).
  Map<ShortcutActivator, VoidCallback> get desktopShortcuts => {
    const SingleActivator(LogicalKeyboardKey.space): togglePlayWithOsd,
    const SingleActivator(LogicalKeyboardKey.keyK): togglePlayWithOsd,
    const SingleActivator(LogicalKeyboardKey.mediaPlayPause):
        player.playOrPause,
    const SingleActivator(LogicalKeyboardKey.mediaPlay): player.play,
    const SingleActivator(LogicalKeyboardKey.mediaPause): player.pause,
    const SingleActivator(LogicalKeyboardKey.arrowLeft): () => seekWithOsd(-5),
    const SingleActivator(LogicalKeyboardKey.arrowRight): () => seekWithOsd(5),
    const SingleActivator(LogicalKeyboardKey.keyJ): () => seekWithOsd(-10),
    const SingleActivator(LogicalKeyboardKey.keyL): () => seekWithOsd(10),
    // Mouse side buttons as delivered by some Linux setups.
    const SingleActivator(LogicalKeyboardKey.browserBack): () =>
        seekWithOsd(-5),
    const SingleActivator(LogicalKeyboardKey.browserForward): () =>
        seekWithOsd(5),
    const SingleActivator(LogicalKeyboardKey.arrowLeft, alt: true): () =>
        seekWithOsd(-5),
    const SingleActivator(LogicalKeyboardKey.arrowRight, alt: true): () =>
        seekWithOsd(5),
    const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
        changeVolumeWithOsd(5),
    const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
        changeVolumeWithOsd(-5),
    const SingleActivator(LogicalKeyboardKey.keyM): toggleMute,
    const SingleActivator(LogicalKeyboardKey.keyF): () =>
        key.currentState?.toggleFullscreen(),
    const SingleActivator(LogicalKeyboardKey.escape): () {
      if (key.currentState?.isFullscreen() ?? false) {
        key.currentState?.exitFullscreen();
      } else {
        onExit();
      }
    },
  };

  /// Mouse side buttons (back / forward) seek 5 seconds.
  void _onPointerDown(PointerDownEvent event) {
    if (event.buttons & kBackMouseButton != 0) seekWithOsd(-5);
    if (event.buttons & kForwardMouseButton != 0) seekWithOsd(5);
  }

  Widget buildControls(VideoState state) {
    return Listener(
      onPointerDown: _onPointerDown,
      child: Stack(
        children: [
          AdaptiveVideoControls(state),
          Positioned.fill(child: PlayerOsd(events: osd)),
        ],
      ),
    );
  }

  void toggleZoom() {
    final videoAspectRatio = player.state.width! / player.state.height!;
    final deviceAspectRatio = MediaQuery.of(context).size.aspectRatio;
    key.currentState!.update(
      aspectRatio: fill ? videoAspectRatio : deviceAspectRatio,
    );
    setState(() {
      fill = !fill;
    });
  }

  MaterialVideoControlsThemeData getThemeData(BuildContext context) {
    return MaterialVideoControlsThemeData(
      speedUpOnLongPress: false,
      seekOnDoubleTap: widget.channel.mediaType != MediaType.livestream,
      displaySeekBar: widget.channel.mediaType != MediaType.livestream,
      seekBarMargin: const EdgeInsets.only(bottom: 60),
      seekBarThumbSize: 20,
      seekBarHeight: 10,
      seekGesture: widget.channel.mediaType != MediaType.livestream,
      topButtonBar: [
        IconButton(
          onPressed: onExit,
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 32),
        ),
        const SizedBox(width: 10),
        Text(widget.channel.name),
      ],
      bottomButtonBar: [
        IconButton(
          onPressed: openSubtitlesModal,
          icon: const Icon(Icons.subtitles, color: Colors.white, size: 32),
        ),
        const SizedBox(width: 20),
        IconButton(
          onPressed: openAudioModal,
          icon: const Icon(Icons.music_note, color: Colors.white, size: 32),
        ),
        const SizedBox(width: 20),
        IconButton(
          icon: const Icon(
            Icons.aspect_ratio_outlined,
            color: Colors.white,
            size: 32,
          ),
          onPressed: toggleZoom,
        ),
        if (!(Platform.isAndroid || Platform.isIOS)) ...[
          const Spacer(),
          const MaterialFullscreenButton(iconSize: 32, iconColor: Colors.white),
        ],
      ],
    );
  }

  MaterialDesktopVideoControlsThemeData getDesktopThemeData(
    BuildContext context,
  ) {
    return MaterialDesktopVideoControlsThemeData(
      seekBarMargin: const EdgeInsets.only(bottom: 60),
      seekBarThumbSize: 20,
      seekBarHeight: 10,
      displaySeekBar: widget.channel.mediaType != MediaType.livestream,
      hideMouseOnControlsRemoval: true,
      controlsHoverDuration: const Duration(seconds: 3),
      keyboardShortcuts: desktopShortcuts,
      // Clicking the video pauses/resumes, like most desktop players.
      playAndPauseOnTap:
          widget.channel.mediaType != MediaType.livestream || _liveTimeshift,
      topButtonBar: [
        IconButton(
          onPressed: onExit,
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 32),
        ),
        const SizedBox(width: 10),
        Text(widget.channel.name),
      ],
      bottomButtonBar: [
        if (widget.channel.mediaType != MediaType.livestream) ...[
          MaterialDesktopCustomButton(
            icon: const Icon(Icons.replay_10),
            iconSize: 32,
            iconColor: Colors.white,
            onPressed: () => seekBy(const Duration(seconds: -10)),
          ),
          const MaterialDesktopPlayOrPauseButton(
            iconSize: 32,
            iconColor: Colors.white,
          ),
          MaterialDesktopCustomButton(
            icon: const Icon(Icons.forward_10),
            iconSize: 32,
            iconColor: Colors.white,
            onPressed: () => seekBy(const Duration(seconds: 10)),
          ),
        ],
        if (_liveTimeshift)
          const MaterialDesktopPlayOrPauseButton(
            iconSize: 32,
            iconColor: Colors.white,
          ),
        const MaterialDesktopVolumeButton(
          iconSize: 32,
          iconColor: Colors.white,
        ),
        if (widget.channel.mediaType != MediaType.livestream)
          const MaterialDesktopPositionIndicator(),
        if (_liveTimeshift) Expanded(child: LiveTimeshiftBar(player: player)),
        const SizedBox(width: 20),
        IconButton(
          onPressed: openSubtitlesModal,
          icon: const Icon(Icons.subtitles, color: Colors.white, size: 32),
        ),
        const SizedBox(width: 20),
        IconButton(
          onPressed: openAudioModal,
          icon: const Icon(Icons.music_note, color: Colors.white, size: 32),
        ),
        const SizedBox(width: 20),
        IconButton(
          icon: const Icon(
            Icons.aspect_ratio_outlined,
            color: Colors.white,
            size: 32,
          ),
          onPressed: toggleZoom,
        ),
        if (!_liveTimeshift) const Spacer(),
        const MaterialDesktopFullscreenButton(
          iconSize: 32,
          iconColor: Colors.white,
        ),
      ],
    );
  }
}
