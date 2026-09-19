import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

final _selectionKeys = {
  LogicalKeyboardKey.select,
  LogicalKeyboardKey.enter,
  LogicalKeyboardKey.numpadEnter,
  LogicalKeyboardKey.gameButtonA,
};

/// Swallows the select key that is still held when [child] appears.
///
/// Holding OK on a remote opens a menu after a moment, but the remote keeps
/// sending the key (repeats, then the release). Without this guard those
/// events activate the first entry of the menu (e.g. "Add to favorites")
/// before the user can choose anything.
class HeldKeyGuard extends StatefulWidget {
  final Widget child;
  const HeldKeyGuard({super.key, required this.child});

  @override
  State<HeldKeyGuard> createState() => _HeldKeyGuardState();
}

class _HeldKeyGuardState extends State<HeldKeyGuard> {
  late bool _blocking = HardwareKeyboard.instance.logicalKeysPressed.any(
    _selectionKeys.contains,
  );

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (!_blocking || !_selectionKeys.contains(event.logicalKey)) {
      return KeyEventResult.ignored;
    }
    if (event is KeyUpEvent) _blocking = false;
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: _onKey,
      child: widget.child,
    );
  }
}

/// [showDialog] for menus opened by holding select on a remote.
Future<T?> showHeldKeySafeDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  return showDialog<T>(
    context: context,
    builder: (context) => HeldKeyGuard(child: builder(context)),
  );
}
