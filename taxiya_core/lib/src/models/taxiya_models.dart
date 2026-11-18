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
    this.dni,
    this.municipalMobileNum,
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
  final String? dni;
  final String? municipalMobileNum;
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
      (dni?.trim().isNotEmpty ?? false) &&
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
      dni: json['dni'] as String?,
      municipalMobileNum: json['municipal_mobile_num'] as String?,
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
    'dni': dni,
    'municipal_mobile_num': municipalMobileNum,
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

/// Estado del ciclo de vida de un viaje en `taxiya.trips`.
enum TripStatus {
  searching('searching', 'Buscando taxi'),
  requested('requested', 'Solicitado'),
  accepted('accepted', 'Taxi asignado'),
  arriving('arriving', 'En camino a buscarte'),
  inDoor('in_door', 'Taxi en la puerta'),
  inProgress('in_progress', 'Viaje en curso'),
  waiting('waiting', 'En espera (ida y vuelta)'),
  waitingReturn('waiting_return', 'En espera (ida y vuelta)'),
  completed('completed', 'Viaje finalizado'),
  cancelled('cancelled', 'Viaje cancelado');

  const TripStatus(this.dbValue, this.labelAr);

  final String dbValue;
  final String labelAr;

  static TripStatus fromString(String? raw) {
    for (final value in TripStatus.values) {
      if (value.dbValue == raw) return value;
    }
    return TripStatus.searching;
  }

  bool get isTerminal =>
      this == TripStatus.completed || this == TripStatus.cancelled;

  bool get isSearching =>
      this == TripStatus.searching || this == TripStatus.requested;

  bool get isWaitingState =>
      this == TripStatus.waiting || this == TripStatus.waitingReturn;

  bool get isDriverAssigned => !isSearching && !isTerminal;
}

/// Registro de traslado en `taxiya.trips`.
class Trip {
  const Trip({
    required this.id,
    required this.passengerId,
    required this.driverId,
    required this.localityId,
    required this.status,
    required this.originAddress,
    required this.originPoint,
    required this.destAddress,
    required this.destPoint,
    required this.isRoundTrip,
    required this.waitMinutes,
    required this.scheduledFor,
    required this.cancelReason,
    required this.cancelledBy,
    required this.acceptedAt,
    required this.startedAt,
    required this.completedAt,
    required this.createdAt,
  });

  final String id;
  final String passengerId;
  final String? driverId;
  final String? localityId;
  final TripStatus status;
  final String? originAddress;
  final GeoPoint? originPoint;
  final String? destAddress;
  final GeoPoint? destPoint;
  final bool isRoundTrip;
  final int? waitMinutes;
  final DateTime? scheduledFor;
  final String? cancelReason;
  final String? cancelledBy;
  final DateTime? acceptedAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime? createdAt;

  /// Determina si el traslado ocurrió o inició dentro del Turno Nocturno (00:00 a 06:00).
  bool get isNightShiftTrip {
    final ref = (startedAt ?? acceptedAt ?? createdAt)?.toLocal();
    if (ref == null) return false;
    return ref.hour >= 0 && ref.hour < 6;
  }

  /// El chat permite lectura y escritura durante el viaje y hasta 15 minutos después de finalizar o cancelar.
  bool get isChatWritable {
    if (!status.isTerminal) return true;
    final ref = (completedAt ?? acceptedAt ?? createdAt)?.toLocal();
    if (ref == null) return false;
    return DateTime.now().difference(ref) <= const Duration(minutes: 15);
  }

  /// Tiempo restante (en minutos enteros hacia arriba) para que cierre el chat post-viaje.
  int get remainingChatMinutes {
    if (!status.isTerminal) return 15;
    final ref = (completedAt ?? acceptedAt ?? createdAt)?.toLocal();
    if (ref == null) return 0;
    final left = const Duration(minutes: 15) - DateTime.now().difference(ref);
    if (left.isNegative || left.inSeconds == 0) return 0;
    return (left.inSeconds / 60).ceil();
  }

  /// Indica si una reserva programada todavía espera llegar a la ventana de despacho (30 min antes).
  bool isScheduledStillDormant([DateTime? now]) {
    final scheduled = scheduledFor?.toLocal();
    if (scheduled == null) return false;
    final current = now ?? DateTime.now();
    return scheduled.difference(current) > const Duration(minutes: 30);
  }

  bool isReadyForDriverDispatch([DateTime? now]) {
    final scheduled = scheduledFor?.toLocal();
    if (scheduled == null) return true;
    final current = now ?? DateTime.now();
    return !current.isBefore(scheduled.subtract(const Duration(minutes: 30)));
  }

  factory Trip.fromJson(Map<String, dynamic> json) {
    return Trip(
      id: json['id'] as String,
      passengerId: json['passenger_id'] as String,
      driverId: json['driver_id'] as String?,
      localityId: json['locality_id'] as String?,
      status: TripStatus.fromString(json['status'] as String?),
      originAddress: json['origin_address'] as String?,
      originPoint: parsePostGisPoint(json['origin_point']),
      destAddress: json['dest_address'] as String?,
      destPoint: parsePostGisPoint(json['dest_point']),
      isRoundTrip: (json['is_round_trip'] as bool?) ?? false,
      waitMinutes: (json['wait_minutes'] as num?)?.toInt(),
      scheduledFor: _parseDate(json['scheduled_for']),
      cancelReason: json['cancel_reason'] as String?,
      cancelledBy: json['cancelled_by'] as String?,
      acceptedAt: _parseDate(json['accepted_at']),
      startedAt: _parseDate(json['started_at']),
      completedAt: _parseDate(json['completed_at']),
      createdAt: _parseDate(json['created_at']),
    );
  }

  Map<String, dynamic> toCacheJson() => {
    'id': id,
    'passenger_id': passengerId,
    'driver_id': driverId,
    'locality_id': localityId,
    'status': status.dbValue,
    'origin_address': originAddress,
    'origin_point': originPoint == null
        ? null
        : {'lat': originPoint!.lat, 'lng': originPoint!.lng},
    'dest_address': destAddress,
    'dest_point': destPoint == null
        ? null
        : {'lat': destPoint!.lat, 'lng': destPoint!.lng},
    'is_round_trip': isRoundTrip,
    'wait_minutes': waitMinutes,
    'scheduled_for': scheduledFor?.toIso8601String(),
    'cancel_reason': cancelReason,
    'cancelled_by': cancelledBy,
    'accepted_at': acceptedAt?.toIso8601String(),
    'started_at': startedAt?.toIso8601String(),
    'completed_at': completedAt?.toIso8601String(),
    'created_at': createdAt?.toIso8601String(),
  };

  Trip copyWith({
    String? driverId,
    bool clearDriverId = false,
    TripStatus? status,
    String? cancelReason,
    String? cancelledBy,
    DateTime? acceptedAt,
    DateTime? startedAt,
    DateTime? completedAt,
  }) {
    return Trip(
      id: id,
      passengerId: passengerId,
      driverId: clearDriverId ? null : (driverId ?? this.driverId),
      localityId: localityId,
      status: status ?? this.status,
      originAddress: originAddress,
      originPoint: originPoint,
      destAddress: destAddress,
      destPoint: destPoint,
      isRoundTrip: isRoundTrip,
      waitMinutes: waitMinutes,
      scheduledFor: scheduledFor,
      cancelReason: cancelReason ?? this.cancelReason,
      cancelledBy: cancelledBy ?? this.cancelledBy,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      createdAt: createdAt,
    );
  }
}

/// Mensaje de chat dentro de un viaje (`taxiya.trip_messages`).
class TripMessage {
  const TripMessage({
    required this.id,
    required this.tripId,
    required this.senderId,
    required this.message,
    required this.createdAt,
  });

  final String id;
  final String tripId;
  final String senderId;
  final String message;
  final DateTime? createdAt;

  factory TripMessage.fromJson(Map<String, dynamic> json) {
    return TripMessage(
      id: json['id'] as String,
      tripId: json['trip_id'] as String,
      senderId: json['sender_id'] as String,
      message: (json['message'] as String?) ?? '',
      createdAt: _parseDate(json['created_at']),
    );
  }

  Map<String, dynamic> toCacheJson() => {
    'id': id,
    'trip_id': tripId,
    'sender_id': senderId,
    'message': message,
    'created_at': createdAt?.toIso8601String(),
  };
}

/// Calificación de 1 a 5 estrellas emitida por un pasajero (`taxiya.ratings`).
class TripRating {
  const TripRating({
    required this.id,
    required this.tripId,
    required this.passengerId,
    required this.driverId,
    required this.stars,
    required this.comment,
    required this.createdAt,
  });

  final String id;
  final String tripId;
  final String passengerId;
  final String driverId;
  final int stars;
  final String? comment;
  final DateTime? createdAt;

  factory TripRating.fromJson(Map<String, dynamic> json) {
    return TripRating(
      id: json['id'] as String,
      tripId: json['trip_id'] as String,
      passengerId: json['passenger_id'] as String,
      driverId: json['driver_id'] as String,
      stars: (json['stars'] as num?)?.toInt() ?? 5,
      comment: json['comment'] as String?,
      createdAt: _parseDate(json['created_at']),
    );
  }

  Map<String, dynamic> toCacheJson() => {
    'id': id,
    'trip_id': tripId,
    'passenger_id': passengerId,
    'driver_id': driverId,
    'stars': stars,
    'comment': comment,
    'created_at': createdAt?.toIso8601String(),
  };
}

/// Códigos oficiales de insignias del chofer en `taxiya.driver_badges`.
enum DriverBadgeCode {
  punctual(
    code: 'punctual',
    labelAr: 'Puntual',
    descriptionAr: 'Completás viajes sin demoras al recoger al pasajero.',
    rewardAr: 'Prioridad de 5 s al recibir pedidos nuevos',
  ),
  localFav(
    code: 'local_fav',
    labelAr: 'Favorito local',
    descriptionAr: 'Calificación promedio igual o superior a 4,8 estrellas.',
    rewardAr: 'Borde dorado en tu tarjeta del pasajero',
  ),
  impeccable(
    code: 'impeccable',
    labelAr: 'Sin cancelaciones',
    descriptionAr: '10 viajes seguidos sin cancelar como chofer.',
    rewardAr: 'Prioridad de 5 s al recibir pedidos nuevos',
  ),
  nightShift(
    code: 'night_shift',
    labelAr: 'Turno nocturno',
    descriptionAr: '5 viajes o más en Turno Nocturno.',
    rewardAr: 'Desbloquea estadísticas de demanda por zona',
  ),
  veteran(
    code: 'veteran',
    labelAr: 'Veterano de la zona',
    descriptionAr: '20 viajes o más completados en tu localidad.',
    rewardAr: 'Borde dorado en tu tarjeta del pasajero',
  );

  const DriverBadgeCode({
    required this.code,
    required this.labelAr,
    required this.descriptionAr,
    required this.rewardAr,
  });

  final String code;
  final String labelAr;
  final String descriptionAr;
  final String rewardAr;

  static DriverBadgeCode? fromString(String? raw) {
    for (final value in DriverBadgeCode.values) {
      if (value.code == raw) return value;
    }
    return null;
  }

  bool get grantsOrderPriority =>
      this == DriverBadgeCode.punctual || this == DriverBadgeCode.impeccable;

  bool get grantsGoldBorder =>
      this == DriverBadgeCode.localFav || this == DriverBadgeCode.veteran;
}

/// Insignia obtenida por un chofer (`taxiya.driver_badges`).
class DriverBadge {
  const DriverBadge({
    required this.id,
    required this.driverId,
    required this.rawCode,
    required this.badgeCode,
    required this.awardedAt,
    required this.expiresAt,
  });

  final String id;
  final String driverId;
  final String rawCode;
  final DriverBadgeCode? badgeCode;
  final DateTime? awardedAt;
  final DateTime? expiresAt;

  bool get isActive {
    if (expiresAt == null) return true;
    return expiresAt!.toLocal().isAfter(DateTime.now());
  }

  String get displayLabel => badgeCode?.labelAr ?? rawCode;

  factory DriverBadge.fromJson(Map<String, dynamic> json) {
    final rawCode = (json['badge_code'] as String?) ?? 'punctual';
    return DriverBadge(
      id: (json['id'] as String?) ?? rawCode,
      driverId: json['driver_id'] as String,
      rawCode: rawCode,
      badgeCode: DriverBadgeCode.fromString(rawCode),
      awardedAt: _parseDate(json['awarded_at']),
      expiresAt: _parseDate(json['expires_at']),
    );
  }

  Map<String, dynamic> toCacheJson() => {
    'id': id,
    'driver_id': driverId,
    'badge_code': rawCode,
    'awarded_at': awardedAt?.toIso8601String(),
    'expires_at': expiresAt?.toIso8601String(),
  };
}

enum SupportTicketStatus {
  open('open', 'Abierto'),
  inReview('in_review', 'En revisión'),
  inProgress('in_progress', 'En proceso'),
  resolved('resolved', 'Resuelto'),
  closed('closed', 'Cerrado');

  const SupportTicketStatus(this.dbValue, this.labelAr);

  final String dbValue;
  final String labelAr;

  static SupportTicketStatus fromString(String? raw) {
    for (final value in SupportTicketStatus.values) {
      if (value.dbValue == raw) return value;
    }
    return SupportTicketStatus.open;
  }
}

/// Ticket de soporte o alerta de emergencia (`taxiya.support_tickets`).
class SupportTicket {
  const SupportTicket({
    required this.id,
    required this.userId,
    required this.tripId,
    required this.localityId,
    required this.category,
    required this.description,
    required this.isEmergency,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String? tripId;
  final String? localityId;
  final String? category;
  final String? description;
  final bool isEmergency;
  final SupportTicketStatus status;
  final DateTime? createdAt;

  factory SupportTicket.fromJson(Map<String, dynamic> json) {
    return SupportTicket(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      tripId: json['trip_id'] as String?,
      localityId: json['locality_id'] as String?,
      category: json['category'] as String?,
      description: json['description'] as String?,
      isEmergency: (json['is_emergency'] as bool?) ?? false,
      status: SupportTicketStatus.fromString(json['status'] as String?),
      createdAt: _parseDate(json['created_at']),
    );
  }

  Map<String, dynamic> toCacheJson() => {
    'id': id,
    'user_id': userId,
    'trip_id': tripId,
    'locality_id': localityId,
    'category': category,
    'description': description,
    'is_emergency': isEmergency,
    'status': status.dbValue,
    'created_at': createdAt?.toIso8601String(),
  };
}

/// Información pública del chofer asignado que se muestra en la tarjeta del pasajero.
class DriverPublicSummary {
  const DriverPublicSummary({
    required this.driverId,
    required this.fullName,
    required this.phone,
    required this.avatarUrl,
    required this.companyName,
    required this.companyBadgeColor,
    required this.carBrand,
    required this.carModel,
    required this.carColor,
    required this.carType,
    required this.carPhotoUrl,
    required this.plateNumber,
    required this.municipalMobileNum,
    required this.showPlatePublic,
    required this.showPermitPublic,
    required this.ratingAvg,
    required this.totalTrips,
    required this.currentLocation,
    required this.lastLocationAt,
    required this.activeBadges,
  });

  final String driverId;
  final String? fullName;
  final String? phone;
  final String? avatarUrl;
  final String? companyName;
  final String? companyBadgeColor;
  final String? carBrand;
  final String? carModel;
  final String? carColor;
  final String? carType;
  final String? carPhotoUrl;
  final String? plateNumber;
  final String? municipalMobileNum;
  final bool showPlatePublic;
  final bool showPermitPublic;
  final double? ratingAvg;
  final int totalTrips;
  final GeoPoint? currentLocation;
  final DateTime? lastLocationAt;
  final List<DriverBadge> activeBadges;

  bool get isGpsStale {
    if (lastLocationAt == null) return true;
    return DateTime.now().difference(lastLocationAt!.toLocal()).inSeconds > 15;
  }

  bool get hasGoldCardReward =>
      activeBadges.any((b) => b.isActive && (b.badgeCode?.grantsGoldBorder ?? false));

  String get displayName =>
      (fullName != null && fullName!.trim().isNotEmpty)
          ? fullName!.trim()
          : 'Chofer habilitado';

  String get vehicleDescription {
    final parts = <String>[
      if (carBrand != null && carBrand!.trim().isNotEmpty) carBrand!.trim(),
      if (carModel != null && carModel!.trim().isNotEmpty) carModel!.trim(),
      if (carColor != null && carColor!.trim().isNotEmpty) carColor!.trim(),
    ];
    return parts.isEmpty ? 'Taxi habilitado' : parts.join(' ');
  }

  String get visiblePlateLabel => showPlatePublic
      ? (plateNumber?.trim().isNotEmpty == true
            ? plateNumber!.trim().toUpperCase()
            : 'No informada')
      : 'Patente oculta por privacidad';

  String get visiblePermitLabel {
    if (!showPermitPublic) return 'Habilitación verificada (oculta)';
    final mobile = municipalMobileNum?.trim();
    if (mobile != null && mobile.isNotEmpty) {
      return 'Móvil municipal $mobile (verificado)';
    }
    return 'Habilitación municipal verificada';
  }
}

/// Período de filtro para la pantalla de rendimiento y gamificación del chofer.
enum StatsPeriod {
  day('Día'),
  week('Semana'),
  month('Mes');

  const StatsPeriod(this.labelAr);
  final String labelAr;
}

/// Resumen calculado de rendimiento, metas e insignias del chofer.
class DriverStatsSnapshot {
  const DriverStatsSnapshot({
    required this.period,
    required this.completedTrips,
    required this.nightShiftTrips,
    required this.onlineHours,
    required this.averageRating,
    required this.weeklyCompletedTrips,
    required this.weeklyNightTrips,
    required this.evaluatedTripsCount,
    required this.noCancelStreak,
    required this.earnedBadgeCodes,
  });

  final StatsPeriod period;
  final int completedTrips;
  final int nightShiftTrips;
  final double onlineHours;
  final double? averageRating;
  final int weeklyCompletedTrips;
  final int weeklyNightTrips;
  final int evaluatedTripsCount;
  final int noCancelStreak;
  final Set<DriverBadgeCode> earnedBadgeCodes;

  bool get hasOrderPriorityReward =>
      earnedBadgeCodes.any((c) => c.grantsOrderPriority);

  bool get hasGoldBorderReward =>
      earnedBadgeCodes.any((c) => c.grantsGoldBorder);

  bool get hasZoneStatsReward =>
      earnedBadgeCodes.contains(DriverBadgeCode.nightShift);
}

/// Calcula métricas y progreso de metas locales a partir del historial de viajes y calificaciones.
abstract final class DriverStatsCalculator {
  static DriverStatsSnapshot compute({
    required String driverId,
    required StatsPeriod period,
    required List<Trip> trips,
    required List<TripRating> ratings,
    required double onlineHoursInPeriod,
    double? profileRatingAvg,
    DateTime? now,
  }) {
    final current = (now ?? DateTime.now()).toLocal();
    final periodStart = _startOfPeriod(current, period);
    final weekStart = _startOfPeriod(current, StatsPeriod.week);

    final completedAll = trips
        .where((t) => t.status == TripStatus.completed)
        .toList();

    final inPeriod = completedAll.where((t) {
      final ts = (t.completedAt ?? t.createdAt)?.toLocal();
      return ts != null && !ts.isBefore(periodStart);
    }).toList();

    final inWeek = completedAll.where((t) {
      final ts = (t.completedAt ?? t.createdAt)?.toLocal();
      return ts != null && !ts.isBefore(weekStart);
    }).toList();

    // Calificaciones en el período o promedio general
    final periodRatings = ratings.where((r) {
      final ts = r.createdAt?.toLocal();
      return ts != null && !ts.isBefore(periodStart);
    }).toList();

    double? avgRating;
    if (periodRatings.isNotEmpty) {
      avgRating =
          periodRatings.fold<int>(0, (acc, r) => acc + r.stars) /
          periodRatings.length;
    } else if (ratings.isNotEmpty) {
      avgRating =
          ratings.fold<int>(0, (acc, r) => acc + r.stars) / ratings.length;
    } else {
      avgRating = profileRatingAvg;
    }

    // Racha sin cancelaciones del chofer ordenando del más reciente al más antiguo
    final sortedByDate = List<Trip>.from(trips)
      ..sort((a, b) {
        final ta = (a.createdAt ?? a.acceptedAt ?? DateTime(2000)).toLocal();
        final tb = (b.createdAt ?? b.acceptedAt ?? DateTime(2000)).toLocal();
        return tb.compareTo(ta);
      });

    var streak = 0;
    for (final trip in sortedByDate) {
      if (trip.status == TripStatus.cancelled && trip.cancelledBy == driverId) {
        break;
      }
      if (trip.status == TripStatus.completed) {
        streak++;
      }
    }

    final totalCompleted = completedAll.length;
    final totalNightTrips = completedAll.where((t) => t.isNightShiftTrip).length;
    final overallRating = ratings.isNotEmpty
        ? ratings.fold<int>(0, (acc, r) => acc + r.stars) / ratings.length
        : (profileRatingAvg ?? 0);

    final earned = <DriverBadgeCode>{
      if (streak >= 10) DriverBadgeCode.impeccable,
      if (totalNightTrips >= 5) DriverBadgeCode.nightShift,
      if (overallRating >= 4.8 &&
          (ratings.length >= 15 || totalCompleted >= 15))
        DriverBadgeCode.localFav,
      if (totalCompleted >= 20) DriverBadgeCode.veteran,
      if (inWeek.length >= 20 || (totalCompleted >= 5 && streak >= 5))
        DriverBadgeCode.punctual,
    };

    return DriverStatsSnapshot(
      period: period,
      completedTrips: inPeriod.length,
      nightShiftTrips: inPeriod.where((t) => t.isNightShiftTrip).length,
      onlineHours: onlineHoursInPeriod,
      averageRating: avgRating,
      weeklyCompletedTrips: inWeek.length,
      weeklyNightTrips: inWeek.where((t) => t.isNightShiftTrip).length,
      evaluatedTripsCount:
          ratings.isNotEmpty ? ratings.length : totalCompleted,
      noCancelStreak: streak,
      earnedBadgeCodes: earned,
    );
  }

  static DateTime startOfPeriod(DateTime current, StatsPeriod period) =>
      _startOfPeriod(current, period);

  static DateTime _startOfPeriod(DateTime current, StatsPeriod period) {
    final dayStart = DateTime(current.year, current.month, current.day);
    switch (period) {
      case StatsPeriod.day:
        return dayStart;
      case StatsPeriod.week:
        return dayStart.subtract(Duration(days: current.weekday - 1));
      case StatsPeriod.month:
        return DateTime(current.year, current.month, 1);
    }
  }
}
