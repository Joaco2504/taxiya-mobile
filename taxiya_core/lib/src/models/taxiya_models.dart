import '../utils/postgis_utils.dart';

enum TaxiyaRole {
  admin,
  driver,
  passenger;

  static TaxiyaRole fromString(String? value) {
    switch (value) {
      case 'admin':
        return TaxiyaRole.admin;
      case 'driver':
        return TaxiyaRole.driver;
      case 'passenger':
      default:
        return TaxiyaRole.passenger;
    }
  }
}

enum TaxiyaAccountStatus {
  pending,
  active,
  suspended,
  revoked;

  static TaxiyaAccountStatus fromString(String? value) {
    switch (value) {
      case 'active':
        return TaxiyaAccountStatus.active;
      case 'suspended':
        return TaxiyaAccountStatus.suspended;
      case 'revoked':
        return TaxiyaAccountStatus.revoked;
      case 'pending':
      default:
        return TaxiyaAccountStatus.pending;
    }
  }

  String get labelAr {
    switch (this) {
      case TaxiyaAccountStatus.pending:
        return 'Pendiente de revisión';
      case TaxiyaAccountStatus.active:
        return 'Activo';
      case TaxiyaAccountStatus.suspended:
        return 'Suspendido temporalmente';
      case TaxiyaAccountStatus.revoked:
        return 'Permiso revocado';
    }
  }
}

enum SubscriptionTier {
  free,
  noAds,
  premium;

  static SubscriptionTier fromString(String? value) {
    switch (value) {
      case 'no_ads':
        return SubscriptionTier.noAds;
      case 'premium':
        return SubscriptionTier.premium;
      case 'free':
      default:
        return SubscriptionTier.free;
    }
  }

  String get dbValue {
    switch (this) {
      case SubscriptionTier.free:
        return 'free';
      case SubscriptionTier.noAds:
        return 'no_ads';
      case SubscriptionTier.premium:
        return 'premium';
    }
  }

  String get labelAr {
    switch (this) {
      case SubscriptionTier.free:
        return 'Plan Gratuito (\$ 0)';
      case SubscriptionTier.noAds:
        return 'Sin publicidad (\$ 2 USD/mes)';
      case SubscriptionTier.premium:
        return 'Plan Premium (\$ 3 USD/mes)';
    }
  }
}

class Locality {
  const Locality({
    required this.id,
    required this.name,
    required this.province,
    required this.center,
    required this.radiusKm,
    required this.isActive,
  });

  final String id;
  final String name;
  final String province;
  final GeoPoint center;
  final double radiusKm;
  final bool isActive;

  factory Locality.fromJson(Map<String, dynamic> json) {
    final name = (json['name'] as String?) ?? 'Belén';
    return Locality(
      id: json['id'] as String,
      name: name,
      province: (json['province'] as String?) ?? 'Catamarca',
      center:
          parsePostGisPoint(json['center_location']) ??
          CatamarcaDefaults.forLocalityName(name),
      radiusKm: (json['radius_km'] as num?)?.toDouble() ?? 12.0,
      isActive: (json['is_active'] as bool?) ?? true,
    );
  }

  Map<String, dynamic> toCacheJson() => {
    'id': id,
    'name': name,
    'province': province,
    'center_location': {'lat': center.lat, 'lng': center.lng},
    'radius_km': radiusKm,
    'is_active': isActive,
  };
}

class TaxiCompany {
  const TaxiCompany({
    required this.id,
    required this.localityId,
    required this.name,
    required this.badgeColor,
    required this.logoUrl,
    required this.isActive,
  });

  final String id;
  final String localityId;
  final String name;
  final String badgeColor;
  final String? logoUrl;
  final bool isActive;

  factory TaxiCompany.fromJson(Map<String, dynamic> json) {
    return TaxiCompany(
      id: json['id'] as String,
      localityId: json['locality_id'] as String,
      name: (json['name'] as String?) ?? 'Empresa privada',
      badgeColor: (json['badge_color'] as String?) ?? '#0284C7',
      logoUrl: json['logo_url'] as String?,
      isActive: (json['is_active'] as bool?) ?? true,
    );
  }

  Map<String, dynamic> toCacheJson() => {
    'id': id,
    'locality_id': localityId,
    'name': name,
    'badge_color': badgeColor,
    'logo_url': logoUrl,
    'is_active': isActive,
  };
}

class Profile {
  const Profile({
    required this.id,
    required this.fullName,
    required this.phone,
    required this.email,
    required this.role,
    required this.accountStatus,
    required this.localityId,
    required this.avatarUrl,
    required this.subscriptionTier,
    required this.subscriptionExpiresAt,
    required this.fcmToken,
    required this.themeMode,
    required this.notifyPromos,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String? fullName;
  final String? phone;
  final String? email;
  final TaxiyaRole role;
  final TaxiyaAccountStatus accountStatus;
  final String? localityId;
  final String? avatarUrl;
  final SubscriptionTier subscriptionTier;
  final DateTime? subscriptionExpiresAt;
  final String? fcmToken;
  final String themeMode;
  final bool notifyPromos;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      fullName: json['full_name'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      role: TaxiyaRole.fromString(json['role'] as String?),
      accountStatus: TaxiyaAccountStatus.fromString(
        json['account_status'] as String?,
      ),
      localityId: json['locality_id'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      subscriptionTier: SubscriptionTier.fromString(
        json['subscription_tier'] as String?,
      ),
      subscriptionExpiresAt: _parseDate(json['subscription_expires_at']),
      fcmToken: json['fcm_token'] as String?,
      themeMode: (json['theme_mode'] as String?) ?? 'system',
      notifyPromos: (json['notify_promos'] as bool?) ?? true,
      createdAt: _parseDate(json['created_at']),
      updatedAt: _parseDate(json['updated_at']),
    );
  }

  Map<String, dynamic> toCacheJson() => {
    'id': id,
    'full_name': fullName,
    'phone': phone,
    'email': email,
    'role': role.name,
    'account_status': accountStatus.name,
    'locality_id': localityId,
    'avatar_url': avatarUrl,
    'subscription_tier': subscriptionTier.dbValue,
    'subscription_expires_at': subscriptionExpiresAt?.toIso8601String(),
    'fcm_token': fcmToken,
    'theme_mode': themeMode,
    'notify_promos': notifyPromos,
    'created_at': createdAt?.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
  };

  Profile copyWith({
    String? fullName,
    String? phone,
    String? email,
    TaxiyaAccountStatus? accountStatus,
    String? localityId,
    String? avatarUrl,
    String? themeMode,
    bool? notifyPromos,
  }) {
    return Profile(
      id: id,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      role: role,
      accountStatus: accountStatus ?? this.accountStatus,
      localityId: localityId ?? this.localityId,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      subscriptionTier: subscriptionTier,
      subscriptionExpiresAt: subscriptionExpiresAt,
      fcmToken: fcmToken,
      themeMode: themeMode ?? this.themeMode,
      notifyPromos: notifyPromos ?? this.notifyPromos,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

class DriverDetails {
  const DriverDetails({
    required this.userId,
    required this.companyId,
    required this.carBrand,
    required this.carModel,
    required this.carColor,
    required this.carType,
    required this.carPhotoUrl,
    required this.plateNumber,
    required this.selfieUrl,
    required this.licenseFrontUrl,
    required this.licenseBackUrl,
    required this.municipalPermitUrl,
    required this.permitExpiryDate,
    required this.showPlatePublic,
    required this.showPermitPublic,
    required this.isOnline,
    required this.currentLocation,
    required this.lastLocationAt,
    required this.ratingAvg,
    required this.totalTrips,
  });

  final String userId;
  final String? companyId;
  final String? carBrand;
  final String? carModel;
  final String? carColor;
  final String? carType;
  final String? carPhotoUrl;
  final String? plateNumber;
  final String? selfieUrl;
  final String? licenseFrontUrl;
  final String? licenseBackUrl;
  final String? municipalPermitUrl;
  final DateTime? permitExpiryDate;
  final bool showPlatePublic;
  final bool showPermitPublic;
  final bool isOnline;
  final GeoPoint? currentLocation;
  final DateTime? lastLocationAt;
  final double? ratingAvg;
  final int totalTrips;

  bool get hasCompleteDossier =>
      (selfieUrl?.isNotEmpty ?? false) &&
      (licenseFrontUrl?.isNotEmpty ?? false) &&
      (licenseBackUrl?.isNotEmpty ?? false) &&
      (municipalPermitUrl?.isNotEmpty ?? false) &&
      (carPhotoUrl?.isNotEmpty ?? false) &&
      (plateNumber?.isNotEmpty ?? false) &&
      permitExpiryDate != null;

  bool get isGpsStale {
    if (lastLocationAt == null) return true;
    return DateTime.now().difference(lastLocationAt!.toLocal()).inSeconds > 15;
  }

  factory DriverDetails.fromJson(Map<String, dynamic> json) {
    return DriverDetails(
      userId: json['user_id'] as String,
      companyId: json['company_id'] as String?,
      carBrand: json['car_brand'] as String?,
      carModel: json['car_model'] as String?,
      carColor: json['car_color'] as String?,
      carType: json['car_type'] as String?,
      carPhotoUrl: json['car_photo_url'] as String?,
      plateNumber: json['plate_number'] as String?,
      selfieUrl: json['selfie_url'] as String?,
      licenseFrontUrl: json['license_front_url'] as String?,
      licenseBackUrl: json['license_back_url'] as String?,
      municipalPermitUrl: json['municipal_permit_url'] as String?,
      permitExpiryDate: _parseDate(json['permit_expiry_date']),
      showPlatePublic: (json['show_plate_public'] as bool?) ?? true,
      showPermitPublic: (json['show_permit_public'] as bool?) ?? true,
      isOnline: (json['is_online'] as bool?) ?? false,
      currentLocation: parsePostGisPoint(json['current_location']),
      lastLocationAt: _parseDate(json['last_location_at']),
      ratingAvg: (json['rating_avg'] as num?)?.toDouble(),
      totalTrips: (json['total_trips'] as int?) ?? 0,
    );
  }

  Map<String, dynamic> toCacheJson() => {
    'user_id': userId,
    'company_id': companyId,
    'car_brand': carBrand,
    'car_model': carModel,
    'car_color': carColor,
    'car_type': carType,
    'car_photo_url': carPhotoUrl,
    'plate_number': plateNumber,
    'selfie_url': selfieUrl,
    'license_front_url': licenseFrontUrl,
    'license_back_url': licenseBackUrl,
    'municipal_permit_url': municipalPermitUrl,
    'permit_expiry_date': permitExpiryDate?.toIso8601String(),
    'show_plate_public': showPlatePublic,
    'show_permit_public': showPermitPublic,
    'is_online': isOnline,
    'current_location': currentLocation == null
        ? null
        : {'lat': currentLocation!.lat, 'lng': currentLocation!.lng},
    'last_location_at': lastLocationAt?.toIso8601String(),
    'rating_avg': ratingAvg,
    'total_trips': totalTrips,
  };
}

class Landmark {
  const Landmark({
    required this.id,
    required this.localityId,
    required this.name,
    required this.category,
    required this.location,
    required this.isPublic,
    required this.status,
    required this.createdBy,
    required this.createdAt,
  });

  final String id;
  final String localityId;
  final String name;
  final String? category;
  final GeoPoint? location;
  final bool isPublic;
  final String status;
  final String? createdBy;
  final DateTime? createdAt;

  factory Landmark.fromJson(Map<String, dynamic> json) {
    return Landmark(
      id: json['id'] as String,
      localityId: json['locality_id'] as String,
      name: (json['name'] as String?) ?? 'Punto sin nombre',
      category: json['category'] as String?,
      location: parsePostGisPoint(json['location']),
      isPublic: (json['is_public'] as bool?) ?? false,
      status: (json['status'] as String?) ?? 'pending',
      createdBy: json['created_by'] as String?,
      createdAt: _parseDate(json['created_at']),
    );
  }

  Map<String, dynamic> toCacheJson() => {
    'id': id,
    'locality_id': localityId,
    'name': name,
    'category': category,
    'location': location == null
        ? null
        : {'lat': location!.lat, 'lng': location!.lng},
    'is_public': isPublic,
    'status': status,
    'created_by': createdBy,
    'created_at': createdAt?.toIso8601String(),
  };
}

DateTime? _parseDate(dynamic raw) {
  if (raw == null) return null;
  if (raw is DateTime) return raw;
  if (raw is String && raw.isNotEmpty) {
    return DateTime.tryParse(raw);
  }
  return null;
}
