import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:disability_app/main.dart';

void main() {
  testWidgets('DisabilityApp builds', (WidgetTester tester) async {
    await tester.pumpWidget(const DisabilityApp());

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
