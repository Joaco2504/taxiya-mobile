import 'package:flutter/material.dart';
import 'package:taxiya_core/taxiya_core.dart';

/// Diálogo de motivos para cancelar un viaje en curso o en búsqueda.
Future<String?> showPassengerCancelReasonDialog(BuildContext context) {
  const reasons = <String>[
    'El móvil demora demasiado',
    'Cambié de planes',
    'Pedí el viaje por error',
    'El origen quedó mal marcado',
    'Otro motivo',
  ];
  var selected = reasons.first;

  return showDialog<String>(
    context: context,
    builder: (BuildContext ctx) {
      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setLocalState) {
          return AlertDialog(
            title: const Text('Cancelar viaje'),
            content: RadioGroup<String>(
              groupValue: selected,
              onChanged: (String? value) {
                if (value != null) setLocalState(() => selected = value);
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Contanos brevemente el motivo para avisar al sistema:',
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...reasons.map((String r) {
                    return RadioListTile<String>(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      value: r,
                      title: Text(r),
                    );
                  }),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(null),
                child: const Text('Seguir viajando'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: ctx.taxiyaColors.error,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.of(ctx).pop(selected),
                child: const Text('Confirmar cancelación'),
              ),
            ],
          );
        },
      );
    },
  );
}

/// Modal de calificación de 1 a 5 estrellas al finalizar el traslado.
Future<void> showPassengerRatingModal({
  required BuildContext context,
  required TaxiyaRepository repo,
  required Trip trip,
  String? driverName,
}) async {
  var stars = 5;
  final commentCtrl = TextEditingController();
  var saving = false;

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext ctx) {
      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setLocalState) {
          final theme = Theme.of(context);
          final colors = context.taxiyaColors;
          return AlertDialog(
            title: const Text('Calificá tu viaje'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    driverName != null && driverName.isNotEmpty
                        ? '¿Cómo estuvo el viaje con $driverName?'
                        : '¿Cómo estuvo tu viaje en TaxiYa?',
                    style: TextStyle(color: colors.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List<Widget>.generate(5, (int index) {
                      final value = index + 1;
                      final active = value <= stars;
                      return IconButton(
                        onPressed: saving
                            ? null
                            : () => setLocalState(() => stars = value),
                        iconSize: 34,
                        icon: Icon(
                          active
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          color: active
                              ? theme.colorScheme.primary
                              : colors.textSecondary,
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: commentCtrl,
                    minLines: 2,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Comentario opcional',
                      hintText: 'Ej: Llegó rápido y el auto impecable',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.of(ctx).pop(),
                child: const Text('Ahora no'),
              ),
              FilledButton(
                onPressed: saving || trip.driverId == null
                    ? null
                    : () async {
                        setLocalState(() => saving = true);
                        try {
                          await repo.submitRating(
                            tripId: trip.id,
                            passengerId: trip.passengerId,
                            driverId: trip.driverId!,
                            stars: stars,
                            comment: commentCtrl.text,
                          );
                          if (ctx.mounted) {
                            Navigator.of(ctx).pop();
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(
                                content: Text('Gracias por calificar el viaje.'),
                              ),
                            );
                          }
                        } catch (_) {
                          setLocalState(() => saving = false);
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'No pudimos guardar tu calificación sin señal.',
                                ),
                              ),
                            );
                          }
                        }
                      },
                child: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Enviar calificación'),
              ),
            ],
          );
        },
      );
    },
  );
  commentCtrl.dispose();
}
