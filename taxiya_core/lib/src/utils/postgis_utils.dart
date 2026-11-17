import 'dart:math' as math;
import 'dart:typed_data';

/// Coordenada geográfica simple (latitud y longitud).
class GeoPoint {
  const GeoPoint({required this.lat, required this.lng});

  final double lat;
  final double lng;

  @override
  bool operator ==(Object other) =>
      other is GeoPoint && other.lat == lat && other.lng == lng;

  @override
  int get hashCode => Object.hash(lat, lng);
}

/// Coordenadas por defecto para Belén y Andalgalá (Catamarca).
abstract final class CatamarcaDefaults {
  static const GeoPoint belen = GeoPoint(lat: -27.6514, lng: -67.0286);
  static const GeoPoint andalgala = GeoPoint(lat: -27.5819, lng: -66.3161);
  static const GeoPoint center = GeoPoint(lat: -27.615, lng: -66.67);

  static GeoPoint forLocalityName(String? name) {
    if (name == null) return belen;
    final norm = name
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u');
    if (norm.contains('andalgala')) return andalgala;
    if (norm.contains('belen')) return belen;
    return center;
  }
}

/// Decodifica puntos PostGIS en EWKB/WKB hex, GeoJSON o WKT (`POINT(lng lat)`).
GeoPoint? parsePostGisPoint(dynamic value) {
  if (value == null) return null;

  if (value is Map) {
    final type = value['type'];
    final coords = value['coordinates'];
    if (type == 'Point' && coords is List && coords.length >= 2) {
      final lng = (coords[0] as num?)?.toDouble();
      final lat = (coords[1] as num?)?.toDouble();
      if (lat != null && lng != null && lat.isFinite && lng.isFinite) {
        return GeoPoint(lat: lat, lng: lng);
      }
    }
    final lat = (value['lat'] as num?)?.toDouble();
    final lng = (value['lng'] as num?)?.toDouble();
    if (lat != null && lng != null && lat.isFinite && lng.isFinite) {
      return GeoPoint(lat: lat, lng: lng);
    }
    return null;
  }

  if (value is! String) return null;
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;

  // WKT / EWKT
  final wktMatch = RegExp(
    r'POINT\s*\(\s*([-+]?\d+(?:\.\d+)?)\s+([-+]?\d+(?:\.\d+)?)\s*\)',
    caseSensitive: false,
  ).firstMatch(trimmed);
  if (wktMatch != null) {
    final lng = double.tryParse(wktMatch.group(1)!);
    final lat = double.tryParse(wktMatch.group(2)!);
    if (lat != null && lng != null && lat.isFinite && lng.isFinite) {
      return GeoPoint(lat: lat, lng: lng);
    }
  }

  // EWKB / WKB hex (formato por defecto de PostgREST para PostGIS)
  if (trimmed.length >= 42 &&
      trimmed.length.isEven &&
      RegExp(r'^[0-9a-fA-F]+$').hasMatch(trimmed)) {
    final bytes = Uint8List(trimmed.length ~/ 2);
    for (var i = 0; i < trimmed.length; i += 2) {
      bytes[i ~/ 2] = int.parse(trimmed.substring(i, i + 2), radix: 16);
    }
    final data = ByteData.sublistView(bytes);
    final endian = bytes[0] == 1 ? Endian.little : Endian.big;
    final geomType = data.getUint32(1, endian);
    final hasSrid = (geomType & 0x20000000) != 0;
    final baseType = geomType & 0x000000ff;
    final offset = hasSrid ? 9 : 5;
    if (baseType == 1 && bytes.length >= offset + 16) {
      final lng = data.getFloat64(offset, endian);
      final lat = data.getFloat64(offset + 8, endian);
      if (lat.isFinite && lng.isFinite) {
        return GeoPoint(lat: lat, lng: lng);
      }
    }
  }

  return null;
}

/// Convierte coordenadas lat/lng al formato EWKT esperado por PostGIS en Supabase.
String toPostGisEwkt(double lat, double lng) => 'SRID=4326;POINT($lng $lat)';

/// Distancia aproximada en metros mediante Haversine.
double haversineDistanceMeters(
  double lat1,
  double lng1,
  double lat2,
  double lng2,
) {
  const earthRadiusMeters = 6371000.0;
  final dLat = _degToRad(lat2 - lat1);
  final dLng = _degToRad(lng2 - lng1);
  final a =
      math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_degToRad(lat1)) *
          math.cos(_degToRad(lat2)) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return earthRadiusMeters * c;
}

double _degToRad(double deg) => deg * (math.pi / 180.0);
