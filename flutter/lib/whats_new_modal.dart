import 'package:flutter/material.dart';
import 'package:open_tv/native_bridge.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class WhatsNewModal extends StatelessWidget {
  final String version;
  const WhatsNewModal({super.key, required this.version});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text("What's new: update $version"),
      actions: [
        TextButton(
          onPressed: () async {
            await launchUrl(
              Uri.parse(
                "https://github.com/jaimegarmun/Haim-TV-IPTV/releases",
              ),
              mode: LaunchMode.externalApplication,
            );
            if (!context.mounted) return;
            Navigator.pop(context, false);
          },
          child: const Text("Releases"),
        ),
        TextButton(
          autofocus: true,
          onPressed: () async {
            await NativeBridge.instance.updateLastSeenVersion(
              (await PackageInfo.fromPlatform()).version,
            );
            if (!context.mounted) return;
            Navigator.pop(context, true);
          },
          child: const Text("Don't show again"),
        ),
      ],
      content: const Scrollbar(
        thumbVisibility: true,
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.only(right: 8.0),
            child: Text('''
New in 1.0.1:

- Haim TV checks for updates on start and can install them for you
- Channels / Movies / Series filter at the top of every list
- TV remote: holding OK opens the options menu again (folders, etc.)
- Each channel shows which account it comes from
- Turn a source off in Settings to hide it without deleting it

Welcome to Haim TV! Here's what it can do:

- Download movies and episodes to watch offline
- Resume where you left off, with a tick on watched episodes
- Live TV folders by network and country (TV mode)
- Your own folders inside Favorites
- Rewind live channels on PC (timeshift bar)
- Double tap the sides to skip 10 s on mobile
- Keyboard shortcuts and volume indicator on PC
- Right click or long press any item for more options

Found a problem? Report it on GitHub from any error message.
'''),
          ),
        ),
      ),
    );
  }
}
