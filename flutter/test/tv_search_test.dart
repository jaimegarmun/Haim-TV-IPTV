import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_tv/l10n/l10n.dart';
import 'package:open_tv/qwerty_keyboard.dart';
import 'package:open_tv/tv_search_view.dart';

void main() {
  testWidgets('TV search fits a 960x540 TV screen', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 2;
    await tester.pumpWidget(const MaterialApp(home: TvSearchView()));
    await tester.pump();
    expect(find.text("Q"), findsOneWidget);
    expect(find.text("Ñ"), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keyboard dialog types and returns text', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 2;
    String? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => result = await showKeyboardInput(context),
            child: const Text("open"),
          ),
        ),
      ),
    );
    await tester.tap(find.text("open"));
    await tester.pumpAndSettle();
    await tester.tap(find.text("H"));
    await tester.tap(find.text("O"));
    await tester.pump();
    // Remote: focus starts on "Q"; right moves to "W", OK types it.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump();
    expect(find.text("how|"), findsOneWidget);
    // Down from "W" reaches the next row ("S"), OK types it.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump();
    expect(find.text("hows|"), findsOneWidget);
    await tester.tap(find.byIcon(Icons.search).last);
    await tester.pumpAndSettle();
    expect(result, "hows");
    expect(tester.takeException(), isNull);
  });

  test('tr falls back to English and fills placeholders', () {
    expect(tr("Update available: {version}", {"version": "1.0.2"}),
        "Update available: 1.0.2");
    expect(L10n.instance.code, anyOf("en", "es"));
  });
}
