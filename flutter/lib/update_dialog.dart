import 'package:flutter/material.dart';
import 'package:open_tv/services/update_checker.dart';
import 'package:url_launcher/url_launcher.dart';

/// On start: offers a newer release, if any. The user can update, be asked
/// again next time, or never be asked again.
Future<void> maybeOfferUpdate(BuildContext context) async {
  final release = await UpdateChecker.instance.checkOnStart();
  if (release == null || !context.mounted) return;
  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => UpdateDialog(release: release),
  );
}

class UpdateDialog extends StatefulWidget {
  final ReleaseInfo release;
  const UpdateDialog({super.key, required this.release});

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  bool _downloading = false;
  double? _progress;
  String? _error;

  Future<void> _update() async {
    final release = widget.release;
    if (!UpdateChecker.canInstallInApp(release)) {
      await launchUrl(
        Uri.parse(release.assetUrl ?? release.pageUrl),
        mode: LaunchMode.externalApplication,
      );
      if (mounted) Navigator.of(context).pop();
      return;
    }
    setState(() {
      _downloading = true;
      _progress = null;
      _error = null;
    });
    try {
      final file = await UpdateChecker.instance.download(release, (progress) {
        if (mounted) setState(() => _progress = progress);
      });
      await UpdateChecker.instance.install(file);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _downloading = false;
          _error = "The update could not be installed: $e";
        });
      }
    }
  }

  Future<void> _neverAskAgain() async {
    await UpdateChecker.instance.setCheckOnStart(false);
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    Navigator.of(context).pop();
    messenger?.showSnackBar(
      const SnackBar(
        content: Text("You can turn update checks back on in Settings"),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final release = widget.release;
    return AlertDialog(
      title: Text("Update available: ${release.version}"),
      content: SizedBox(
        width: 480,
        child: _downloading
            ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _progress == null
                        ? "Downloading..."
                        : "Downloading... ${(_progress! * 100).round()}%",
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(value: _progress),
                ],
              )
            : Scrollbar(
                thumbVisibility: true,
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "A new version of Haim TV is available. "
                          "Do you want to update now?",
                        ),
                        if (release.notes.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(release.notes),
                        ],
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            _error!,
                            style: const TextStyle(color: Colors.redAccent),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
      ),
      actions: _downloading
          ? const []
          : [
              TextButton(
                onPressed: _neverAskAgain,
                child: const Text("Don't show again"),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text("Remind me later"),
              ),
              FilledButton(
                autofocus: true,
                onPressed: _update,
                child: const Text("Yes, update"),
              ),
            ],
    );
  }
}
