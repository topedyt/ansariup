import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// CHANGE THIS IMPORT to match your project name if needed,
// but relative import usually works:
import 'package:up_special/main.dart';

void main() {
  testWidgets('App renders smoke test', (WidgetTester tester) async {
    // 1. Wrap the app in ProviderScope (Required for Riverpod)
    await tester.pumpWidget(
      const ProviderScope(
        child: MyApp(), // Fixed: changed UpParikshaApp to MyApp
      ),
    );

    // 2. Simple check to ensure the app launches without crashing
    // (We removed the default counter logic since your app is now a Library)
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
