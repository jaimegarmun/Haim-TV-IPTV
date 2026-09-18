import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A folder shown in the TV folder screens. Works with touch, mouse and
/// remote controls (select opens it, holding select triggers [onLongPress]).
class FolderTile extends StatefulWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;

  /// Shown instead of [icon], e.g. a flag emoji.
  final String? emoji;
  final Color color;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool autofocus;

  const FolderTile({
    super.key,
    required this.title,
    required this.color,
    required this.onTap,
    this.subtitle,
    this.icon,
    this.emoji,
    this.onLongPress,
    this.autofocus = false,
  });

  @override
  State<FolderTile> createState() => _FolderTileState();
}

class _FolderTileState extends State<FolderTile> {
  static final _selectionKeys = {
    LogicalKeyboardKey.select,
    LogicalKeyboardKey.enter,
    LogicalKeyboardKey.numpadEnter,
  };

  bool _focused = false;
  bool _hovered = false;
  bool _selectDown = false;
  bool _longPressed = false;
  Timer? _longPressTimer;

  @override
  void dispose() {
    _longPressTimer?.cancel();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (!_selectionKeys.contains(event.logicalKey)) {
      return KeyEventResult.ignored;
    }
    if (event is KeyDownEvent) {
      _selectDown = true;
      _longPressed = false;
      _longPressTimer?.cancel();
      if (widget.onLongPress != null) {
        _longPressTimer = Timer(const Duration(milliseconds: 500), () {
          _longPressed = true;
          widget.onLongPress!();
        });
      }
    } else if (event is KeyUpEvent) {
      if (!_selectDown) return KeyEventResult.handled;
      _selectDown = false;
      _longPressTimer?.cancel();
      if (!_longPressed) widget.onTap();
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final active = _focused || _hovered;
    return Padding(
      padding: const EdgeInsets.all(8),
      child: AnimatedScale(
        scale: active ? 1.07 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: Container(
          width: 190,
          height: 120,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                widget.color,
                Color.lerp(widget.color, Colors.black, 0.45)!,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: active ? Colors.white : Colors.transparent,
              width: 3,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: active ? 0.5 : 0.2),
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: Focus(
              onKeyEvent: _onKey,
              skipTraversal: true,
              child: InkWell(
                autofocus: widget.autofocus,
                borderRadius: BorderRadius.circular(16),
                onTap: widget.onTap,
                onLongPress: widget.onLongPress,
                onSecondaryTap: widget.onLongPress,
                onFocusChange: (v) => setState(() => _focused = v),
                onHover: (v) => setState(() => _hovered = v),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (widget.emoji != null)
                        Text(
                          widget.emoji!,
                          style: const TextStyle(fontSize: 34),
                        )
                      else if (widget.icon != null)
                        Icon(widget.icon, color: Colors.white, size: 36),
                      const SizedBox(height: 6),
                      Text(
                        widget.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          shadows: [
                            Shadow(
                              color: Colors.black54,
                              offset: Offset(0, 1),
                              blurRadius: 2,
                            ),
                          ],
                        ),
                      ),
                      if (widget.subtitle != null)
                        Text(
                          widget.subtitle!,
                          maxLines: 1,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A titled row of folders for the TV folder screens.
class FolderSection extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const FolderSection({super.key, required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(title, style: Theme.of(context).textTheme.titleLarge),
          ),
          Wrap(children: children),
        ],
      ),
    );
  }
}
