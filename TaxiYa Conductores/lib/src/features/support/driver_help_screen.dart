import 'package:flutter/material.dart';
import 'package:taxiya_core/taxiya_core.dart';

/// Abre "Ayuda y guía de uso" con tarjetas y preguntas pensadas para el taxista.
Future<void> openDriverHelpScreen({
  required BuildContext context,
  required Profile profile,
  required String localityName,
  String? activeTripId,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => TaxiyaHelpGuideScreen(
        profile: profile,
        roleLabel: 'Chofer',
        localityName: localityName,
        activeTripId: activeTripId,
        guideCards: const <TaxiyaHelpGuideCardData>[
          TaxiyaHelpGuideCardData(
            stepLabel: 'Paso 1',
            title: 'Conectate con GPS en vivo',
            description:
                'Tocá En línea para compartir tu móvil cada 3 segundos. Si falla el 4G, se respalda en Hive.',
            icon: Icons.power_settings_new_rounded,
          ),
          TaxiyaHelpGuideCardData(
            stepLabel: 'Paso 2',
            title: 'Tomá pedidos con un toque',
            description:
                'Los viajes cercanos suenan y aparecen en pantalla. El primero que acepta toma el traslado.',
            icon: Icons.notifications_active_rounded,
          ),
          TaxiyaHelpGuideCardData(
            stepLabel: 'Paso 3',
            title: 'Marcá cada etapa y esperas',
            description:
                'Usá el botón principal grande con una sola mano: En camino, En la puerta, En curso y Fin.',
            icon: Icons.touch_app_rounded,
          ),
          TaxiyaHelpGuideCardData(
            stepLabel: 'Paso 4',
            title: 'Sumá insignias y 0% comisión',
            description:
                'Cobrás directo al pasajero sin comisiones. Con puntualidad y Turno Nocturno ganás prioridad.',
            icon: Icons.workspace_premium_rounded,
          ),
        ],
        faqItems: const <TaxiyaFaqItemData>[
          TaxiyaFaqItemData(
            question: '¿TaxiYa descuenta comisiones por viaje?',
            answer:
                'No. TaxiYa nunca descuenta porcentaje por tus viajes ni fija tarifas. Trabajás con reloj taxímetro o tarifa habilitada local.',
          ),
          TaxiyaFaqItemData(
            question: '¿Qué pasa si acepto un viaje y no avanzo hacia el origen?',
            answer:
                'A los 3 minutos sin acercarte suena un aviso preventivo y a los 4 minutos el pedido se libera automáticamente para otro móvil.',
          ),
          TaxiyaFaqItemData(
            question: '¿Cómo funciona la espera en viajes de ida y vuelta?',
            answer:
                'Si la espera pedida es de 5 o 10 minutos, marcás En espera hasta emprender el regreso. Si supera los 10 minutos, elegís en pantalla si esperás o liberás el viaje para seguir trabajando.',
          ),
          TaxiyaFaqItemData(
            question: '¿Qué beneficios dan las insignias y el Turno Nocturno?',
            answer:
                'Manteniendo buen puntaje, racha sin cancelaciones y viajes nocturnos (00:00 a 06:00), obtenés prioridad de 5 segundos al recibir pedidos, borde dorado en tu tarjeta y estadísticas de demanda.',
          ),
        ],
        ticketCategories: const <String>[
          'Problema con un pasajero',
          'Falla de GPS o mapa',
          'Renovación de habilitación',
          'Insignias y rendimiento',
          'Suscripción / publicidad',
          'Otro reclamo',
        ],
      ),
    ),
  );
}
