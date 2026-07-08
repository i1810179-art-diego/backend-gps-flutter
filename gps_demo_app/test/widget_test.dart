import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gps_demo_app/main.dart';

void main() {
  testWidgets('muestra las acciones principales de la demo', (tester) async {
    await tester.pumpWidget(const GpsDemoApp());

    expect(find.text('GPS → Webhook → PostgreSQL'), findsOneWidget);
    expect(find.text('Obtener y enviar ubicación'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();

    expect(find.text('Ver datos guardados'), findsOneWidget);
  });
}
