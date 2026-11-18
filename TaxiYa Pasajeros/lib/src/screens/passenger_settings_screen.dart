import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:taxiya_core/taxiya_core.dart';

import '../features/support/passenger_help_screen.dart';
import '../features/trips/passenger_trip_modals.dart';
import '../services/passenger_image_helper.dart';

/// Configuración del pasajero: nombre, correo, selfie o 12 avatares, localidad, tema y avisos.
class PassengerSettingsScreen extends ConsumerStatefulWidget {
  const PassengerSettingsScreen({super.key});

  @override
  ConsumerState<PassengerSettingsScreen> createState() =>
      _PassengerSettingsScreenState();
}

class _PassengerSettingsScreenState
    extends ConsumerState<PassengerSettingsScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  bool _initialized = false;
  bool _savingProfile = false;
  bool _uploadingSelfie = false;
  String? _selectedLocalityId;

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
    _selectedLocalityId = profile.localityId;
  }

  Future<void> _saveProfile(Profile profile) async {
    final fullName = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();

    if (fullName.length < 3 || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Revisá tu nombre y correo electrónico.')),
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
        'locality_id': ?_selectedLocalityId,
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
              'No pudimos guardar ahora. Revisá tu conexión e intentá de nuevo.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _savingProfile = false);
    }
  }

  Future<void> _uploadSelfie(Profile profile) async {
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

    setState(() => _uploadingSelfie = true);
    try {
      final bytes = await PassengerImageHelper.pickAndCompress(source);
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
          const SnackBar(content: Text('No pudimos subir tu foto.')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingSelfie = false);
    }
  }

  Future<void> _selectPreset(
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
          const SnackBar(content: Text('No pudimos cambiar tu avatar.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentProfileProvider).value;
    final localities =
        ref.watch(localitiesProvider).value ?? const <Locality>[];
    final themeMode = ref.watch(themeModeProvider);
    final cache = ref.watch(hiveCacheProvider);
    final colors = context.taxiyaColors;

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
                                'Tu foto o avatar',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 6),
                              OutlinedButton.icon(
                                onPressed: _uploadingSelfie
                                    ? null
                                    : () => _uploadSelfie(profile),
                                icon: _uploadingSelfie
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.photo_camera_rounded),
                                label: const Text('Subir selfie'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Catálogo de 12 avatares predefinidos',
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
                      children: TaxiyaAvatars.passengerCatalog.map((preset) {
                        final selected =
                            TaxiyaAvatars.fromUri(profile.avatarUrl)?.id ==
                            preset.id;
                        return InkWell(
                          borderRadius: BorderRadius.circular(28),
                          onTap: () => _selectPreset(profile, preset),
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
                      'Tus datos y localidad',
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
                      ),
                    ),
                    if (localities.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      TaxiyaSelectorField<String>(
                        label: 'Localidad habitual',
                        sheetTitle: 'Elegí tu localidad habitual',
                        prefixIcon: Icons.location_city_rounded,
                        value: _selectedLocalityId ?? localities.first.id,
                        options: localities
                            .map(
                              (Locality l) => TaxiyaSelectorOption<String>(
                                value: l.id,
                                label: l.name,
                                subtitle: l.province,
                              ),
                            )
                            .toList(),
                        onChanged: (String? v) {
                          setState(() => _selectedLocalityId = v);
                        },
                      ),
                    ],
                    const SizedBox(height: 14),
                    FilledButton(
                      onPressed:
                          _savingProfile ? null : () => _saveProfile(profile),
                      child: _savingProfile
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2.5),
                            )
                          : const Text('Guardar cambios'),
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
                            role: TaxiyaRole.passenger,
                          ),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: Icon(
                      Icons.star_rounded,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    title: const Text(
                      'Mis Taxistas Favoritos',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      profile.isPremium
                          ? 'Ven tus pedidos 10 segundos antes que el resto'
                          : 'Beneficio exclusivo del Plan Premium',
                      style: TextStyle(color: colors.textSecondary),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => showPassengerFavoriteDriversSheet(
                      context: context,
                      passengerProfile: profile,
                    ),
                  ),
                ],
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
                      'Tema visual',
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
                      'Preferencias de notificaciones',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  SwitchListTile(
                    title: const Text('Avisos de llegada del taxi'),
                    subtitle: const Text(
                      'Alertas cuando el móvil esté cerca o en camino',
                    ),
                    value: cache.notifyTrips,
                    onChanged: (bool val) async {
                      await cache.setNotifyTrips(val);
                      if (mounted) setState(() {});
                    },
                  ),
                  SwitchListTile(
                    title: const Text('Novedades y avisos locales'),
                    subtitle: const Text(
                      'Comunicados útiles de TaxiYa en tu localidad',
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
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () {
                var locName = 'Catamarca';
                for (final l in localities) {
                  if (l.id == profile.localityId) {
                    locName = l.name;
                    break;
                  }
                }
                openPassengerHelpScreen(
                  context: context,
                  profile: profile,
                  localityName: locName,
                );
              },
              icon: const Icon(Icons.help_outline_rounded),
              label: const Text('Ayuda y guía de uso'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: colors.error,
                side: BorderSide(color: colors.error),
              ),
              onPressed: () async {
                await ref.read(supabaseClientProvider).auth.signOut();
                await ref.read(hiveCacheProvider).clearUserCache();
                if (context.mounted) {
                  Navigator.of(context).popUntil((Route<dynamic> r) => r.isFirst);
                }
              },
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Cerrar sesión'),
            ),
            if (profile.showsAds) ...[
              const SizedBox(height: 14),
              TaxiyaAdBannerWidget(
                localityId: profile.localityId ?? '',
                subscriptionTier: profile.subscriptionTier,
                role: TaxiyaRole.passenger,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
