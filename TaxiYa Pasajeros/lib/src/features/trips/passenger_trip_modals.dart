import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

/// Modal de calificación de 1 a 5 estrellas al finalizar el traslado,
/// con botón de estrella para marcar Taxista favorito (Plan Premium).
Future<void> showPassengerRatingModal({
  required BuildContext context,
  required TaxiyaRepository repo,
  required Trip trip,
  required Profile passengerProfile,
  DriverPublicSummary? driverSummary,
  String? driverName,
  VoidCallback? onFavoritesChanged,
}) async {
  var stars = 5;
  final commentCtrl = TextEditingController();
  var saving = false;
  var togglingFav = false;
  final initialFavorites = passengerProfile.isPremium && trip.driverId != null
      ? await repo.fetchFavoriteDrivers(passengerProfile.id)
      : const <FavoriteDriverEntry>[];
  var isFavorite =
      trip.driverId != null &&
      initialFavorites.any((e) => e.driverId == trip.driverId);

  if (!context.mounted) {
    commentCtrl.dispose();
    return;
  }

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
                  if (trip.driverId != null) ...[
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: togglingFav
                          ? null
                          : () async {
                              if (!passengerProfile.isPremium) {
                                Navigator.of(ctx).pop();
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => const TaxiyaPlansScreen(
                                      role: TaxiyaRole.passenger,
                                    ),
                                  ),
                                );
                                return;
                              }
                              setLocalState(() => togglingFav = true);
                              try {
                                final nowFav = await repo.toggleFavoriteDriver(
                                  passengerId: passengerProfile.id,
                                  driver: FavoriteDriverEntry(
                                    driverId: trip.driverId!,
                                    fullName:
                                        driverSummary?.displayName ??
                                        driverName ??
                                        'Chofer TaxiYa',
                                    vehicleLabel:
                                        driverSummary?.vehicleDescription,
                                    plateNumber:
                                        driverSummary?.visiblePlateLabel,
                                    companyName: driverSummary?.companyName,
                                    avatarUrl: driverSummary?.avatarUrl,
                                  ),
                                );
                                onFavoritesChanged?.call();
                                setLocalState(() => isFavorite = nowFav);
                              } finally {
                                if (ctx.mounted) {
                                  setLocalState(() => togglingFav = false);
                                }
                              }
                            },
                      icon: Icon(
                        isFavorite
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        color: isFavorite
                            ? theme.colorScheme.primary
                            : colors.textSecondary,
                      ),
                      label: Text(
                        passengerProfile.isPremium
                            ? (isFavorite
                                ? 'Guardado en Taxistas Favoritos (+10 s)'
                                : 'Marcar como Taxista favorito')
                            : 'Taxista favorito (exclusivo Premium)',
                      ),
                    ),
                  ],
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

/// Hoja para consultar o quitar Taxistas Favoritos del pasajero.
Future<void> showPassengerFavoriteDriversSheet({
  required BuildContext context,
  required Profile passengerProfile,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (BuildContext ctx) {
      return Consumer(
        builder: (BuildContext context, WidgetRef ref, _) {
          final colors = context.taxiyaColors;
          final scheme = Theme.of(context).colorScheme;
          final favsAsync =
              ref.watch(favoriteDriversProvider(passengerProfile.id));
          final favs = favsAsync.value ?? const <FavoriteDriverEntry>[];

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Mis Taxistas Favoritos',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    passengerProfile.isPremium
                        ? 'Cuando pedís un taxi, tus choferes favoritos ven tu solicitud 10 segundos antes que el resto.'
                        : r'Marcá con estrella a tus choferes de confianza para que reciban tus pedidos 10 segundos antes con Plan Premium ($ 3 USD/mes).',
                    style: TextStyle(fontSize: 13, color: colors.textSecondary),
                  ),
                  const SizedBox(height: 14),
                  if (!passengerProfile.isPremium)
                    FilledButton.icon(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const TaxiyaPlansScreen(
                              role: TaxiyaRole.passenger,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.workspace_premium_rounded),
                      label: const Text('Conocer Plan Premium'),
                    )
                  else if (favsAsync.isLoading)
                    const Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (favs.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        'Todavía no agregaste choferes favoritos. Podés tocar el ícono de estrella al finalizar tu próximo viaje.',
                        style: TextStyle(color: colors.textSecondary),
                      ),
                    )
                  else
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: favs.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (_, int i) {
                          final fav = favs[i];
                          return ListTile(
                            leading: TaxiyaAvatar(
                              avatarUrl: fav.avatarUrl,
                              fullName: fav.fullName,
                              radius: 20,
                            ),
                            title: Text(
                              fav.fullName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(
                              <String>[
                                if (fav.vehicleLabel != null) fav.vehicleLabel!,
                                if (fav.plateNumber != null) fav.plateNumber!,
                              ].join(' · '),
                            ),
                            trailing: IconButton(
                              tooltip: 'Quitar de favoritos',
                              icon: Icon(
                                Icons.star_rounded,
                                color: scheme.primary,
                              ),
                              onPressed: () async {
                                await ref
                                    .read(taxiyaRepositoryProvider)
                                    .toggleFavoriteDriver(
                                      passengerId: passengerProfile.id,
                                      driver: fav,
                                    );
                                ref.invalidate(
                                  favoriteDriversProvider(passengerProfile.id),
                                );
                              },
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}
