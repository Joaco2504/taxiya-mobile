import 'package:flutter/material.dart';
import 'package:taxiya_core/taxiya_core.dart';

/// Tarjeta inferior de seguimiento en vivo cuando el pasajero tiene un viaje en curso o buscando.
class PassengerActiveTripCard extends StatelessWidget {
  const PassengerActiveTripCard({
    super.key,
    required this.trip,
    required this.driverSummary,
    required this.onOpenChat,
    required this.onShareWhatsApp,
    required this.onPanic,
    required this.onCancelTrip,
    required this.onInspectCarPhoto,
  });

  final Trip trip;
  final DriverPublicSummary? driverSummary;
  final VoidCallback onOpenChat;
  final VoidCallback onShareWhatsApp;
  final VoidCallback onPanic;
  final VoidCallback onCancelTrip;
  final void Function(String url) onInspectCarPhoto;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = context.taxiyaColors;
    final borderLevel = driverSummary?.highestBorderLevel ?? BadgeLevel.none;
    final hasMaterialBorder = borderLevel.grantsPassengerCardBorder;
    final statusColor = _statusColor(trip.status, scheme, colors);

    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: hasMaterialBorder
              ? Color(borderLevel.colorHex)
              : colors.border,
          width: hasMaterialBorder
              ? (borderLevel.grantsSpecialBorder ? 2.6 : 2.1)
              : 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    trip.status.labelAr,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 12.5,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (trip.isRoundTrip)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.secondary.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Ida y vuelta (${trip.waitMinutes ?? 10} min)',
                      style: TextStyle(
                        color: scheme.secondary,
                        fontWeight: FontWeight.w700,
                        fontSize: 11.5,
                      ),
                    ),
                  ),
                const Spacer(),
                if (trip.scheduledFor != null)
                  Text(
                    TaxiyaDateUtils.formatTime(context, trip.scheduledFor!),
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: colors.textSecondary,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Salida: ${trip.originAddress ?? 'Punto marcado'}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
            ),
            if (trip.destAddress != null && trip.destAddress!.isNotEmpty)
              Text(
                'Destino: ${trip.destAddress}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: colors.textSecondary),
              ),
            if (trip.scheduledFor != null && trip.isScheduledStillDormant())
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Reserva confirmada. La búsqueda automática se activa 30 minutos antes.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: scheme.secondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            if (driverSummary != null) ...[
              const Divider(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TaxiyaAvatar(
                    avatarUrl: driverSummary!.avatarUrl,
                    fullName: driverSummary!.displayName,
                    radius: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                driverSummary!.displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            if (driverSummary!.ratingAvg != null) ...[
                              Icon(
                                Icons.star_rounded,
                                size: 16,
                                color: scheme.primary,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                driverSummary!.ratingAvg!.toStringAsFixed(1),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${driverSummary!.companyName ?? 'Taxista independiente'} · ${driverSummary!.vehicleDescription}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: colors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Patente: ${driverSummary!.visiblePlateLabel} · ${driverSummary!.visiblePermitLabel}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (driverSummary!.carPhotoUrl != null &&
                      driverSummary!.carPhotoUrl!.trim().isNotEmpty) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => onInspectCarPhoto(driverSummary!.carPhotoUrl!),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          driverSummary!.carPhotoUrl!,
                          width: 58,
                          height: 58,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              if (driverSummary!.activeBadges.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: driverSummary!.activeBadges
                      .where((b) => b.badgeCode != null)
                      .map(
                        (b) => TaxiyaBadgePill(
                          badgeCode: b.badgeCode!,
                          level: b.level,
                          compact: true,
                        ),
                      )
                      .toList(),
                ),
              ],
            ] else if (trip.status.isSearching) ...[
              const SizedBox(height: 10),
              const LinearProgressIndicator(minHeight: 3),
              const SizedBox(height: 6),
              Text(
                trip.isScheduledStillDormant()
                    ? 'Aguardando horario de despacho (30 min antes).'
                    : 'Avisando a los taxis habilitados cercanos...',
                style: TextStyle(fontSize: 12.5, color: colors.textSecondary),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (driverSummary != null) ...[
                  FilledButton.icon(
                    onPressed: onOpenChat,
                    icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                    label: const Text('Chat'),
                  ),
                  OutlinedButton.icon(
                    onPressed: onShareWhatsApp,
                    icon: const Icon(Icons.share_rounded, size: 18),
                    label: const Text('Compartir'),
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.error,
                      side: BorderSide(color: colors.error),
                    ),
                    onPressed: onPanic,
                    icon: const Icon(Icons.warning_rounded, size: 18),
                    label: const Text('Pánico'),
                  ),
                ],
                if (trip.status.isSearching ||
                    trip.status == TripStatus.accepted ||
                    trip.status == TripStatus.arriving ||
                    trip.status == TripStatus.inDoor)
                  TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: colors.error),
                    onPressed: onCancelTrip,
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: const Text('Cancelar'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(
    TripStatus status,
    ColorScheme scheme,
    TaxiyaSemanticColors colors,
  ) {
    switch (status) {
      case TripStatus.searching:
      case TripStatus.requested:
        return scheme.primary;
      case TripStatus.accepted:
      case TripStatus.arriving:
        return scheme.secondary;
      case TripStatus.inDoor:
      case TripStatus.inProgress:
        return colors.success;
      case TripStatus.waiting:
      case TripStatus.waitingReturn:
        return colors.warning;
      case TripStatus.completed:
        return colors.success;
      case TripStatus.cancelled:
        return colors.error;
    }
  }
}
