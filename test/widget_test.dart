import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rlx_invoice/app/app.dart';

void main() {
  testWidgets('generates an electric fence quotation from predefined inputs', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const ProviderScope(child: RLXInvoiceApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Invoices'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Client Name'),
      'Green Horizon Farms',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Running Feet'),
      '200',
    );

    final wifiCard = find.textContaining('WiFi Card');
    await tester.ensureVisible(wifiCard);
    await tester.tap(wifiCard);
    await tester.pumpAndSettle();

    final generateButton = find.text('Generate quotation');
    await tester.ensureVisible(generateButton);
    await tester.tap(generateButton);
    await tester.pumpAndSettle();

    expect(find.text('Green Horizon Farms  •  Electric Fence'), findsOneWidget);
    expect(find.text('PKR 136,500'), findsOneWidget);
    expect(find.textContaining('RLGX-'), findsWidgets);
  });
}
