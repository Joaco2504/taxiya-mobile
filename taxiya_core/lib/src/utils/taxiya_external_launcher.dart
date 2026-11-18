import 'package:url_launcher/url_launcher.dart';

import '../config/taxiya_env.dart';

/// Utilidades compartidas para abrir llamadas telefónicas y mensajes pre-cargados en WhatsApp.
abstract final class TaxiyaExternalLauncher {
  /// Limpia un número argentino para formato internacional `wa.me` (`549...`).
  static String sanitizeWhatsAppDigits(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return '';
    if (digits.startsWith('549')) return digits;
    if (digits.startsWith('54')) return '549${digits.substring(2)}';
    if (digits.startsWith('0')) return '549${digits.substring(1)}';
    return '549$digits';
  }

  static Future<bool> openPhoneDialer(String? phone) async {
    final raw = phone?.trim() ?? '';
    if (raw.isEmpty) return false;
    final clean = raw.replaceAll(RegExp(r'[^0-9+]'), '');
    if (clean.isEmpty) return false;
    final uri = Uri(scheme: 'tel', path: clean);
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  static Uri buildWhatsAppUri({
    String? phoneDigits,
    required String message,
  }) {
    final normalized = phoneDigits != null && phoneDigits.trim().isNotEmpty
        ? sanitizeWhatsAppDigits(phoneDigits)
        : '';
    final path = normalized.isNotEmpty ? '/$normalized' : '/';
    return Uri(
      scheme: 'https',
      host: 'wa.me',
      path: path,
      queryParameters: <String, String>{'text': message},
    );
  }

  static Future<bool> openWhatsAppSupport({
    required String userId,
    required String roleLabel,
    required String localityName,
  }) async {
    final message =
        'Hola TaxiYa Soporte. Necesito ayuda con mi cuenta.\n'
        'ID de usuario: $userId\n'
        'Rol: $roleLabel\n'
        'Localidad: $localityName';
    final uri = buildWhatsAppUri(
      phoneDigits: TaxiyaEnv.supportWhatsAppNumber,
      message: message,
    );
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  static Future<bool> shareTripOnWhatsApp({
    required String originAddress,
    String? destinationAddress,
    String? driverName,
    String? vehicleSummary,
    String? plateLabel,
    String? permitLabel,
  }) async {
    final lines = <String>[
      'Comparto mi viaje en TaxiYa:',
      'Salida: $originAddress',
      if (destinationAddress != null && destinationAddress.trim().isNotEmpty)
        'Destino: ${destinationAddress.trim()}',
      if (driverName != null && driverName.trim().isNotEmpty)
        'Chofer: ${driverName.trim()}',
      if (vehicleSummary != null && vehicleSummary.trim().isNotEmpty)
        'Vehículo: ${vehicleSummary.trim()}',
      if (plateLabel != null && plateLabel.trim().isNotEmpty)
        'Patente: ${plateLabel.trim()}',
      if (permitLabel != null && permitLabel.trim().isNotEmpty)
        'Habilitación: ${permitLabel.trim()}',
    ];
    final uri = buildWhatsAppUri(message: lines.join('\n'));
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
