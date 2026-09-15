import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:forntend/screens/login/login_screen.dart';

void main() {
  testWidgets('Login screen renders the employee code and mobile fields', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

    expect(find.text('Employee Code'), findsOneWidget);
    expect(find.text('Mobile Number'), findsOneWidget);
    expect(find.text('Request OTP'), findsOneWidget);
  });
}
