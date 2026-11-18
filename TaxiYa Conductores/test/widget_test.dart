import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taxiya_conductores/src/features/trips/driver_trip_widgets.dart';
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

  testWidgets('DriverActiveTripPanel prompts decision when round-trip wait > 10 min', (
    WidgetTester tester,
  ) async {
    const trip = Trip(
      id: 'trip-2',
      passengerId: 'p1',
      driverId: 'd1',
      localityId: 'belen',
      status: TripStatus.inProgress,
      originAddress: 'Centro',
      originPoint: GeoPoint(lat: -27.6514, lng: -67.0286),
      destAddress: 'Terminal',
      destPoint: null,
      isRoundTrip: true,
      waitMinutes: 15,
      scheduledFor: null,
      cancelReason: null,
      cancelledBy: null,
      acceptedAt: null,
      startedAt: null,
      completedAt: null,
      createdAt: null,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: TaxiyaTheme.light,
        home: Scaffold(
          body: DriverActiveTripPanel(
            trip: trip,
            passengerProfile: null,
            driverLocation: null,
            pendingSyncCount: 1,
            busy: false,
            onAdvanceStatus: (_) {},
            onLongWaitChoiceWait: () {},
            onLongWaitChoiceRelease: () {},
            onOpenChat: () {},
            onPanic: () {},
            onCancel: () {},
          ),
        ),
      ),
    );

    expect(find.text('Liberar y trabajar'), findsOneWidget);
    expect(find.text('Esperar regreso'), findsOneWidget);
    expect(
      find.textContaining('1 cambio(s) en cola sin 4G'),
      findsOneWidget,
    );
  });
}
