import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taxiya_core/taxiya_core.dart';

import '../providers/passenger_providers.dart';
import '../services/passenger_location_service.dart';

/// Resultado devuelto al tocar una acción dentro del selector de Origen / Destino.
@immutable
class PlacePickerResult {
  const PlacePickerResult({
    this.selectedPlace,
    this.requestMapPin = false,
  });

  final SelectedRoutePlace? selectedPlace;
  final bool requestMapPin;
}

/// Modal con las 3 modalidades de selección: pin en mapa, destinos personales y puntos públicos.
class PlacePickerSheet extends ConsumerStatefulWidget {
  const PlacePickerSheet({
    super.key,
    required this.isOrigin,
    required this.profile,
    required this.locality,
    this.currentMapCenter,
  });

  final bool isOrigin;
  final Profile profile;
  final Locality? locality;
  final GeoPoint? currentMapCenter;

  @override
  ConsumerState<PlacePickerSheet> createState() => _PlacePickerSheetState();
}

class _PlacePickerSheetState extends ConsumerState<PlacePickerSheet> {
  final _searchCtrl = TextEditingController();
  bool _checkingGps = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _useCurrentGps() async {
    setState(() => _checkingGps = true);
    try {
      final result = await PassengerLocationService.getCurrentFix();
      if (!mounted) return;
      if (result.fix == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.errorMessage ?? 'No pudimos obtener tu ubicación GPS.',
            ),
          ),
        );
        return;
      }

      final fix = result.fix!;
      if (fix.needsAccuracyConfirmation) {
        final action = await showDialog<String>(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext ctx) {
            return AlertDialog(
              title: const Text('Confirmá tu ubicación'),
              content: Text(
                'Tu señal GPS tiene un margen de error de ${fix.accuracyMeters.round()} metros. Te conviene ajustar el pin en el mapa para que el taxi te encuentre exacto.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop('pin'),
                  child: const Text('Ajustar pin en el mapa'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(ctx).pop('confirm'),
                  child: const Text('Confirmar este punto igual'),
                ),
              ],
            );
          },
        );

        if (!mounted) return;
        if (action == 'pin') {
          Navigator.of(context).pop(const PlacePickerResult(requestMapPin: true));
          return;
        }
        if (action != 'confirm') return;
      }

      Navigator.of(context).pop(
        PlacePickerResult(
          selectedPlace: SelectedRoutePlace(
            label: widget.isOrigin
                ? 'Mi ubicación actual'
                : 'Punto marcado con GPS',
            point: fix.point,
            sourceType: 'pin',
            accuracyMeters: fix.accuracyMeters,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _checkingGps = false);
    }
  }

  Future<void> _openCreateLandmarkDialog({
    required bool isPublic,
    int currentPersonalCount = 0,
  }) async {
    final localityId = widget.locality?.id ?? widget.profile.localityId;
    if (localityId == null) return;

    if (!isPublic && !widget.profile.isPremium && currentPersonalCount >= 2) {
      await showDialog<void>(
        context: context,
        builder: (BuildContext ctx) {
          return AlertDialog(
            title: const Text('Límite de lugares personales'),
            content: const Text(
              r'En el Plan Gratuito y Sin Publicidad podés guardar hasta 2 lugares personales. Con Plan Premium ($ 3 USD/mes) guardás todos tus destinos favoritos sin límites.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Entendido'),
              ),
              FilledButton(
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
                child: const Text('Ver Plan Premium'),
              ),
            ],
          );
        },
      );
      return;
    }

    final nameCtrl = TextEditingController();
    var category = isPublic ? 'Plaza' : 'Casa';
    final categories = isPublic
        ? const <String>[
            'Plaza',
            'Hospital / Salud',
            'Terminal / Parada',
            'Escuela',
            'Comercio',
            'Otro',
          ]
        : const <String>['Casa', 'Trabajo', 'Familiar', 'Personal'];

    final targetPoint =
        widget.currentMapCenter ??
        widget.locality?.center ??
        CatamarcaDefaults.belen;

    final saved = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setLocalState) {
            return AlertDialog(
              title: Text(
                isPublic
                    ? 'Sugerir punto público'
                    : 'Guardar destino personal',
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    isPublic
                        ? 'Se guarda en la ubicación actual del mapa y queda visible tras revisión del administrador.'
                        : 'Se guarda privado en la ubicación actual del mapa, listo para usar sin esperar aprobación.',
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameCtrl,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: 'Nombre del lugar',
                      hintText: isPublic
                          ? 'Ej: Terminal de Ómnibus Belén'
                          : 'Ej: Casa',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TaxiyaSelectorField<String>(
                    label: 'Categoría',
                    sheetTitle: 'Elegí una categoría',
                    prefixIcon: Icons.category_outlined,
                    value: category,
                    options: categories
                        .map(
                          (String c) => TaxiyaSelectorOption<String>(
                            value: c,
                            label: c,
                          ),
                        )
                        .toList(),
                    onChanged: (String? v) {
                      if (v != null) setLocalState(() => category = v);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () async {
                    if (nameCtrl.text.trim().length < 2) return;
                    await ref.read(taxiyaRepositoryProvider).createLandmark(
                      localityId: localityId,
                      name: nameCtrl.text,
                      category: category,
                      location: targetPoint,
                      isPublic: isPublic,
                      createdBy: widget.profile.id,
                    );
                    if (ctx.mounted) Navigator.of(ctx).pop(true);
                  },
                  child: Text(isPublic ? 'Enviar sugerencia' : 'Guardar'),
                ),
              ],
            );
          },
        );
      },
    );

    nameCtrl.dispose();
    if (saved == true && mounted) {
      ref.invalidate(passengerLandmarksProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isPublic
                ? 'Enviamos tu sugerencia al administrador para publicarla en el mapa.'
                : 'Guardamos tu destino personal.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final landmarksAsync = ref.watch(passengerLandmarksProvider);
    final all = landmarksAsync.value ?? const <Landmark>[];
    final query = _searchCtrl.text.trim().toLowerCase();

    final allPersonal = all
        .where((Landmark l) => !l.isPublic && l.location != null)
        .toList();
    final personalPlaces = allPersonal
        .where((Landmark l) => query.isEmpty || l.name.toLowerCase().contains(query))
        .toList();
    final publicPlaces = all
        .where(
          (Landmark l) =>
              l.isPublic && l.status == 'approved' && l.location != null,
        )
        .where((Landmark l) => query.isEmpty || l.name.toLowerCase().contains(query))
        .toList();

    final colors = context.taxiyaColors;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.82,
      minChildSize: 0.5,
      maxChildSize: 0.94,
      builder: (BuildContext context, ScrollController scrollCtrl) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.border,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                widget.isOrigin
                    ? '¿Dónde te pasamos a buscar?'
                    : '¿A dónde vas?',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _checkingGps ? null : _useCurrentGps,
                      icon: _checkingGps
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.my_location_rounded),
                      label: const Text('Mi GPS actual'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop(
                          const PlacePickerResult(requestMapPin: true),
                        );
                      },
                      icon: const Icon(Icons.pin_drop_rounded),
                      label: const Text('Pin en mapa'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _searchCtrl,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Buscar plaza, barrio o lugar guardado',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: query.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() {});
                          },
                          icon: const Icon(Icons.clear_rounded),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  controller: scrollCtrl,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            widget.profile.isPremium
                                ? 'Tus destinos personales (ilimitados)'
                                : 'Tus destinos personales (${allPersonal.length} / 2)',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: colors.textSecondary,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () => _openCreateLandmarkDialog(
                            isPublic: false,
                            currentPersonalCount: allPersonal.length,
                          ),
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('Guardar actual'),
                        ),
                      ],
                    ),
                    if (personalPlaces.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          'Todavía no guardaste lugares personales en esta localidad.',
                          style: TextStyle(
                            fontSize: 13,
                            color: colors.textSecondary,
                          ),
                        ),
                      )
                    else
                      ...personalPlaces.map(
                        (Landmark item) => ListTile(
                          leading: Icon(
                            Icons.bookmark_rounded,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          title: Text(
                            item.name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(item.category ?? 'Personal'),
                          trailing: IconButton(
                            tooltip: 'Eliminar lugar guardado',
                            icon: const Icon(Icons.delete_outline_rounded),
                            onPressed: () async {
                              await ref
                                  .read(taxiyaRepositoryProvider)
                                  .deletePersonalLandmark(item.id);
                              ref.invalidate(passengerLandmarksProvider);
                            },
                          ),
                          onTap: () {
                            Navigator.of(context).pop(
                              PlacePickerResult(
                                selectedPlace: SelectedRoutePlace(
                                  label: item.name,
                                  point: item.location!,
                                  sourceType: 'personal',
                                  landmarkId: item.id,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Puntos públicos de ${widget.locality?.name ?? 'la localidad'}',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: colors.textSecondary,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () =>
                              _openCreateLandmarkDialog(isPublic: true),
                          icon: const Icon(Icons.add_location_alt_rounded, size: 18),
                          label: const Text('Sugerir punto'),
                        ),
                      ],
                    ),
                    if (landmarksAsync.isLoading)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (publicPlaces.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'No encontramos referencias públicas con ese nombre.',
                          style: TextStyle(
                            fontSize: 13,
                            color: colors.textSecondary,
                          ),
                        ),
                      )
                    else
                      ...publicPlaces.map(
                        (Landmark item) => ListTile(
                          leading: Icon(
                            Icons.place_rounded,
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                          title: Text(
                            item.name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(item.category ?? 'Referencia pública'),
                          onTap: () {
                            Navigator.of(context).pop(
                              PlacePickerResult(
                                selectedPlace: SelectedRoutePlace(
                                  label: item.name,
                                  point: item.location!,
                                  sourceType: 'public',
                                  landmarkId: item.id,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
