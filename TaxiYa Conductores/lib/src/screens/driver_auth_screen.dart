import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:taxiya_core/taxiya_core.dart';

/// Pantalla de ingreso y registro para choferes de TaxiYa.
class DriverAuthScreen extends ConsumerStatefulWidget {
  const DriverAuthScreen({super.key});

  @override
  ConsumerState<DriverAuthScreen> createState() => _DriverAuthScreenState();
}

class _DriverAuthScreenState extends ConsumerState<DriverAuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _isRegister = false;
  bool _obscurePassword = true;
  bool _loading = false;
  String? _selectedLocalityId;
  String? _feedbackMessage;
  bool _isErrorFeedback = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit(List<Locality> localities) async {
    if (!_formKey.currentState!.validate()) return;
    if (_isRegister && _selectedLocalityId == null && localities.isNotEmpty) {
      setState(() {
        _isErrorFeedback = true;
        _feedbackMessage = 'Elegí en qué localidad vas a trabajar.';
      });
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _feedbackMessage = null;
    });

    final client = ref.read(supabaseClientProvider);
    final repo = ref.read(taxiyaRepositoryProvider);
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;

    try {
      if (_isRegister) {
        final localityId = _selectedLocalityId ?? localities.firstOrNull?.id;
        final res = await client.auth.signUp(
          email: email,
          password: password,
          data: <String, dynamic>{
            'role': 'driver',
            'full_name': _nameCtrl.text.trim(),
            'phone': _phoneCtrl.text.trim(),
            'locality_id': ?localityId,
          },
        );

        final user = res.user;
        if (res.session != null && user != null) {
          await repo.upsertProfile(
            userId: user.id,
            role: TaxiyaRole.driver,
            fullName: _nameCtrl.text.trim(),
            phone: _phoneCtrl.text.trim(),
            email: email,
            localityId: localityId,
            avatarUrl: TaxiyaAvatars.driverCatalog.first.storageUri,
            accountStatus: TaxiyaAccountStatus.pending,
          );
        } else if (mounted) {
          setState(() {
            _isErrorFeedback = false;
            _feedbackMessage =
                'Te enviamos un correo para confirmar tu cuenta. Revisalo y volvé a ingresar.';
            _isRegister = false;
          });
        }
      } else {
        final res = await client.auth.signInWithPassword(
          email: email,
          password: password,
        );
        final user = res.user;
        if (user != null) {
          final existing = await repo.fetchProfile(user.id);
          if (existing == null) {
            final localityId =
                _selectedLocalityId ??
                (localities.isNotEmpty ? localities.first.id : null);
            await repo.upsertProfile(
              userId: user.id,
              role: TaxiyaRole.driver,
              fullName:
                  (user.userMetadata?['full_name'] as String?) ?? 'Chofer',
              phone: user.userMetadata?['phone'] as String?,
              email: user.email ?? email,
              localityId:
                  (user.userMetadata?['locality_id'] as String?) ?? localityId,
              avatarUrl: TaxiyaAvatars.driverCatalog.first.storageUri,
              accountStatus: TaxiyaAccountStatus.pending,
            );
          } else if (existing.role != TaxiyaRole.driver) {
            await client.auth.signOut();
            await ref.read(hiveCacheProvider).clearUserCache();
            if (mounted) {
              setState(() {
                _isErrorFeedback = true;
                _feedbackMessage =
                    'Esta cuenta no corresponde al perfil de chofer.';
              });
            }
          }
        }
      }
    } on AuthException catch (e) {
      if (mounted) {
        setState(() {
          _isErrorFeedback = true;
          _feedbackMessage = _mapAuthError(e.message);
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isErrorFeedback = true;
          _feedbackMessage =
              'No pudimos conectarnos. Revisá tu señal e intentá de nuevo.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  String _mapAuthError(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('invalid login credentials')) {
      return 'Correo o contraseña incorrectos. Revisalos e intentá de nuevo.';
    }
    if (lower.contains('already registered') ||
        lower.contains('user already exists')) {
      return 'Ya existe una cuenta registrada con ese correo.';
    }
    if (lower.contains('email not confirmed')) {
      return 'Todavía falta confirmar tu correo electrónico.';
    }
    return 'No pudimos completar el ingreso. Intentá en unos segundos.';
  }

  @override
  Widget build(BuildContext context) {
    final localitiesAsync = ref.watch(localitiesProvider);
    final localities = localitiesAsync.value ?? const <Locality>[];
    final colors = context.taxiyaColors;
    final scheme = Theme.of(context).colorScheme;

    if (_selectedLocalityId == null && localities.isNotEmpty) {
      _selectedLocalityId = localities.first.id;
    }

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: colors.border),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            color: scheme.primary,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            Icons.local_taxi_rounded,
                            color: scheme.onPrimary,
                            size: 30,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'TaxiYa Conductores',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Belén y Andalgalá, Catamarca',
                                style: TextStyle(color: colors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment<bool>(
                        value: false,
                        label: Text('Ya tengo cuenta'),
                      ),
                      ButtonSegment<bool>(
                        value: true,
                        label: Text('Registrarme'),
                      ),
                    ],
                    selected: <bool>{_isRegister},
                    onSelectionChanged: _loading
                        ? null
                        : (Set<bool> selection) {
                            setState(() {
                              _isRegister = selection.first;
                              _feedbackMessage = null;
                            });
                          },
                  ),
                  const SizedBox(height: 18),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              _isRegister
                                  ? 'Creá tu cuenta de chofer'
                                  : 'Ingresá con tu correo',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 16),
                            if (_isRegister) ...[
                              TextFormField(
                                controller: _nameCtrl,
                                textCapitalization: TextCapitalization.words,
                                decoration: const InputDecoration(
                                  labelText: 'Nombre y apellido',
                                  hintText: 'Ej: Carlos Mendoza',
                                  prefixIcon: Icon(Icons.person_outline_rounded),
                                ),
                                validator: (String? v) {
                                  if (v == null || v.trim().length < 3) {
                                    return 'Ingresá tu nombre y apellido completo.';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _phoneCtrl,
                                keyboardType: TextInputType.phone,
                                decoration: const InputDecoration(
                                  labelText: 'Celular',
                                  hintText: '+54 9 3835 412345',
                                  helperText:
                                      'Ingresá con código de área, sin 0 ni 15.',
                                  prefixIcon: Icon(Icons.phone_android_rounded),
                                ),
                                validator: (String? v) {
                                  if (v == null || v.trim().length < 8) {
                                    return 'Ingresá un número de celular válido.';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 14),
                              if (localities.isNotEmpty)
                                TaxiyaSelectorField<String>(
                                  label: 'Localidad donde trabajás',
                                  sheetTitle: 'Elegí tu localidad',
                                  prefixIcon: Icons.location_city_rounded,
                                  value: _selectedLocalityId,
                                  options: localities
                                      .map(
                                        (Locality l) =>
                                            TaxiyaSelectorOption<String>(
                                              value: l.id,
                                              label: l.name,
                                              subtitle: l.province,
                                            ),
                                      )
                                      .toList(),
                                  onChanged: (String? val) {
                                    setState(() => _selectedLocalityId = val);
                                  },
                                )
                              else if (localitiesAsync.isLoading)
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 8),
                                  child: LinearProgressIndicator(),
                                ),
                              const SizedBox(height: 14),
                            ],
                            TextFormField(
                              controller: _emailCtrl,
                              keyboardType: TextInputType.emailAddress,
                              autocorrect: false,
                              decoration: const InputDecoration(
                                labelText: 'Correo electrónico',
                                hintText: 'chofer@ejemplo.com',
                                prefixIcon: Icon(Icons.email_outlined),
                              ),
                              validator: (String? v) {
                                if (v == null || !v.contains('@')) {
                                  return 'Ingresá un correo electrónico válido.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _passwordCtrl,
                              obscureText: _obscurePassword,
                              decoration: InputDecoration(
                                labelText: 'Contraseña',
                                prefixIcon: const Icon(Icons.lock_outline_rounded),
                                suffixIcon: IconButton(
                                  onPressed: () {
                                    setState(
                                      () => _obscurePassword = !_obscurePassword,
                                    );
                                  },
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                  ),
                                ),
                              ),
                              validator: (String? v) {
                                if (v == null || v.length < 6) {
                                  return 'La contraseña debe tener al menos 6 caracteres.';
                                }
                                return null;
                              },
                            ),
                            if (_feedbackMessage != null) ...[
                              const SizedBox(height: 14),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: (_isErrorFeedback
                                          ? colors.error
                                          : colors.success)
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: _isErrorFeedback
                                        ? colors.error
                                        : colors.success,
                                  ),
                                ),
                                child: Text(
                                  _feedbackMessage!,
                                  style: TextStyle(
                                    color: _isErrorFeedback
                                        ? colors.error
                                        : colors.success,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 18),
                            FilledButton(
                              onPressed:
                                  _loading ? null : () => _submit(localities),
                              child: _loading
                                  ? const SizedBox(
                                      height: 22,
                                      width: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                      ),
                                    )
                                  : Text(
                                      _isRegister
                                          ? 'Crear cuenta y cargar legajo'
                                          : 'Ingresar',
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
