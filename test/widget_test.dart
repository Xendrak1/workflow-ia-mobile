import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workflow_ia_mobile/core/theme.dart';

void main() {
  testWidgets('Theme builds without errors', (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      home: const Scaffold(body: Center(child: Text('Workflow IA'))),
    ));
    expect(find.text('Workflow IA'), findsOneWidget);
  });
}
