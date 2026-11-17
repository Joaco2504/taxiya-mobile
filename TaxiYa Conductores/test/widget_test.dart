import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taxiya_conductores/src/screens/driver_status_gate_screen.dart';
import 'package:taxiya_core/taxiya_core.dart';

void main() {
  testWidgets('DriverStatusGateScreen displays pending review state', (
    WidgetTester tester,
  ) async {
    const profile = Profile(
      id: 'driver-1',
      fullName: 'Carlos Mendoza',
      phone: '+54 9 3835 412345',
      email: 'carlos@taxiya.ar',
      role: TaxiyaRole.driver,
      accountStatus: TaxiyaAccountStatus.pending,
      localityId: 'belen',
      avatarUrl: null,
      subscriptionTier: SubscriptionTier.free,
      subscriptionExpiresAt: null,
      fcmToken: null,
      themeMode: 'light',
      notifyPromos: true,
      createdAt: null,
      updatedAt: null,
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: TaxiyaTheme.light,
          home: const DriverStatusGateScreen(profile: profile),
        ),
      ),
    );

    expect(find.text('Tu legajo está en revisión'), findsOneWidget);
    expect(find.text('Cerrar sesión'), findsOneWidget);
  });
}
