import 'dart:io' show Platform;

import 'package:flutter/material.dart';

bool get isDesktop =>
    Platform.isWindows || Platform.isLinux || Platform.isMacOS;

/// Whether screens show the "back" arrow. On a real TV the remote's back key
/// is used instead, but TV mode forced on a PC needs it for the mouse.
bool showBackArrow(bool tvMode) => !tvMode || isDesktop;

/// App bar with a back arrow for TV-mode screens that otherwise have none.
/// Null on real TVs and on the first screen (nothing to go back to).
PreferredSizeWidget? tvBackAppBar(BuildContext context, {String? title}) {
  if (!isDesktop || !Navigator.canPop(context)) return null;
  return AppBar(title: title != null ? Text(title) : null);
}
