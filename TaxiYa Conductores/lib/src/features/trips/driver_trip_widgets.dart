import 'package:flutter/material.dart';
import 'package:taxiya_core/taxiya_core.dart';

/// Tarjeta gigante de pedido entrante para operar con una mano mientras el chofer está En línea.
class DriverIncomingOrderCard extends StatelessWidget {
  const DriverIncomingOrderCard({
    super.key,
    required this.trip,
    required this.driverLocation,
    required this.prioritySeconds,
    required this.accepting,
    required this.onAccept,
    required this.onDismiss,
  });

  final Trip trip;
  final GeoPoint? driverLocation;
  final int prioritySeconds;
  final bool accepting;
  final VoidCallback onAccept;
  final VoidCallback onDismiss;

  String? _distanceLabel() {
    if (driverLocation == null || trip.originPoint == null) return null;
    final meters = haversineDistanceMeters(
      driverLocation!.lat,
      driverLocation!.lng,
      trip.originPoint!.lat,
      trip.originPoint!.lng,
    );
    if (meters < 1000) return 'A ${meters.round()} m tuyo';
    return 'A ${(meters / 1000).toStringAsFixed(1)} km tuyo';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.taxiyaColors;
    final dist = _distanceLabel();

    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: scheme.primary, width: 2.2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                    color: scheme.primary.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    trip.scheduledFor != null
                        ? 'Reserva programada'
                        : 'Nuevo pedido de taxi',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: scheme.primary,
                      fontSize: 12.5,
                    ),
                  ),
                ),
                if (prioritySeconds > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: colors.success.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Prioridad +${prioritySeconds}s',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: colors.success,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                if (dist != null)
                  Text(
                    dist,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Subida: ${trip.originAddress ?? 'Punto marcado en mapa'}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              'Destino: ${trip.destAddress?.trim().isNotEmpty == true ? trip.destAddress! : 'A confirmar con el pasajero'}',
              style: TextStyle(fontSize: 13.5, color: colors.textSecondary),
            ),
            if (trip.isRoundTrip) ...[
              const SizedBox(height: 6),
              Text(
                'Ida y vuelta · Espera estimada: ${trip.waitMinutes ?? 10} min',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: scheme.secondary,
                ),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 54,
                    child: OutlinedButton(
                      onPressed: accepting ? null : onDismiss,
                      child: const Text('Omitir'),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 54,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: colors.success,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: accepting ? null : onAccept,
                      icon: accepting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check_rounded),
                      label: const Text(
                        'Aceptar viaje',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Panel de un viaje activo en el chofer: botón único por etapa, espera ida y vuelta >10 min y herramientas rápidas.
class DriverActiveTripPanel extends StatelessWidget {
  const DriverActiveTripPanel({
    super.key,
    required this.trip,
    required this.passengerProfile,
    required this.driverLocation,
    required this.pendingSyncCount,
    required this.busy,
    required this.onAdvanceStatus,
    required this.onLongWaitChoiceWait,
    required this.onLongWaitChoiceRelease,
    required this.onOpenChat,
    required this.onPanic,
    required this.onCancel,
  });

  final Trip trip;
  final Profile? passengerProfile;
  final GeoPoint? driverLocation;
  final int pendingSyncCount;
  final bool busy;
  final void Function(TripStatus nextStatus) onAdvanceStatus;
  final VoidCallback onLongWaitChoiceWait;
  final VoidCallback onLongWaitChoiceRelease;
  final VoidCallback onOpenChat;
  final VoidCallback onPanic;
  final VoidCallback onCancel;

  double? _distanceToOrigin() {
    if (driverLocation == null || trip.originPoint == null) return null;
    return haversineDistanceMeters(
      driverLocation!.lat,
      driverLocation!.lng,
      trip.originPoint!.lat,
      trip.originPoint!.lng,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.taxiyaColors;
    final distOrigin = _distanceToOrigin();
    final nearDoor =
        distOrigin != null &&
        distOrigin <= 100.0 &&
        (trip.status == TripStatus.accepted ||
            trip.status == TripStatus.arriving);

    final requiresLongWaitDecision =
        trip.status == TripStatus.inProgress &&
        trip.isRoundTrip &&
        (trip.waitMinutes ?? 10) > 10;

    return Card(
      elevation: 6,
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                    color: scheme.secondary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    trip.status.labelAr,
                    style: TextStyle(
                      color: scheme.secondary,
                      fontWeight: FontWeight.w800,
                      fontSize: 12.5,
                    ),
                  ),
                ),
                const Spacer(),
                if (distOrigin != null &&
                    (trip.status == TripStatus.accepted ||
                        trip.status == TripStatus.arriving))
                  Text(
                    distOrigin < 1000
                        ? 'A ${distOrigin.round()} m del origen'
                        : 'A ${(distOrigin / 1000).toStringAsFixed(1)} km',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: nearDoor ? colors.success : colors.textSecondary,
                    ),
                  ),
              ],
            ),
            if (pendingSyncCount > 0) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: colors.warning.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$pendingSyncCount cambio(s) en cola sin 4G. Se suben al volver la señal.',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: colors.warning,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 10),
            Text(
              passengerProfile?.fullName?.trim().isNotEmpty == true
                  ? 'Pasajero: ${passengerProfile!.fullName}'
                  : 'Pasajero asignado',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
            const SizedBox(height: 4),
            Text(
              'Subida: ${trip.originAddress ?? 'Punto en mapa'}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
            ),
            if (trip.destAddress != null && trip.destAddress!.isNotEmpty)
              Text(
                'Destino: ${trip.destAddress}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: colors.textSecondary),
              ),
            if (nearDoor) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: colors.success.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Estás a menos de 100 m del punto de salida. Avisá que llegaste.',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: colors.success,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            if (requiresLongWaitDecision) ...[
              Text(
                'Ida y vuelta con espera de ${trip.waitMinutes} min (supera 10 min). ¿Qué preferís al llegar a destino?',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: colors.warning,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: OutlinedButton(
                        onPressed: busy ? null : onLongWaitChoiceRelease,
                        child: const Text(
                          'Liberar y trabajar',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: FilledButton(
                        onPressed: busy ? null : onLongWaitChoiceWait,
                        child: const Text(
                          'Esperar regreso',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ] else
              _buildPrimaryAction(context, colors, scheme),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                OutlinedButton.icon(
                  onPressed: onOpenChat,
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                  label: const Text('Chat'),
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
                if (trip.status == TripStatus.accepted ||
                    trip.status == TripStatus.arriving ||
                    trip.status == TripStatus.inDoor)
                  TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: colors.error),
                    onPressed: busy ? null : onCancel,
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

  Widget _buildPrimaryAction(
    BuildContext context,
    TaxiyaSemanticColors colors,
    ColorScheme scheme,
  ) {
    late String label;
    late TripStatus target;
    Color bg = scheme.primary;
    Color fg = scheme.onPrimary;

    switch (trip.status) {
      case TripStatus.accepted:
        label = 'Voy en camino al origen';
        target = TripStatus.arriving;
      case TripStatus.arriving:
        label = 'Estoy en la puerta';
        target = TripStatus.inDoor;
        bg = colors.success;
        fg = Colors.white;
      case TripStatus.inDoor:
        label = 'Pasajero subió · Iniciar viaje';
        target = TripStatus.inProgress;
        bg = scheme.secondary;
        fg = scheme.onSecondary;
      case TripStatus.inProgress:
        if (trip.isRoundTrip) {
          label =
              'Llegamos · Esperar regreso (${trip.waitMinutes ?? 10} min)';
          target = TripStatus.waitingReturn;
          bg = colors.warning;
          fg = Colors.white;
        } else {
          label = 'Finalizar viaje';
          target = TripStatus.completed;
          bg = colors.success;
          fg = Colors.white;
        }
      case TripStatus.waiting:
      case TripStatus.waitingReturn:
        label = 'Finalizar ida y vuelta';
        target = TripStatus.completed;
        bg = colors.success;
        fg = Colors.white;
      default:
        label = 'Finalizar viaje';
        target = TripStatus.completed;
    }

    return SizedBox(
      height: 56,
      child: FilledButton(
        style: FilledButton.styleFrom(backgroundColor: bg, foregroundColor: fg),
        onPressed: busy ? null : () => onAdvanceStatus(target),
        child: busy
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.2),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
      ),
    );
  }
}
