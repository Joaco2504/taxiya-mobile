import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:taxiya_core/taxiya_core.dart';

import '../services/image_upload_helper.dart';

/// Wizard de registro de modalidad, vehículo y legajo digital para choferes.
class DriverOnboardingScreen extends ConsumerStatefulWidget {
  const DriverOnboardingScreen({
    super.key,
    required this.profile,
    this.existingDetails,
    this.onCompleted,
  });

  final Profile profile;
  final DriverDetails? existingDetails;
  final VoidCallback? onCompleted;

  @override
  ConsumerState<DriverOnboardingScreen> createState() =>
      _DriverOnboardingScreenState();
}

class _DriverOnboardingScreenState
    extends ConsumerState<DriverOnboardingScreen> {
  final _vehicleFormKey = GlobalKey<FormState>();

  int _step = 0;
  bool _submitting = false;
  String? _errorText;

  // Paso 1: Localidad y modalidad
  String? _localityId;
  String? _selectedCompanyId; // null = Taxista independiente

  // Paso 2: Titular y vehículo
  String _selectedBrand = ArgentinaVehicles.modelsByBrand.keys.first;
  String _selectedModel = ArgentinaVehicles.modelsByBrand.values.first.first;
  String _selectedColor = ArgentinaVehicles.commonColors.first;
  String _selectedType = ArgentinaVehicles.vehicleTypes.first;
  final _dniCtrl = TextEditingController();
  final _customBrandCtrl = TextEditingController();
  final _customModelCtrl = TextEditingController();
  final _customColorCtrl = TextEditingController();
  final _plateCtrl = TextEditingController();
  final _mobileUnitCtrl = TextEditingController();
  DateTime? _permitExpiryDate;

  // Paso 3: Documentos (bytes nuevos o URL/path existente)
  Uint8List? _selfieBytes;
  Uint8List? _licenseFrontBytes;
  Uint8List? _licenseBackBytes;
  Uint8List? _permitBytes;
  Uint8List? _carPhotoBytes;

  @override
  void initState() {
    super.initState();
    final d = widget.existingDetails;
    _localityId = widget.profile.localityId;
    _selectedCompanyId = d?.companyId;

    if (d != null) {
      _dniCtrl.text = d.dni ?? '';
      _plateCtrl.text = d.plateNumber ?? '';
      _permitExpiryDate = d.permitExpiryDate;
      if (d.carBrand != null &&
          ArgentinaVehicles.modelsByBrand.containsKey(d.carBrand)) {
        _selectedBrand = d.carBrand!;
        final models = ArgentinaVehicles.modelsByBrand[_selectedBrand]!;
        if (d.carModel != null && models.contains(d.carModel)) {
          _selectedModel = d.carModel!;
        } else {
          _selectedModel = ArgentinaVehicles.customOption;
          _customModelCtrl.text = d.carModel ?? '';
        }
      } else if (d.carBrand != null && d.carBrand!.isNotEmpty) {
        _selectedBrand = ArgentinaVehicles.customOption;
        _customBrandCtrl.text = d.carBrand!;
        _selectedModel = ArgentinaVehicles.customOption;
        _customModelCtrl.text = d.carModel ?? '';
      }

      if (d.carColor != null &&
          ArgentinaVehicles.commonColors.contains(d.carColor)) {
        _selectedColor = d.carColor!;
      } else if (d.carColor != null && d.carColor!.isNotEmpty) {
        _selectedColor = 'Otro';
        _customColorCtrl.text = d.carColor!;
      }

      if (d.carType != null &&
          ArgentinaVehicles.vehicleTypes.contains(d.carType)) {
        _selectedType = d.carType!;
      } else if (d.carType?.toLowerCase() == 'sedan') {
        _selectedType = ArgentinaVehicles.vehicleTypes.first;
      }
    }

    _mobileUnitCtrl.text =
        widget.existingDetails?.municipalMobileNum ??
        ref.read(hiveCacheProvider).driverMobileUnit ??
        '';
  }

  @override
  void dispose() {
    _dniCtrl.dispose();
    _customBrandCtrl.dispose();
    _customModelCtrl.dispose();
    _customColorCtrl.dispose();
    _plateCtrl.dispose();
    _mobileUnitCtrl.dispose();
    super.dispose();
  }

  bool _isBelen(List<Locality> localities) {
    for (final l in localities) {
      if (l.id == _localityId) {
        return l.name.toLowerCase().contains('bel');
      }
    }
    return false;
  }

  Future<void> _pickPermitDate() async {
    final now = DateTime.now();
    final initial = _permitExpiryDate ?? now.add(const Duration(days: 180));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(now) ? now : initial,
      firstDate: now.subtract(const Duration(days: 30)),
      lastDate: now.add(const Duration(days: 365 * 6)),
      helpText: 'Vencimiento de habilitación',
    );
    if (picked != null) {
      setState(() => _permitExpiryDate = picked);
    }
  }

  Future<void> _pickDocImage(String docKey) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (BuildContext ctx) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_rounded),
                title: const Text('Sacar foto con la cámara'),
                onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded),
                title: const Text('Elegir desde la galería'),
                onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
              ),
            ],
          ),
        );
      },
    );
    if (source == null) return;

    final bytes = await DriverImageHelper.pickAndCompress(source);
    if (bytes == null || !mounted) return;

    setState(() {
      switch (docKey) {
        case 'selfie':
          _selfieBytes = bytes;
        case 'license_front':
          _licenseFrontBytes = bytes;
        case 'license_back':
          _licenseBackBytes = bytes;
        case 'municipal_permit':
          _permitBytes = bytes;
        case 'car_photo':
          _carPhotoBytes = bytes;
      }
    });
  }

  bool _hasAllRequiredDocs() {
    final d = widget.existingDetails;
    final hasSelfie =
        _selfieBytes != null || (d?.selfieUrl?.isNotEmpty ?? false);
    final hasFront =
        _licenseFrontBytes != null ||
        (d?.licenseFrontUrl?.isNotEmpty ?? false);
    final hasBack =
        _licenseBackBytes != null || (d?.licenseBackUrl?.isNotEmpty ?? false);
    final hasPermit =
        _permitBytes != null || (d?.municipalPermitUrl?.isNotEmpty ?? false);
    final hasCar =
        _carPhotoBytes != null || (d?.carPhotoUrl?.isNotEmpty ?? false);
    return hasSelfie && hasFront && hasBack && hasPermit && hasCar;
  }

  Future<void> _submitAll(List<Locality> localities) async {
    if (!_hasAllRequiredDocs()) {
      setState(() {
        _errorText =
            'Subí las 5 fotos requeridas para enviar tu legajo a revisión.';
      });
      return;
    }

    setState(() {
      _submitting = true;
      _errorText = null;
    });

    final repo = ref.read(taxiyaRepositoryProvider);
    final cache = ref.read(hiveCacheProvider);
    final uid = widget.profile.id;
    final existing = widget.existingDetails;

    try {
      final selfiePath = _selfieBytes != null
          ? await repo.uploadPrivateImage(
              userId: uid,
              docKey: 'selfie',
              jpegBytes: _selfieBytes!,
            )
          : existing!.selfieUrl!;

      final licenseFrontPath = _licenseFrontBytes != null
          ? await repo.uploadPrivateImage(
              userId: uid,
              docKey: 'license_front',
              jpegBytes: _licenseFrontBytes!,
            )
          : existing!.licenseFrontUrl!;

      final licenseBackPath = _licenseBackBytes != null
          ? await repo.uploadPrivateImage(
              userId: uid,
              docKey: 'license_back',
              jpegBytes: _licenseBackBytes!,
            )
          : existing!.licenseBackUrl!;

      final permitPath = _permitBytes != null
          ? await repo.uploadPrivateImage(
              userId: uid,
              docKey: 'municipal_permit',
              jpegBytes: _permitBytes!,
            )
          : existing!.municipalPermitUrl!;

      final carPhotoUrl = _carPhotoBytes != null
          ? await repo.uploadPublicImage(
              userId: uid,
              folder: 'cars',
              jpegBytes: _carPhotoBytes!,
            )
          : existing!.carPhotoUrl!;

      final resolvedBrand = _selectedBrand == ArgentinaVehicles.customOption
          ? _customBrandCtrl.text.trim()
          : _selectedBrand;
      final resolvedModel = _selectedModel == ArgentinaVehicles.customOption
          ? _customModelCtrl.text.trim()
          : _selectedModel;
      final resolvedColor = _selectedColor == 'Otro'
          ? _customColorCtrl.text.trim()
          : _selectedColor;

      final isBelen = _isBelen(localities);
      final companyId = isBelen ? _selectedCompanyId : null;

      await cache.setDriverMobileUnit(_mobileUnitCtrl.text);

      await repo.updateProfileFields(uid, <String, dynamic>{
        'locality_id': ?_localityId,
        if (existing == null) 'account_status': TaxiyaAccountStatus.pending.name,
      });

      final expiryIso = _permitExpiryDate!
          .toIso8601String()
          .split('T')
          .first;

      final cleanDni = _dniCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
      final cleanMobileNum = _mobileUnitCtrl.text.trim();

      await repo.upsertDriverDetails(<String, dynamic>{
        'user_id': uid,
        'company_id': companyId,
        'dni': cleanDni,
        'municipal_mobile_num': cleanMobileNum.isEmpty ? null : cleanMobileNum,
        'car_brand': resolvedBrand,
        'car_model': resolvedModel,
        'car_color': resolvedColor,
        'car_type': _selectedType,
        'car_photo_url': carPhotoUrl,
        'plate_number': _plateCtrl.text.trim().toUpperCase(),
        'selfie_url': selfiePath,
        'license_front_url': licenseFrontPath,
        'license_back_url': licenseBackPath,
        'municipal_permit_url': permitPath,
        'permit_expiry_date': expiryIso,
      });

      if (mounted) {
        widget.onCompleted?.call();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorText =
              'No pudimos subir tu legajo. Revisá la conexión e intentá de nuevo.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  void _nextStep(List<Locality> localities) {
    setState(() => _errorText = null);
    if (_step == 0) {
      if (_localityId == null && localities.isNotEmpty) {
        _localityId = localities.first.id;
      }
      setState(() => _step = 1);
      return;
    }

    if (_step == 1) {
      if (!_vehicleFormKey.currentState!.validate()) return;
      if (_permitExpiryDate == null) {
        setState(() {
          _errorText = 'Elegí la fecha de vencimiento de tu habilitación.';
        });
        return;
      }
      setState(() => _step = 2);
    }
  }

  @override
  Widget build(BuildContext context) {
    final localities =
        ref.watch(localitiesProvider).value ?? const <Locality>[];
    final companies =
        ref.watch(taxiCompaniesProvider).value ?? const <TaxiCompany>[];
    final colors = context.taxiyaColors;
    final isBelen = _isBelen(localities);
    final belenCompanies = companies
        .where((TaxiCompany c) => c.localityId == _localityId)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Legajo de chofer'),
        actions: [
          if (widget.onCompleted == null)
            TextButton(
              onPressed: _submitting
                  ? null
                  : () async {
                      await ref.read(supabaseClientProvider).auth.signOut();
                      await ref.read(hiveCacheProvider).clearUserCache();
                    },
              child: const Text('Salir'),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LinearProgressIndicator(
                    value: (_step + 1) / 3,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    switch (_step) {
                      0 => 'Paso 1 de 3 · Localidad y modalidad',
                      1 => 'Paso 2 de 3 · Datos del vehículo',
                      _ => 'Paso 3 de 3 · Fotos del legajo',
                    },
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_step == 0)
                      _buildStepModality(localities, belenCompanies, isBelen),
                    if (_step == 1) _buildStepVehicle(),
                    if (_step == 2) _buildStepDocs(),
                    if (_errorText != null) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colors.error.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: colors.error),
                        ),
                        child: Text(
                          _errorText!,
                          style: TextStyle(
                            color: colors.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  if (_step > 0) ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _submitting
                            ? null
                            : () => setState(() => _step -= 1),
                        child: const Text('Volver'),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: _submitting
                          ? null
                          : () {
                              if (_step < 2) {
                                _nextStep(localities);
                              } else {
                                _submitAll(localities);
                              }
                            },
                      child: _submitting
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2.5),
                            )
                          : Text(
                              _step < 2
                                  ? 'Continuar'
                                  : 'Enviar legajo para aprobación',
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepModality(
    List<Locality> localities,
    List<TaxiCompany> belenCompanies,
    bool isBelen,
  ) {
    final colors = context.taxiyaColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (localities.isNotEmpty)
          TaxiyaSelectorField<String>(
            label: 'Localidad',
            sheetTitle: 'Elegí tu localidad',
            prefixIcon: Icons.location_city_rounded,
            value: _localityId ?? localities.first.id,
            options: localities
                .map(
                  (Locality l) => TaxiyaSelectorOption<String>(
                    value: l.id,
                    label: l.name,
                    subtitle: l.province,
                  ),
                )
                .toList(),
            onChanged: (String? val) {
              setState(() {
                _localityId = val;
                if (!_isBelen(localities)) {
                  _selectedCompanyId = null;
                }
              });
            },
          ),
        const SizedBox(height: 18),
        Text(
          'Modalidad de trabajo',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        if (!isBelen)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.person_pin_rounded, color: colors.success),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'En Andalgalá trabajás bajo modalidad Independiente, conectado directo con los pasajeros de tu localidad.',
                    ),
                  ),
                ],
              ),
            ),
          )
        else ...[
          RadioGroup<String?>(
            groupValue: _selectedCompanyId,
            onChanged: (String? val) {
              setState(() => _selectedCompanyId = val);
            },
            child: Column(
              children: [
                ...belenCompanies.map(
                  (TaxiCompany company) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Card(
                      child: RadioListTile<String?>(
                        value: company.id,
                        title: Text(
                          company.name,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: const Text('Empresa privada registrada'),
                        secondary: CircleAvatar(
                          backgroundColor: _parseHexColor(company.badgeColor),
                          radius: 14,
                        ),
                      ),
                    ),
                  ),
                ),
                const Card(
                  child: RadioListTile<String?>(
                    value: null,
                    title: Text(
                      'Taxista independiente',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text('Trabajás con habilitación propia sin base'),
                    secondary: Icon(Icons.local_taxi_rounded),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStepVehicle() {
    final brands = <String>[
      ...ArgentinaVehicles.modelsByBrand.keys,
      ArgentinaVehicles.customOption,
    ];
    final models = _selectedBrand == ArgentinaVehicles.customOption
        ? <String>[ArgentinaVehicles.customOption]
        : <String>[
            ...?ArgentinaVehicles.modelsByBrand[_selectedBrand],
            ArgentinaVehicles.customOption,
          ];

    return Form(
      key: _vehicleFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _dniCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.digitsOnly,
            ],
            decoration: const InputDecoration(
              labelText: 'DNI del titular',
              hintText: 'Ej: 30123456',
              helperText: 'Ingresalo sin puntos ni espacios.',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
            validator: (String? v) {
              final digits = (v ?? '').replaceAll(RegExp(r'[^0-9]'), '');
              if (digits.length < 7 || digits.length > 9) {
                return 'Ingresá un DNI válido (7 a 9 dígitos sin puntos).';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          TaxiyaSelectorField<String>(
            label: 'Marca del vehículo',
            sheetTitle: 'Elegí la marca del vehículo',
            prefixIcon: Icons.directions_car_rounded,
            value: _selectedBrand,
            options: brands
                .map(
                  (String b) =>
                      TaxiyaSelectorOption<String>(value: b, label: b),
                )
                .toList(),
            onChanged: (String? val) {
              if (val == null) return;
              setState(() {
                _selectedBrand = val;
                if (val == ArgentinaVehicles.customOption) {
                  _selectedModel = ArgentinaVehicles.customOption;
                } else {
                  _selectedModel = ArgentinaVehicles.modelsByBrand[val]!.first;
                }
              });
            },
          ),
          if (_selectedBrand == ArgentinaVehicles.customOption) ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: _customBrandCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Ingresá la marca manualmente',
                hintText: 'Ej: Nissan',
              ),
              validator: (String? v) =>
                  (v == null || v.trim().isEmpty) ? 'Indicá la marca.' : null,
            ),
          ],
          const SizedBox(height: 12),
          TaxiyaSelectorField<String>(
            label: 'Modelo',
            sheetTitle: 'Elegí el modelo',
            prefixIcon: Icons.local_taxi_rounded,
            value: models.contains(_selectedModel)
                ? _selectedModel
                : models.first,
            options: models
                .map(
                  (String m) =>
                      TaxiyaSelectorOption<String>(value: m, label: m),
                )
                .toList(),
            onChanged: (String? val) {
              if (val != null) setState(() => _selectedModel = val);
            },
          ),
          if (_selectedModel == ArgentinaVehicles.customOption ||
              _selectedBrand == ArgentinaVehicles.customOption) ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: _customModelCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Ingresá el modelo manualmente',
                hintText: 'Ej: Versa',
              ),
              validator: (String? v) =>
                  (v == null || v.trim().isEmpty) ? 'Indicá el modelo.' : null,
            ),
          ],
          const SizedBox(height: 12),
          TaxiyaSelectorField<String>(
            label: 'Color',
            sheetTitle: 'Elegí el color del auto',
            prefixIcon: Icons.palette_outlined,
            value: _selectedColor,
            options: ArgentinaVehicles.commonColors
                .map(
                  (String c) =>
                      TaxiyaSelectorOption<String>(value: c, label: c),
                )
                .toList(),
            onChanged: (String? val) {
              if (val != null) setState(() => _selectedColor = val);
            },
          ),
          if (_selectedColor == 'Otro') ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: _customColorCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Especificá el color',
              ),
              validator: (String? v) =>
                  (v == null || v.trim().isEmpty) ? 'Indicá el color.' : null,
            ),
          ],
          const SizedBox(height: 12),
          TaxiyaSelectorField<String>(
            label: 'Tipo de vehículo',
            sheetTitle: 'Elegí el tipo de vehículo',
            prefixIcon: Icons.commute_rounded,
            value: _selectedType,
            options: ArgentinaVehicles.vehicleTypes
                .map(
                  (String t) =>
                      TaxiyaSelectorOption<String>(value: t, label: t),
                )
                .toList(),
            onChanged: (String? val) {
              if (val != null) setState(() => _selectedType = val);
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _plateCtrl,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'Patente',
              hintText: 'Ej: AF 482 KL',
            ),
            validator: (String? v) {
              if (v == null || v.trim().length < 6) {
                return 'Ingresá una patente válida.';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _mobileUnitCtrl,
            keyboardType: TextInputType.text,
            decoration: const InputDecoration(
              labelText: 'Número de móvil (opcional)',
              hintText: 'Ej: Móvil 14',
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: _pickPermitDate,
            icon: const Icon(Icons.event_available_rounded),
            label: Text(
              _permitExpiryDate == null
                  ? 'Elegir vencimiento de habilitación municipal'
                  : 'Vencimiento: ${TaxiyaDateUtils.formatDateAr(_permitExpiryDate)}',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepDocs() {
    final d = widget.existingDetails;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DocCaptureCard(
          title: 'Selfie del chofer',
          subtitle: 'Foto de frente con buena luz (archivo privado)',
          bytes: _selfieBytes,
          alreadyUploaded: d?.selfieUrl?.isNotEmpty ?? false,
          onTap: () => _pickDocImage('selfie'),
        ),
        const SizedBox(height: 10),
        _DocCaptureCard(
          title: 'Carnet de conducir — Frente',
          subtitle: 'Foto legible de tus datos personales',
          bytes: _licenseFrontBytes,
          alreadyUploaded: d?.licenseFrontUrl?.isNotEmpty ?? false,
          onTap: () => _pickDocImage('license_front'),
        ),
        const SizedBox(height: 10),
        _DocCaptureCard(
          title: 'Carnet de conducir — Dorso',
          subtitle: 'Foto de categorías y vencimiento',
          bytes: _licenseBackBytes,
          alreadyUploaded: d?.licenseBackUrl?.isNotEmpty ?? false,
          onTap: () => _pickDocImage('license_back'),
        ),
        const SizedBox(height: 10),
        _DocCaptureCard(
          title: 'Habilitación municipal vigente',
          subtitle: 'Comprobante otorgado por el municipio',
          bytes: _permitBytes,
          alreadyUploaded: d?.municipalPermitUrl?.isNotEmpty ?? false,
          onTap: () => _pickDocImage('municipal_permit'),
        ),
        const SizedBox(height: 10),
        _DocCaptureCard(
          title: 'Foto del auto',
          subtitle: 'Vista frontal o lateral visible para el pasajero',
          bytes: _carPhotoBytes,
          alreadyUploaded: d?.carPhotoUrl?.isNotEmpty ?? false,
          onTap: () => _pickDocImage('car_photo'),
        ),
      ],
    );
  }

  Color _parseHexColor(String hex) {
    final clean = hex.replaceFirst('#', '');
    final value = int.tryParse(clean, radix: 16);
    if (value == null) return const Color(0xFF0284C7);
    return Color(clean.length <= 6 ? (0xFF000000 | value) : value);
  }
}

class _DocCaptureCard extends StatelessWidget {
  const _DocCaptureCard({
    required this.title,
    required this.subtitle,
    required this.bytes,
    required this.alreadyUploaded,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final Uint8List? bytes;
  final bool alreadyUploaded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.taxiyaColors;
    final ready = bytes != null || alreadyUploaded;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: ready
                      ? colors.success.withValues(alpha: 0.14)
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                clipBehavior: Clip.antiAlias,
                child: bytes != null
                    ? Image.memory(bytes!, fit: BoxFit.cover)
                    : Icon(
                        ready
                            ? Icons.check_circle_rounded
                            : Icons.add_a_photo_rounded,
                        color: ready ? colors.success : colors.textSecondary,
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      bytes != null
                          ? 'Foto comprimida lista'
                          : alreadyUploaded
                          ? 'Cargada (tocá para cambiar)'
                          : 'Tocá para sacar o subir foto',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: ready
                            ? colors.success
                            : Theme.of(context).colorScheme.secondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}
