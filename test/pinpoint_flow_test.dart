import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pinpoint_feedback/pinpoint_feedback.dart';
import 'package:pinpoint_feedback/src/screenshot_service.dart';

/// Drives the full reporter flow: button -> mark -> capture -> compose -> submit.
///
/// The submit step talks to the real Supabase project, so this doubles as an
/// end-to-end check that the deployed schema, storage policies and SDK agree.
void main() {
  /// pumpAndSettle never returns while the submit spinner animates, so step
  /// time forward manually and stop as soon as the expected text appears.
  Future<void> pumpUntil(WidgetTester tester, Finder finder,
      {Duration limit = const Duration(seconds: 30)}) async {
    final deadline = DateTime.now().add(limit);
    while (DateTime.now().isBefore(deadline)) {
      await tester.pump(const Duration(milliseconds: 250));
      if (finder.evaluate().isNotEmpty) return;
    }
  }

  const apiKey = '71e9c38f687a551765e7dbb9bf73f1fc';

  // flutter_test installs an HttpOverrides that fails every request with a 400.
  // Clearing it lets the submit tests actually reach Supabase.
  setUpAll(() => HttpOverrides.global = null);

  // No isolate: `compute` never completes under flutter_test.
  const testConfig = PinpointConfig(useIsolateForEncoding: false);

  Widget host({String key = apiKey}) => Pinpoint(
        apiKey: key,
        config: testConfig,
        appVersion: 'test',
        buildNumber: '0',
        userEmail: 'widget-test@pinpoint.local',
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Text('Client app content'),
                  SizedBox(height: 20),
                  Icon(Icons.shopping_cart, size: 64),
                ],
              ),
            ),
          ),
        ),
      );

  testWidgets('screenshot capture produces a real JPEG', (tester) async {
    final boundaryKey = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundaryKey,
        child: const MaterialApp(
          home: Scaffold(body: Center(child: Text('capture me'))),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final bytes = await ScreenshotService.capture(
      boundaryKey: boundaryKey,
      useIsolate: false,
    );

    expect(bytes, isNotNull, reason: 'capture returned null');
    expect(bytes!.length, greaterThan(100), reason: 'suspiciously small image');
    // JPEG magic number.
    expect(bytes[0], 0xFF);
    expect(bytes[1], 0xD8);
  });

  testWidgets('button appears and enters marking mode', (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.chat_bubble_outline), findsOneWidget);

    await tester.tap(find.byIcon(Icons.chat_bubble_outline));
    await tester.pumpAndSettle();

    expect(find.text('Tap the problem areas'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
  });

  testWidgets('tapping adds numbered markers, tapping one removes it',
      (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.chat_bubble_outline));
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(120, 300));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(220, 420));
    await tester.pumpAndSettle();

    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.textContaining('2 marked'), findsOneWidget);

    // Tap marker 1 to remove it; marker 2 should renumber to 1.
    await tester.tap(find.text('1'));
    await tester.pumpAndSettle();

    expect(find.text('2'), findsNothing);
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('full flow submits to Supabase and shows confirmation',
      (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.chat_bubble_outline));
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(150, 350));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Next'));
    await pumpUntil(tester, find.text('Send feedback'));

    // Compose step is up and reports a captured screenshot.
    expect(find.text('Send feedback'), findsOneWidget);
    expect(find.textContaining('screenshot attached'), findsOneWidget);

    await tester.enterText(
      find.byType(TextField),
      'Automated flow test from pinpoint_flow_test.dart',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Submit'));
    await pumpUntil(tester, find.text('Feedback sent. Thank you!'));

    expect(find.text('Feedback sent. Thank you!'), findsOneWidget,
        reason: 'submission did not succeed');
    // Back to idle.
    expect(find.byIcon(Icons.chat_bubble_outline), findsOneWidget);
  });

  testWidgets('an invalid api key surfaces an error instead of silently failing',
      (tester) async {
    await tester.pumpWidget(host(key: 'definitely-not-a-real-key'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.chat_bubble_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await pumpUntil(tester, find.text('Send feedback'));

    await tester.enterText(find.byType(TextField), 'should fail');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submit'));
    await pumpUntil(tester, find.textContaining('not valid'));

    expect(find.textContaining('not valid'), findsOneWidget);
  });
}
