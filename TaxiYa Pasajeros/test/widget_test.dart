import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taxiya_core/taxiya_core.dart';
import 'package:taxiya_pasajeros/src/screens/passenger_blocked_screen.dart';

void main() {
  testWidgets('PassengerBlockedScreen shows suspended account message', (
    WidgetTester tester,
  ) async {
    const profile = Profile(
      id: 'passenger-1',
      fullName: 'Lucía Carrizo',
      phone: '+54 9 3835 412345',
      email: 'lucia@taxiya.ar',
      role: TaxiyaRole.passenger,
      accountStatus: TaxiyaAccountStatus.suspended,
      localityId: 'andalgala',
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
          home: const PassengerBlockedScreen(profile: profile),
        ),
      ),
    );

    expect(find.text('Tu cuenta está suspendida'), findsOneWidget);
    expect(find.text('Cerrar sesión'), findsOneWidget);
  });
}
