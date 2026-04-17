// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:epub_reader/main.dart';

void main() {
  testWidgets('App loads successfully', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const EpubReaderApp());

    // Verify that the app title is displayed.
    expect(find.text('ePub Reader'), findsOneWidget);
    
    // Verify that the main content is displayed.
    expect(find.text('ePub 阅读器'), findsOneWidget);
    
    // Verify that the select file button is present.
    expect(find.text('选择 ePub 文件'), findsOneWidget);
  });
}
