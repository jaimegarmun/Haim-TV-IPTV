import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart' show kBackMouseButton;
import 'package:flutter/services.dart';
import 'package:open_tv/l10n/l10n.dart';
import 'package:open_tv/memory.dart';
import 'package:open_tv/generated/generated_proto.pb.dart' as gen;
import 'package:open_tv/home.dart';
import 'package:open_tv/models/custom_shortcut.dart';
import 'package:open_tv/models/device_detector.dart';
import 'package:open_tv/models/filters.dart';
import 'package:open_tv/models/home_manager.dart';
import 'package:open_tv/models/settings.dart';
import 'package:open_tv/services/data_migration.dart';
import 'package:open_tv/services/download_manager.dart';
import 'package:open_tv/services/favorite_folders.dart';
import 'package:open_tv/services/source_names.dart';
import 'package:open_tv/services/watch_progress.dart';
import 'package:open_tv/utils.dart';
import 'package:open_tv/native_bridge.dart' as nb;
import 'package:open_tv/setup.dart';
import 'package:open_tv/tv_home.dart';
import 'package:path_provider/path_provider.dart';
import 'package:media_kit/media_kit.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!Platform.isAndroid) {
    MediaKit.ensureInitialized();
  }
  DownloadManager.instance.movedDataFolder = await migrateLegacyWindowsData();
  final appDir = await getApplicationSupportDirectory();
  final tempDir = await getApplicationCacheDirectory();
  try {
    await nb.NativeBridge.instance.initialize(
      gen.InitMessage(dbPath: appDir.path, tempPath: tempDir.path),
    );
  } catch (e, stack) {
    if (!e.toString().contains(appDir.path)) {
      developer.log(
        "Failed to initialize NativeBridge",
        error: e,
        stackTrace: stack,
        name: "io.github.jaimegarmun.haimtv",
      );
    }
  }
  await Future.wait([
    L10n.instance.load(),
    WatchProgressStore.instance.load(),
    FavoriteFoldersStore.instance.load(),
    // Also resumes unfinished downloads.
    DownloadManager.instance.load(),
  ]);
  await SourceNames.instance.load();
  final hasSources = await nb.NativeBridge.instance.hasSources();
  final settings = await nb.NativeBridge.instance.getSettings();
  final hasTouchScreen = await Utils.hasTouchScreen();
  final isTV = await DeviceDetector.isTV();
  runApp(
    MyApp(
      skipSetup: hasSources,
      settings: settings,
      hasTouchScreen: hasTouchScreen,
      isTV: isTV,
    ),
  );
}

class MyApp extends StatelessWidget {
  final bool skipSetup;
  final Settings settings;
  final bool hasTouchScreen;
  final bool isTV;
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  const MyApp({
    super.key,
    required this.skipSetup,
    required this.settings,
    required this.hasTouchScreen,
    required this.isTV,
  });

  bool get _isEditingText {
    final focus = FocusManager.instance.primaryFocus;
    return focus?.context?.findAncestorWidgetOfExactType<EditableText>() !=
        null;
  }

  bool get _showFocusOutline =>
      !hasTouchScreen ||
      Platform.isLinux ||
      Platform.isWindows ||
      Platform.isMacOS;

  bool get _isTvMode =>
      settings.forceTVMode ||
      isTV ||
      (!hasTouchScreen && (Platform.isAndroid || Platform.isIOS));

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Haim TV',
      navigatorKey: navigatorKey,
      builder: (context, child) {
        return CallbackShortcuts(
          bindings: {
            const CustomShortcut(
              SingleActivator(LogicalKeyboardKey.escape),
            ): () {
              if (_isEditingText) return;
              navigatorKey.currentState?.maybePop();
            },
            const CustomShortcut(
              SingleActivator(LogicalKeyboardKey.backspace),
            ): () {
              if (_isEditingText) return;
              navigatorKey.currentState?.maybePop();
            },
            // On Linux the mouse "back" side button often arrives as the
            // browser-back key or as Alt+Left instead of a mouse button.
            const CustomShortcut(
              SingleActivator(LogicalKeyboardKey.browserBack),
            ): () {
              if (!videoPlayerOpen) navigatorKey.currentState?.maybePop();
            },
            const CustomShortcut(
              SingleActivator(LogicalKeyboardKey.arrowLeft, alt: true),
            ): () {
              if (!videoPlayerOpen && !_isEditingText) {
                navigatorKey.currentState?.maybePop();
              }
            },
          },
          // The mouse "back" side button goes back, except in the player
          // where it seeks.
          child: Listener(
            onPointerDown: (event) {
              if (event.buttons & kBackMouseButton != 0 && !videoPlayerOpen) {
                navigatorKey.currentState?.maybePop();
              }
            },
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          surface: Colors.black,
          brightness: Brightness.dark,
          surfaceContainer: const Color.fromARGB(255, 29, 36, 41),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: ButtonStyle(
            side: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.focused) && _showFocusOutline) {
                return const BorderSide(
                  color: Colors.yellow, // yellow border
                  width: 4,
                );
              }
              return BorderSide.none;
            }),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: ButtonStyle(
            side: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.focused) && _showFocusOutline) {
                return const BorderSide(
                  color: Colors.yellow, // yellow border
                  width: 4,
                );
              }
              return null;
            }),
          ),
        ),
        iconButtonTheme: IconButtonThemeData(
          style: ButtonStyle(
            side: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.focused) && _showFocusOutline) {
                return const BorderSide(
                  color: Colors.yellow, // yellow border
                  width: 4,
                );
              }
              return null;
            }),
          ),
        ),
        switchTheme: SwitchThemeData(
          trackOutlineColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.focused) && _showFocusOutline) {
              return Colors.yellow;
            }
            return null;
          }),
          trackOutlineWidth: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.focused) && _showFocusOutline) {
              return 4;
            }
            return null;
          }),
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.dark,
      debugShowCheckedModeBanner: false,
      home: skipSetup
          ? (_isTvMode
                ? const TvHome()
                : Home(
                    firstLaunch: true,
                    refresh: settings.refreshOnStart,
                    home: HomeManager(
                      filters: Filters(viewType: settings.defaultView),
                    ),
                  ))
          : Setup(tvMode: _isTvMode),
    );
  }
}
