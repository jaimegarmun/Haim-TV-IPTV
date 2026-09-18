import 'package:flutter/material.dart';

/// Horizontal margin for list screens: small on phones, wider on large
/// screens so content doesn't touch the window edges.
double sideMargin(double screenWidth) {
  if (screenWidth < 600) return 12;
  return (screenWidth * 0.05).clamp(24.0, 96.0);
}

/// For `SafeArea(minimum: ...)`: left/right margin only, never top/bottom.
EdgeInsets sideMarginInsets(BuildContext context) => EdgeInsets.symmetric(
  horizontal: sideMargin(MediaQuery.sizeOf(context).width),
);

/// Adds [sideMargin] on the left and right only (never top/bottom).
class SideMargins extends StatelessWidget {
  final Widget child;
  const SideMargins({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: sideMargin(width)),
      child: child,
    );
  }
}
