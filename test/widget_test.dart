import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:atin/main.dart';

void main() {
  testWidgets('Atin App Auth Screen test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const AtinApp());

    // Verify that the AuthScreen displays the welcome text and email/password fields
    expect(find.text('Welcome to Atin'), findsOneWidget);
    expect(find.text('Gmail / Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
  });
}
