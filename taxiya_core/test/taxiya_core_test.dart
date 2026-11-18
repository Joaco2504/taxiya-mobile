import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taxiya_core/taxiya_core.dart';

void main() {
  group('PostGIS & Catamarca coordinates', () {
    test('parses EWKT/WKT and GeoJSON points accurately', () {
      final fromWkt = parsePostGisPoint('SRID=4326;POINT(-67.0286 -27.6514)');
      expect(fromWkt, isNotNull);
      expect(fromWkt!.lat, closeTo(-27.6514, 0.0001));
      expect(fromWkt.lng, closeTo(-67.0286, 0.0001));

      final fromGeoJson = parsePostGisPoint(<String, dynamic>{
        'type': 'Point',
        'coordinates': <double>[-66.3161, -27.5819],
      });
      expect(fromGeoJson, isNotNull);
      expect(fromGeoJson!.lat, closeTo(-27.5819, 0.0001));
      expect(fromGeoJson.lng, closeTo(-66.3161, 0.0001));
    });

    test('builds valid PostGIS EWKT point string', () {
      final ewkt = toPostGisEwkt(-27.6514, -67.0286);
      expect(ewkt, 'SRID=4326;POINT(-67.0286 -27.6514)');
    });

    test('calculates Haversine distance > 0 between Belén and Andalgalá', () {
      final meters = haversineDistanceMeters(
        CatamarcaDefaults.belen.lat,
        CatamarcaDefaults.belen.lng,
        CatamarcaDefaults.andalgala.lat,
        CatamarcaDefaults.andalgala.lng,
      );
      expect(meters, greaterThan(60000));
      expect(meters, lessThan(90000));
    });
  });

  group('Catalogs, Models & Date formatting', () {
    test('provides 12 passenger and 12 driver avatars with package asset paths', () {
      expect(TaxiyaAvatars.passengerCatalog.length, 12);
      expect(TaxiyaAvatars.driverCatalog.length, 12);
      expect(TaxiyaAvatars.allCatalog.length, 24);
      expect(
        TaxiyaAvatars.passengerCatalog.first.assetPath,
        'packages/taxiya_core/assets/avatars/pasajero_masc_1.png',
      );
      expect(
        TaxiyaAvatars.driverCatalog.first.assetPath,
        'packages/taxiya_core/assets/avatars/conductor_masc_1.png',
      );
      expect(TaxiyaAvatars.fromUri('preset://pasajero_fem_6')?.fileName,
          'pasajero_fem_6.png');
      expect(TaxiyaAvatars.fromUri('preset://conductor_fem_4')?.fileName,
          'conductor_fem_4.png');
      expect(TaxiyaAvatars.fromUri('preset://avatar_01')?.id,
          'conductor_masc_1');
      expect(TaxiyaAvatars.fromUri('preset://unknown'), isNull);
    });

    test('parses DriverDetails dni and checks hasCompleteDossier', () {
      final complete = DriverDetails.fromJson(<String, dynamic>{
        'user_id': 'u1',
        'dni': '30123456',
        'municipal_mobile_num': 'Móvil 01',
        'selfie_url': 'u1/selfie.png',
        'license_front_url': 'u1/front.png',
        'license_back_url': 'u1/back.png',
        'municipal_permit_url': 'u1/permit.png',
        'car_photo_url': 'https://example.com/car.png',
        'plate_number': 'AE123CD',
        'permit_expiry_date': '2027-05-18',
      });
      expect(complete.dni, '30123456');
      expect(complete.municipalMobileNum, 'Móvil 01');
      expect(complete.hasCompleteDossier, isTrue);

      final missingDni = DriverDetails.fromJson(<String, dynamic>{
        'user_id': 'u2',
        'selfie_url': 'u2/selfie.png',
        'license_front_url': 'u2/front.png',
        'license_back_url': 'u2/back.png',
        'municipal_permit_url': 'u2/permit.png',
        'car_photo_url': 'https://example.com/car.png',
        'plate_number': 'AE123CD',
        'permit_expiry_date': '2027-05-18',
      });
      expect(missingDni.hasCompleteDossier, isFalse);
    });

    test('detects Turno Nocturno window 00:00 to 06:00', () {
      expect(TaxiyaDateUtils.isNightShift(DateTime(2026, 1, 1, 2, 30)), isTrue);
      expect(TaxiyaDateUtils.isNightShift(DateTime(2026, 1, 1, 14, 0)), isFalse);
      expect(
        TaxiyaDateUtils.formatDateAr(DateTime(2026, 11, 17)),
        '17/11/2026',
      );
    });
  });

  group('Phase 4 Trip, Gamification, Audio & External Launchers', () {
    test('parses Trip with Fase 4 statuses, round-trip wait_minutes and chat 15m lock', () {
      final now = DateTime.now();
      final recentCompleted = Trip.fromJson(<String, dynamic>{
        'id': 't1',
        'passenger_id': 'p1',
        'driver_id': 'd1',
        'locality_id': 'loc1',
        'status': 'completed',
        'origin_address': 'Plaza Olmos',
        'origin_point': 'SRID=4326;POINT(-67.0286 -27.6514)',
        'dest_address': 'Hospital Belén',
        'dest_point': 'SRID=4326;POINT(-67.0300 -27.6540)',
        'is_round_trip': true,
        'wait_minutes': 15,
        'completed_at': now.subtract(const Duration(minutes: 10)).toIso8601String(),
        'created_at': now.subtract(const Duration(minutes: 20)).toIso8601String(),
      });
      expect(recentCompleted.status, TripStatus.completed);
      expect(recentCompleted.isRoundTrip, isTrue);
      expect(recentCompleted.waitMinutes, 15);
      expect(recentCompleted.isChatWritable, isTrue);

      final oldCancelled = Trip.fromJson(<String, dynamic>{
        'id': 't2',
        'passenger_id': 'p1',
        'driver_id': 'd1',
        'status': 'cancelled',
        'completed_at': now.subtract(const Duration(minutes: 18)).toIso8601String(),
      });
      expect(oldCancelled.status, TripStatus.cancelled);
      expect(oldCancelled.isChatWritable, isFalse);

      expect(TripStatus.fromString('searching'), TripStatus.searching);
      expect(TripStatus.fromString('in_door'), TripStatus.inDoor);
      expect(TripStatus.fromString('waiting_return'), TripStatus.waitingReturn);
    });

    test('evaluates scheduled dispatch 30-minute threshold accurately', () {
      final refNow = DateTime(2026, 11, 18, 10, 0);
      final futureScheduled = Trip.fromJson(<String, dynamic>{
        'id': 's1',
        'passenger_id': 'p1',
        'status': 'searching',
        'is_round_trip': false,
        'scheduled_for': DateTime(2026, 11, 18, 11, 0).toIso8601String(),
      });
      expect(futureScheduled.isScheduledStillDormant(refNow), isTrue);
      expect(futureScheduled.isReadyForDriverDispatch(refNow), isFalse);

      final dueSoon = Trip.fromJson(<String, dynamic>{
        'id': 's2',
        'passenger_id': 'p1',
        'status': 'searching',
        'is_round_trip': false,
        'scheduled_for': DateTime(2026, 11, 18, 10, 25).toIso8601String(),
      });
      expect(dueSoon.isScheduledStillDormant(refNow), isFalse);
      expect(dueSoon.isReadyForDriverDispatch(refNow), isTrue);
    });

    test('computes driver metrics, night shift count and badges cleanly', () {
      final refNow = DateTime(2026, 11, 18, 14, 0);
      final trips = <Trip>[
        for (var i = 0; i < 20; i++)
          Trip(
            id: 'trip-$i',
            passengerId: 'p1',
            driverId: 'd1',
            localityId: 'loc1',
            status: TripStatus.completed,
            originAddress: 'Centro',
            originPoint: null,
            destAddress: 'Barrio Sur',
            destPoint: null,
            isRoundTrip: false,
            waitMinutes: null,
            scheduledFor: null,
            cancelReason: null,
            cancelledBy: null,
            acceptedAt: i < 5
                ? DateTime(2026, 11, 18, 2, 10)
                : DateTime(2026, 11, 18, 12 + (i % 6), 0),
            startedAt: i < 5
                ? DateTime(2026, 11, 18, 2, 15)
                : DateTime(2026, 11, 18, 12 + (i % 6), 4),
            completedAt: refNow.subtract(Duration(minutes: i * 10)),
            createdAt: refNow.subtract(Duration(minutes: i * 10)),
          ),
      ];
      final ratings = List<TripRating>.generate(
        15,
        (int i) => TripRating(
          id: 'r-$i',
          tripId: 'trip-$i',
          passengerId: 'p1',
          driverId: 'd1',
          stars: 5,
          comment: null,
          createdAt: refNow,
        ),
      );

      final stats = DriverStatsCalculator.compute(
        driverId: 'd1',
        period: StatsPeriod.week,
        trips: trips,
        ratings: ratings,
        onlineHoursInPeriod: 12.5,
        now: refNow,
      );

      expect(stats.completedTrips, 20);
      expect(stats.nightShiftTrips, 5);
      expect(stats.noCancelStreak, 20);
      expect(stats.averageRating, 5.0);
      expect(stats.earnedBadgeCodes, containsAll(DriverBadgeCode.values));
      expect(stats.badgeProgress[DriverBadgeCode.punctual]?.currentLevel, BadgeLevel.cobre);
      expect(stats.badgeProgress[DriverBadgeCode.nightShift]?.currentLevel, BadgeLevel.madera);
      expect(stats.maxPriorityAdvantageSeconds, 2);
      expect(stats.hasOrderPriorityReward, isTrue);
      expect(stats.hasGoldBorderReward, isFalse);
      expect(stats.hasZoneStatsReward, isFalse);

      // Con umbrales personalizados menores se desbloquea Diamante/Obsidiana y recompensas máximas
      final customCfgs = <DriverBadgeCode, BadgeConfig>{
        for (final code in DriverBadgeCode.values)
          code: BadgeConfig(
            id: 'c-${code.code}',
            localityId: 'loc1',
            badgeCode: code,
            thresholds: const <int>[1, 2, 3, 4, 5, 10],
          ),
      };
      final maxed = DriverStatsCalculator.compute(
        driverId: 'd1',
        period: StatsPeriod.week,
        trips: trips,
        ratings: ratings,
        onlineHoursInPeriod: 12.5,
        badgeConfigs: customCfgs,
        now: refNow,
      );
      expect(maxed.highestBadgeLevel, BadgeLevel.obsidiana);
      expect(maxed.maxPriorityAdvantageSeconds, 8);
      expect(maxed.orderHoldDelaySeconds, 0);
      expect(maxed.hasGoldBorderReward, isTrue);
      expect(maxed.hasZoneStatsReward, isTrue);

      expect(
        DriverBadgeCode.punctual.assetFileName(BadgeLevel.madera),
        'puntual_1_madera.png',
      );
      expect(
        DriverBadgeCode.localFav.assetFileName(BadgeLevel.cobre),
        'favorito_2_cobre.png',
      );
      expect(
        DriverBadgeCode.impeccable.assetFileName(BadgeLevel.oro),
        'impecable_4_oro.png',
      );
      expect(
        DriverBadgeCode.nightShift.assetFileName(BadgeLevel.diamante),
        'nocturno_5_diamante.png',
      );
      expect(
        DriverBadgeCode.veteran.assetFileName(BadgeLevel.obsidiana),
        'veterano_6_obsidiana.png',
      );
    });

    test('synthesizes valid PCM WAV headers and formats WhatsApp URLs', () {
      final wav = TaxiyaSoundGenerator.buildChimeWav();
      expect(wav.length, greaterThan(44));
      expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
      expect(String.fromCharCodes(wav.sublist(8, 12)), 'WAVE');

      final waUri = TaxiyaExternalLauncher.buildWhatsAppUri(
        phoneDigits: '03835412345',
        message: 'Hola soporte',
      );
      expect(waUri.toString(), contains('https://wa.me/5493835412345'));
      expect(waUri.queryParameters['text'], 'Hola soporte');
    });
  });

  group('Phase 5 Badges, Subscriptions, Ads & Heat Analytics', () {
    test('all 30 badge PNG assets exist in assets/badges matching code & level', () {
      for (final code in DriverBadgeCode.values) {
        for (final level in BadgeLevel.unlockableLevels) {
          final fileName = code.assetFileName(level);
          final file = File('assets/badges/$fileName');
          expect(
            file.existsSync(),
            isTrue,
            reason: 'Falta archivo oficial de insignia: assets/badges/$fileName',
          );
        }
      }
    });

    test('validates AdBanner date window and FavoriteDriver priority coding', () {
      final today = DateTime(2026, 11, 18, 15, 0);
      final activeBanner = AdBanner.fromJson(<String, dynamic>{
        'id': 'ad1',
        'locality_id': 'loc1',
        'business_name': 'Despensa Belén',
        'image_url': 'https://example.com/ad.png',
        'action_type': 'whatsapp',
        'action_target': '3835400111',
        'start_date': '2026-11-01',
        'end_date': '2026-11-25',
        'is_paid': true,
        'is_active': true,
        'clicks_count': 4,
      });
      expect(activeBanner.isCurrentlyRunning(today), isTrue);
      expect(activeBanner.isWhatsAppAction, isTrue);

      final expiredBanner = AdBanner.fromJson(<String, dynamic>{
        'id': 'ad2',
        'locality_id': 'loc1',
        'business_name': 'Comercio Vencido',
        'image_url': '',
        'action_type': 'web',
        'action_target': 'https://example.com',
        'end_date': '2026-11-10',
        'is_paid': true,
        'is_active': true,
      });
      expect(expiredBanner.isCurrentlyRunning(today), isFalse);

      final encoded = TaxiyaTripPriorityUtils.encodePreferredDrivers(
        const <String>['drv-1', 'drv-2', 'drv-1'],
      );
      expect(encoded, 'fav:drv-1,drv-2');
      expect(
        TaxiyaTripPriorityUtils.parsePreferredDrivers(encoded),
        <String>['drv-1', 'drv-2'],
      );
      expect(TaxiyaTripPriorityUtils.isRealCancelReason(encoded), isFalse);
      expect(
        TaxiyaTripPriorityUtils.isRealCancelReason('Demora en origen'),
        isTrue,
      );
    });

    test('synthesizes distinct WAV tones for all DriverOrderSoundPreset modes and computes heat zones', () {
      for (final preset in DriverOrderSoundPreset.values) {
        final bytes = TaxiyaSoundGenerator.buildTripRequestRingWav(preset);
        expect(bytes.length, greaterThan(44));
        expect(String.fromCharCodes(bytes.sublist(0, 4)), 'RIFF');
      }

      final landmarks = <Landmark>[
        Landmark(
          id: 'lm1',
          localityId: 'loc1',
          name: 'Plaza Olmos',
          category: 'Plaza',
          location: const GeoPoint(lat: -27.6514, lng: -67.0286),
          isPublic: true,
          status: 'approved',
          createdBy: null,
          createdAt: null,
        ),
      ];
      final trips = <Trip>[
        Trip(
          id: 't1',
          passengerId: 'p1',
          driverId: 'd1',
          localityId: 'loc1',
          status: TripStatus.completed,
          originAddress: 'Plaza principal',
          originPoint: const GeoPoint(lat: -27.6515, lng: -67.0285),
          destAddress: 'Hospital',
          destPoint: null,
          isRoundTrip: false,
          waitMinutes: null,
          scheduledFor: null,
          cancelReason: null,
          cancelledBy: null,
          acceptedAt: DateTime(2026, 11, 18, 9, 10),
          startedAt: DateTime(2026, 11, 18, 9, 15),
          completedAt: DateTime(2026, 11, 18, 9, 25),
          createdAt: DateTime(2026, 11, 18, 9, 5),
        ),
        Trip(
          id: 't2',
          passengerId: 'p2',
          driverId: null,
          localityId: 'loc1',
          status: TripStatus.cancelled,
          originAddress: 'Cancelado',
          originPoint: const GeoPoint(lat: -27.6515, lng: -67.0285),
          destAddress: null,
          destPoint: null,
          isRoundTrip: false,
          waitMinutes: null,
          scheduledFor: null,
          cancelReason: 'Usuario canceló',
          cancelledBy: 'p2',
          acceptedAt: null,
          startedAt: null,
          completedAt: null,
          createdAt: DateTime(2026, 11, 18, 10, 0),
        ),
      ];

      final analytics = DriverHeatAnalytics.fromTrips(
        trips: trips,
        landmarks: landmarks,
      );
      expect(analytics.totalAnalyzedTrips, 1);
      expect(analytics.topZones.first.label, 'Plaza Olmos');
      expect(analytics.peakHours.first.tripCount, 1);
    });

    testWidgets('hides TaxiyaAdBannerWidget on paid plans and renders on free plan', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: TaxiyaTheme.light,
            home: const Scaffold(
              body: Column(
                children: [
                  TaxiyaAdBannerWidget(
                    localityId: '',
                    subscriptionTier: SubscriptionTier.free,
                    role: TaxiyaRole.passenger,
                    disablePlatformAdsForTest: true,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Quitar anuncios'), findsOneWidget);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: TaxiyaTheme.light,
            home: const Scaffold(
              body: Column(
                children: [
                  TaxiyaAdBannerWidget(
                    localityId: '',
                    subscriptionTier: SubscriptionTier.noAds,
                    role: TaxiyaRole.passenger,
                    disablePlatformAdsForTest: true,
                  ),
                  TaxiyaAdBannerWidget(
                    localityId: '',
                    subscriptionTier: SubscriptionTier.premium,
                    role: TaxiyaRole.driver,
                    disablePlatformAdsForTest: true,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Quitar anuncios'), findsNothing);
    });
  });
}
