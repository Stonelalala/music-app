import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music/features/shell/main_shell.dart';

void main() {
  testWidgets('main shell renders the routed child content', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: MainShell(
            currentLocation: '/home',
            miniPlayer: SizedBox.shrink(),
            child: Text('routed child'),
          ),
        ),
      ),
    );

    expect(find.text('routed child'), findsOneWidget);
  });
}
