import 'package:flutter/material.dart';
import 'package:open_tv/models/view_type.dart';
import 'package:open_tv/l10n/l10n.dart';
import 'package:open_tv/settings_view.dart';

class BottomNav extends StatefulWidget {
  final Function(ViewType) updateViewMode;
  final ViewType startingView;
  final bool blockSettings;
  final bool tvMode;
  const BottomNav({
    super.key,
    required this.updateViewMode,
    this.startingView = ViewType.all,
    this.blockSettings = false,
    this.tvMode = false,
  });

  @override
  State<BottomNav> createState() => _BottomNavState();
}

class _BottomNavState extends State<BottomNav> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    setState(() {
      _selectedIndex = widget.startingView.index;
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  void onBarTapped(int index) {
    if (widget.blockSettings && index == ViewType.settings.index) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr("Settings disabled while refreshing on start")),
        ),
      );
      return;
    }
    setState(() {
      _selectedIndex = index;
    });
    if (_selectedIndex == ViewType.settings.index) {
      Navigator.pushAndRemoveUntil(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) =>
              SettingsView(tvMode: widget.tvMode),
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
          transitionsBuilder: (context, animation, secondaryAnimation, child) =>
              child,
        ),
        (route) => false,
      );
      return;
    }
    widget.updateViewMode(ViewType.values[_selectedIndex]);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceBright,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.surfaceBright,
            width: 1,
          ),
        ),
      ),
      child: NavigationBar(
        destinations: [
          NavigationDestination(icon: const Icon(Icons.list), label: tr('All')),
          NavigationDestination(
            icon: const Icon(Icons.dashboard),
            label: tr('Categories'),
          ),
          NavigationDestination(icon: const Icon(Icons.star), label: tr('Favorites')),
          NavigationDestination(icon: const Icon(Icons.history), label: tr('History')),
          NavigationDestination(icon: const Icon(Icons.settings), label: tr('Settings')),
        ],
        selectedIndex: _selectedIndex,
        onDestinationSelected: onBarTapped,
      ),
    );
  }
}
