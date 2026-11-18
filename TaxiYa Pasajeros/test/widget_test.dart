import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taxiya_core/taxiya_core.dart';
import 'package:taxiya_pasajeros/src/features/trips/passenger_active_trip_card.dart';
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

  testWidgets('PassengerActiveTripCard displays driver info and privacy-masked plate', (
    WidgetTester tester,
  ) async {
    const trip = Trip(
      id: 'trip-1',
      passengerId: 'p1',
      driverId: 'd1',
      localityId: 'belen',
      status: TripStatus.arriving,
      originAddress: 'Plaza Olmos',
      originPoint: GeoPoint(lat: -27.6514, lng: -67.0286),
      destAddress: 'Hospital Belén',
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

    const summary = DriverPublicSummary(
      driverId: 'd1',
      fullName: 'Carlos Gómez',
      phone: '+5493835400001',
      avatarUrl: null,
      companyName: null,
      companyBadgeColor: null,
      carBrand: 'Fiat',
      carModel: 'Cronos',
      carColor: 'Blanco',
      carType: 'Sedán',
      carPhotoUrl: null,
      plateNumber: 'AE123CD',
      municipalMobileNum: '01',
      showPlatePublic: false,
      showPermitPublic: true,
      ratingAvg: 4.9,
      totalTrips: 25,
      currentLocation: null,
      lastLocationAt: null,
      activeBadges: <DriverBadge>[],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: TaxiyaTheme.light,
        home: Scaffold(
          body: PassengerActiveTripCard(
            trip: trip,
            driverSummary: summary,
            onOpenChat: () {},
            onShareWhatsApp: () {},
            onPanic: () {},
            onCancelTrip: () {},
            onInspectCarPhoto: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Carlos Gómez'), findsOneWidget);
    expect(find.textContaining('Patente oculta por privacidad'), findsOneWidget);
    expect(find.text('Ida y vuelta (15 min)'), findsOneWidget);
    expect(find.text('Chat'), findsOneWidget);
    expect(find.text('Compartir'), findsOneWidget);
    expect(find.text('Pánico'), findsOneWidget);
  });
}
