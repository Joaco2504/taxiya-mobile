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
            acceptedAt: refNow.subtract(Duration(minutes: i * 10)),
            startedAt: i < 5
                ? DateTime(2026, 11, 18, 2, 15)
                : DateTime(2026, 11, 18, 12 + (i % 6), 0),
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
      expect(stats.hasOrderPriorityReward, isTrue);
      expect(stats.hasGoldBorderReward, isTrue);
      expect(stats.hasZoneStatsReward, isTrue);
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
}
