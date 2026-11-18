import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:taxiya_core/taxiya_core.dart';

import '../features/stats/driver_performance_screen.dart';
import '../features/support/driver_help_screen.dart';
import '../providers/driver_providers.dart';
import '../services/driver_location_service.dart';
import '../services/image_upload_helper.dart';

/// Configuración del chofer: perfil, avatar, tema, notificaciones y privacidad pública.
class DriverSettingsScreen extends ConsumerStatefulWidget {
  const DriverSettingsScreen({
    super.key,
    required this.onEditDossier,
  });

  final VoidCallback onEditDossier;

  @override
  ConsumerState<DriverSettingsScreen> createState() =>
      _DriverSettingsScreenState();
}

class _DriverSettingsScreenState extends ConsumerState<DriverSettingsScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  bool _initialized = false;
  bool _savingProfile = false;
  bool _uploadingAvatar = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _syncControllers(Profile profile) {
    if (_initialized) return;
    _initialized = true;
    _nameCtrl.text = profile.fullName ?? '';
    _emailCtrl.text = profile.email ?? '';
    _phoneCtrl.text = profile.phone ?? '';
  }

  Future<void> _saveProfileData(Profile profile) async {
    final fullName = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();

    if (fullName.length < 3 || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Revisá tu nombre y correo electrónico.'),
        ),
      );
      return;
    }

    setState(() => _savingProfile = true);
    final repo = ref.read(taxiyaRepositoryProvider);
    try {
      await repo.updateProfileFields(profile.id, <String, dynamic>{
        'full_name': fullName,
        'email': email,
        'phone': phone,
      });

      final currentAuthEmail =
          ref.read(supabaseClientProvider).auth.currentUser?.email;
      if (currentAuthEmail != null &&
          currentAuthEmail.toLowerCase() != email.toLowerCase()) {
        await repo.updateAuthEmail(email);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Guardamos tus cambios.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No pudimos actualizar todos los datos. Revisá tu conexión.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _savingProfile = false);
    }
  }

  Future<void> _uploadCustomAvatar(Profile profile) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (BuildContext ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded),
              title: const Text('Sacar selfie'),
              onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Elegir de la galería'),
              onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    setState(() => _uploadingAvatar = true);
    try {
      final bytes = await DriverImageHelper.pickAndCompress(source);
      if (bytes == null) return;

      final repo = ref.read(taxiyaRepositoryProvider);
      final publicUrl = await repo.uploadPublicImage(
        userId: profile.id,
        folder: 'avatars',
        jpegBytes: bytes,
      );
      await repo.updateProfileFields(profile.id, <String, dynamic>{
        'avatar_url': publicUrl,
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No pudimos subir tu foto. Intentá de nuevo.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  Future<void> _selectPresetAvatar(
    Profile profile,
    TaxiyaPresetAvatar preset,
  ) async {
    try {
      await ref.read(taxiyaRepositoryProvider).updateProfileFields(
        profile.id,
        <String, dynamic>{'avatar_url': preset.storageUri},
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No pudimos guardar el avatar.')),
        );
      }
    }
  }

  Future<void> _signOut() async {
    await DriverLocationController.stopBackgroundService();
    await ref.read(supabaseClientProvider).auth.signOut();
    await ref.read(hiveCacheProvider).clearUserCache();
    if (mounted) {
      Navigator.of(context).popUntil((Route<dynamic> route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentProfileProvider).value;
    final details = ref.watch(driverDetailsProvider).value;
    final themeMode = ref.watch(themeModeProvider);
    final selectedSoundPreset = ref.watch(driverSoundPresetProvider);
    final cache = ref.watch(hiveCacheProvider);
    final colors = context.taxiyaColors;
    final knownBadges = cache.loadDriverBadges(profile?.id ?? '');
    final hasHighBadge = knownBadges.any(
      (b) => b.isActive && b.level.grantsPremiumZoneStatsFor15Days,
    );

    if (profile == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    _syncControllers(profile);

    return Scaffold(
      appBar: AppBar(title: const Text('Configuración')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        TaxiyaAvatar(
                          avatarUrl: profile.avatarUrl,
                          fullName: profile.fullName,
                          radius: 34,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Foto o avatar visible',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 6),
                              OutlinedButton.icon(
                                onPressed: _uploadingAvatar
                                    ? null
                                    : () => _uploadCustomAvatar(profile),
                                icon: _uploadingAvatar
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.photo_camera_rounded),
                                label: const Text('Subir foto propia'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'O elegí un avatar predefinido',
                      style: TextStyle(
                        fontSize: 13,
                        color: colors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: TaxiyaAvatars.driverCatalog.map((preset) {
                        final selected =
                            TaxiyaAvatars.fromUri(profile.avatarUrl)?.id ==
                            preset.id;
                        return InkWell(
                          borderRadius: BorderRadius.circular(28),
                          onTap: () => _selectPresetAvatar(profile, preset),
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: selected
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.transparent,
                                width: 2.5,
                              ),
                            ),
                            child: TaxiyaPresetAvatarBadge(
                              preset: preset,
                              radius: 21,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Tus datos personales',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nombre y apellido',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Correo electrónico',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Celular',
                        helperText: 'Formato recomendado: +54 9 3835 ...',
                      ),
                    ),
                    const SizedBox(height: 14),
                    FilledButton(
                      onPressed: _savingProfile
                          ? null
                          : () => _saveProfileData(profile),
                      child: _savingProfile
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2.5),
                            )
                          : const Text('Guardar datos'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Apariencia',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 10),
                    SegmentedButton<ThemeMode>(
                      segments: const [
                        ButtonSegment<ThemeMode>(
                          value: ThemeMode.light,
                          label: Text('Claro'),
                        ),
                        ButtonSegment<ThemeMode>(
                          value: ThemeMode.dark,
                          label: Text('Oscuro'),
                        ),
                        ButtonSegment<ThemeMode>(
                          value: ThemeMode.system,
                          label: Text('Sistema'),
                        ),
                      ],
                      selected: <ThemeMode>{themeMode},
                      onSelectionChanged: (Set<ThemeMode> sel) {
                        ref
                            .read(themeModeProvider.notifier)
                            .setThemeMode(sel.first);
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                    child: Text(
                      'Notificaciones',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  SwitchListTile(
                    title: const Text('Alertas de viajes y habilitación'),
                    subtitle: const Text(
                      'Avisos sonoros de solicitudes y vencimiento de papeles',
                    ),
                    value: cache.notifyTrips,
                    onChanged: (bool val) async {
                      await cache.setNotifyTrips(val);
                      if (mounted) setState(() {});
                    },
                  ),
                  SwitchListTile(
                    title: const Text('Novedades de TaxiYa'),
                    subtitle: const Text(
                      'Comunicados operativos y mejoras en Catamarca',
                    ),
                    value: profile.notifyPromos,
                    onChanged: (bool val) async {
                      await cache.setNotifyPromos(val);
                      await ref
                          .read(taxiyaRepositoryProvider)
                          .updateProfileFields(profile.id, <String, dynamic>{
                            'notify_promos': val,
                          });
                    },
                  ),
                ],
              ),
            ),
            if (details != null) ...[
              const SizedBox(height: 14),
              Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                      child: Text(
                        'Privacidad en el mapa',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    SwitchListTile(
                      title: const Text('Mostrar patente públicamente'),
                      subtitle: const Text(
                        'Los pasajeros ven tu dominio antes de pedir viaje',
                      ),
                      value: details.showPlatePublic,
                      onChanged: (bool val) async {
                        await ref
                            .read(taxiyaRepositoryProvider)
                            .updateDriverPrivacy(
                              userId: profile.id,
                              showPlatePublic: val,
                            );
                      },
                    ),
                    SwitchListTile(
                      title: const Text(
                        'Mostrar vigencia de habilitación municipal',
                      ),
                      subtitle: const Text(
                        'Muestra tu fecha de habilitación al pasajero',
                      ),
                      value: details.showPermitPublic,
                      onChanged: (bool val) async {
                        await ref
                            .read(taxiyaRepositoryProvider)
                            .updateDriverPrivacy(
                              userId: profile.id,
                              showPermitPublic: val,
                            );
                      },
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (details != null) ...[
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => DriverPerformanceScreen(
                        profile: profile,
                        details: details,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.emoji_events_outlined),
                label: const Text('Tu rendimiento y logros'),
              ),
              const SizedBox(height: 10),
            ],
            OutlinedButton.icon(
              onPressed: () {
                final localities =
                    ref.read(localitiesProvider).value ?? const <Locality>[];
                var locName = 'Catamarca';
                for (final l in localities) {
                  if (l.id == profile.localityId) {
                    locName = l.name;
                    break;
                  }
                }
                openDriverHelpScreen(
                  context: context,
                  profile: profile,
                  localityName: locName,
                );
              },
              icon: const Icon(Icons.help_outline_rounded),
              label: const Text('Ayuda y guía de uso'),
            ),
            const SizedBox(height: 14),
            Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ListTile(
                    leading: Icon(
                      profile.isPremium
                          ? Icons.workspace_premium_rounded
                          : Icons.verified_user_outlined,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    title: const Text(
                      'Planes y Suscripciones',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      profile.subscriptionTier.labelAr,
                      style: TextStyle(color: colors.textSecondary),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const TaxiyaPlansScreen(
                            role: TaxiyaRole.driver,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Sonido de nuevos pedidos',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        if (!profile.isPremium && !hasHighBadge)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              'Plan Premium',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      profile.isPremium || hasHighBadge
                          ? 'Elegí el tono distintivo para cuando entre un viaje.'
                          : 'Desbloqueá tonos personalizados con Plan Premium o Nivel Diamante.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    RadioGroup<DriverOrderSoundPreset>(
                      groupValue: selectedSoundPreset,
                      onChanged: (DriverOrderSoundPreset? val) async {
                        if (val == null) return;
                        if (!profile.isPremium &&
                            !hasHighBadge &&
                            val != DriverOrderSoundPreset.classic) {
                          if (!context.mounted) return;
                          await Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const TaxiyaPlansScreen(
                                role: TaxiyaRole.driver,
                              ),
                            ),
                          );
                          return;
                        }
                        await ref
                            .read(driverSoundPresetProvider.notifier)
                            .setPreset(val);
                      },
                      child: Column(
                        children: DriverOrderSoundPreset.values.map((
                          DriverOrderSoundPreset preset,
                        ) {
                          final unlocked =
                              profile.isPremium ||
                              hasHighBadge ||
                              preset == DriverOrderSoundPreset.classic;
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Radio<DriverOrderSoundPreset>(
                              value: preset,
                            ),
                            title: Text(
                              preset.labelAr,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              unlocked
                                  ? preset.descriptionAr
                                  : 'Disponible en Plan Premium',
                              style: TextStyle(
                                fontSize: 12,
                                color: colors.textSecondary,
                              ),
                            ),
                            trailing: IconButton(
                              tooltip: 'Probar tono',
                              icon: const Icon(Icons.volume_up_rounded),
                              onPressed: () {
                                TaxiyaSoundService().playPresetPreview(preset);
                              },
                            ),
                            onTap: () async {
                              if (!unlocked) {
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => const TaxiyaPlansScreen(
                                      role: TaxiyaRole.driver,
                                    ),
                                  ),
                                );
                                return;
                              }
                              await ref
                                  .read(driverSoundPresetProvider.notifier)
                                  .setPreset(preset);
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                widget.onEditDossier();
              },
              icon: const Icon(Icons.badge_outlined),
              label: const Text('Actualizar vehículo o documentación'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: colors.error,
                side: BorderSide(color: colors.error),
              ),
              onPressed: _signOut,
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Cerrar sesión'),
            ),
            if (profile.showsAds) ...[
              const SizedBox(height: 14),
              TaxiyaAdBannerWidget(
                localityId: profile.localityId ?? '',
                subscriptionTier: profile.subscriptionTier,
                role: TaxiyaRole.driver,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
