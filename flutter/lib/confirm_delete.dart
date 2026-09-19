import 'package:flutter/material.dart';
import 'package:open_tv/l10n/l10n.dart';

class ConfirmDelete extends StatelessWidget {
  const ConfirmDelete(
      {super.key,
      required this.name,
      required this.confirm,
      required this.type});
  final VoidCallback confirm;
  final String type;
  final String name;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(tr("Confirm deletion")),
      content: Text.rich(TextSpan(children: [
        TextSpan(
            text: tr("You are about to delete {type} ", {"type": tr(type)})),
        TextSpan(
            text: name, style: const TextStyle(fontWeight: FontWeight.bold)),
        TextSpan(text: tr(", are you sure?")),
      ])),
      actions: [
        TextButton(
            autofocus: true,
            onPressed: () async {
              Navigator.of(context).pop();
              confirm();
            },
            child: Text(tr("Confirm"))),
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(tr("Cancel")))
      ],
    );
  }
}
