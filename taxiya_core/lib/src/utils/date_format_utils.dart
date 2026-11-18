import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

/// Utilidades de formato argentino y detección de formato horario para Turno Nocturno.
abstract final class TaxiyaDateUtils {
  static String formatDateAr(DateTime? date) {
    if (date == null) return 'Sin fecha';
    return DateFormat('dd/MM/yyyy').format(date.toLocal());
  }

  static String formatTime(BuildContext context, DateTime date) {
    final local = date.toLocal();
    final use24h = MediaQuery.alwaysUse24HourFormatOf(context);
    if (use24h) {
      return '${DateFormat('HH:mm').format(local)} hs';
    }
    return DateFormat('hh:mm a').format(local);
  }

  /// Indica si la hora actual corresponde al Turno Nocturno (00:00 a 06:00).
  static bool isNightShift([DateTime? now]) {
    final current = (now ?? DateTime.now()).toLocal();
    return current.hour >= 0 && current.hour < 6;
  }

  /// Texto del horario del Turno Nocturno adaptado automáticamente al reloj del teléfono.
  static String nightShiftRangeLabel(BuildContext context) {
    final use24h = MediaQuery.alwaysUse24HourFormatOf(context);
    return use24h ? '00:00 a 06:00 hs' : '12:00 AM a 06:00 AM';
  }

  static String formatDateTimeAr(BuildContext context, DateTime? date) {
    if (date == null) return 'Sin fecha';
    return '${formatDateAr(date)} ${formatTime(context, date)}';
  }

  static String secondsSinceLabel(DateTime? timestamp) {
    if (timestamp == null) return 'Sin señal GPS';
    final diff = DateTime.now().difference(timestamp.toLocal());
    if (diff.inSeconds < 5) return 'Actualizado recién';
    if (diff.inSeconds < 60) return 'Hace ${diff.inSeconds} s';
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
    return 'Hace ${diff.inHours} h';
  }
}
