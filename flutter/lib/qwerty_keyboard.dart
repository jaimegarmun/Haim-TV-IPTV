import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_tv/held_key_guard.dart';
import 'package:open_tv/l10n/l10n.dart';

/// Width of [QwertyKeyboard]: ten keys per row.
const double qwertyKeyboardWidth = 10 * (_Key.size + 2 * _Key.gap);

/// On-screen QWERTY keyboard for TV remotes. The system keyboard of many
/// TVs is alphabetical, and awkward to use with a remote.
///
/// Also accepts typing on a physical keyboard while any key has focus.
class QwertyKeyboard extends StatelessWidget {
  final TextEditingController controller;

  /// Called after every change of the text.
  final ValueChanged<String>? onChanged;

  /// Called by the "Search" key.
  final VoidCallback? onSubmit;
  final bool autofocus;

  const QwertyKeyboard({
    super.key,
    required this.controller,
    this.onChanged,
    this.onSubmit,
    this.autofocus = true,
  });

  static const _rows = [
    "1234567890",
    "qwertyuiop",
    "asdfghjklñ",
    "zxcvbnm-'.",
  ];

  void _set(String text) {
    controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    onChanged?.call(text);
  }

  void _type(String char) => _set(controller.text + char);

  void _backspace() {
    final text = controller.text;
    if (text.isNotEmpty) {
      _set(String.fromCharCodes(text.runes.toList()..removeLast()));
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.backspace) {
      _backspace();
      return KeyEventResult.handled;
    }
    final char = event.character;
    if (char != null &&
        char.length == 1 &&
        char.codeUnitAt(0) >= 0x20 &&
        char.codeUnitAt(0) != 0x7f) {
      _type(char.toLowerCase());
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: _onKey,
      child: FocusTraversalGroup(
        policy: ReadingOrderTraversalPolicy(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (rowIndex, row) in _rows.indexed)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final (index, char) in row.characters.indexed)
                    _Key(
                      label: char.toUpperCase(),
                      autofocus: autofocus && rowIndex == 1 && index == 0,
                      onTap: () => _type(char),
                    ),
                ],
              ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Key(
                  icon: Icons.space_bar,
                  tooltip: tr("Space"),
                  flex: 4,
                  onTap: () => _type(" "),
                ),
                _Key(
                  icon: Icons.backspace_outlined,
                  tooltip: tr("Delete"),
                  flex: 2,
                  onTap: _backspace,
                ),
                _Key(
                  icon: Icons.clear_all,
                  tooltip: tr("Clear"),
                  flex: 2,
                  onTap: () => _set(""),
                ),
                if (onSubmit != null)
                  _Key(
                    icon: Icons.search,
                    tooltip: tr("Search"),
                    flex: 2,
                    highlight: true,
                    onTap: onSubmit!,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Key extends StatefulWidget {
  static const double size = 44;
  static const double gap = 4;

  final String? label;
  final IconData? icon;
  final String? tooltip;
  final int flex;
  final bool autofocus;
  final bool highlight;
  final VoidCallback onTap;

  const _Key({
    this.label,
    this.icon,
    this.tooltip,
    this.flex = 1,
    this.autofocus = false,
    this.highlight = false,
    required this.onTap,
  });

  @override
  State<_Key> createState() => _KeyState();
}

class _KeyState extends State<_Key> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final width = _Key.size * widget.flex + _Key.gap * 2 * (widget.flex - 1);
    final key = Padding(
      padding: const EdgeInsets.all(_Key.gap),
      child: Material(
        color: _focused
            ? scheme.primary
            : widget.highlight
            ? scheme.primaryContainer
            : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          autofocus: widget.autofocus,
          borderRadius: BorderRadius.circular(8),
          onTap: widget.onTap,
          onFocusChange: (v) => setState(() => _focused = v),
          child: SizedBox(
            width: width,
            height: _Key.size,
            child: Center(
              child: widget.icon != null
                  ? Icon(
                      widget.icon,
                      color: _focused ? scheme.onPrimary : null,
                    )
                  : Text(
                      widget.label!,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: _focused ? scheme.onPrimary : null,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
    return widget.tooltip == null
        ? key
        : Tooltip(message: widget.tooltip!, child: key);
  }
}

/// A read-only field showing the typed text, above the keyboard.
class KeyboardTextDisplay extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  const KeyboardTextDisplay({
    super.key,
    required this.controller,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.search),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                value.text.isEmpty ? hint : "${value.text}|",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: Theme.of(context).textTheme.titleMedium?.fontSize,
                  color: value.text.isEmpty ? Colors.grey : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Asks for a text with the on-screen keyboard. Returns null when cancelled.
Future<String?> showKeyboardInput(
  BuildContext context, {
  String initial = "",
  String? hint,
}) {
  final controller = TextEditingController(text: initial);
  return showHeldKeySafeDialog<String>(
    context: context,
    builder: (context) => Dialog(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: qwertyKeyboardWidth,
                child: KeyboardTextDisplay(
                  controller: controller,
                  hint: hint ?? tr("Search..."),
                ),
              ),
              const SizedBox(height: 12),
              QwertyKeyboard(
                controller: controller,
                onSubmit: () => Navigator.of(context).pop(controller.text),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
