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
}
