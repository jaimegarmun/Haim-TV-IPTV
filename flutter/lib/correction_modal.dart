import 'package:flutter/material.dart';
import 'package:open_tv/l10n/l10n.dart';

class CorrectionModal extends StatelessWidget {
  const CorrectionModal({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(tr("Is this the right URL?")),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(tr("Proceed anyway")),
        ),
        TextButton(
          autofocus: true,
          onPressed: () => Navigator.pop(context, true),
          child: Text(tr("Correct URL automatically")),
        ),
      ],
      content: Text(tr(
        "It seems your url is not pointing to an Xtream API server, Haim TV can correct the URL automatically for you",
      )),
    );
  }
}
