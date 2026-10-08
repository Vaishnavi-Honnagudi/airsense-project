// Basic smoke test for AirSense — confirms the app builds and shows
// its title without crashing. Replaces Flutter's default counter-app
// test template, which referenced a MyApp/counter that doesn't exist here.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:airsense_mobile/main.dart';

void main() {
  testWidgets('AirSense app builds without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const AirSenseApp());

    // Give the auth-state stream a moment to resolve (it starts on the
    // login screen until Firebase reports a signed-in/out state).
    await tester.pump(const Duration(seconds: 1));

    // Either the login screen or the home screen should be showing —
    // both are valid outcomes depending on auth state, so just confirm
    // no exception was thrown and *something* rendered.
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}