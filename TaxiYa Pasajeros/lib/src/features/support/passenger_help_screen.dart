import 'package:flutter/material.dart';
import 'package:taxiya_core/taxiya_core.dart';

/// Abre la pantalla "Ayuda y guía de uso" adaptada al rol Pasajero.
Future<void> openPassengerHelpScreen({
  required BuildContext context,
  required Profile profile,
  required String localityName,
  String? activeTripId,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => TaxiyaHelpGuideScreen(
        profile: profile,
        roleLabel: 'Pasajero',
        localityName: localityName,
        activeTripId: activeTripId,
        guideCards: const <TaxiyaHelpGuideCardData>[
          TaxiyaHelpGuideCardData(
            stepLabel: 'Paso 1',
            title: 'Elegí salida y destino',
            description:
                'Podés usar tu GPS, tocar un pin directo en el mapa o elegir lugares guardados.',
            icon: Icons.place_rounded,
          ),
          TaxiyaHelpGuideCardData(
            stepLabel: 'Paso 2',
            title: 'Viajes a tu medida',
            description:
                'Pedí al instante, repetí tu último viaje, reservá con anticipación o marcá ida y vuelta.',
            icon: Icons.repeat_rounded,
          ),
          TaxiyaHelpGuideCardData(
            stepLabel: 'Paso 3',
            title: 'Seguí al móvil en vivo',
            description:
                'Ves el chofer asignado, foto del auto, chat directo y aviso cuando llega a la puerta.',
            icon: Icons.directions_car_filled_rounded,
          ),
          TaxiyaHelpGuideCardData(
            stepLabel: 'Paso 4',
            title: 'Pago directo al chofer',
            description:
                'TaxiYa no calcula precios ni cobra comisiones: abonás al taxista según reloj o acuerdo.',
            icon: Icons.payments_outlined,
          ),
        ],
        faqItems: const <TaxiyaFaqItemData>[
          TaxiyaFaqItemData(
            question: '¿Por qué la app no muestra el precio del viaje?',
            answer:
                'TaxiYa conecta pasajeros con taxis habilitados sin cobrar comisiones ni fijar tarifas. El viaje se cobra con reloj taxímetro o acuerdo directo según la ordenanza local.',
          ),
          TaxiyaFaqItemData(
            question: '¿Cómo recupero un objeto olvidado en el taxi?',
            answer:
                'Podés escribirle o llamar al chofer desde el chat del viaje durante los primeros 15 minutos después de bajar. Pasado ese plazo, enviá un reclamo desde acá abajo o escribí a Soporte por WhatsApp.',
          ),
          TaxiyaFaqItemData(
            question: '¿Qué pasa si pido ida y vuelta con mucha espera?',
            answer:
                'Si elegís 5 o 10 minutos de espera, el móvil se queda aguardándote. Si elegís 15 o 30 minutos, el chofer decide si espera o libera el auto y vos conservás el botón "Ya estoy listo para volver".',
          ),
          TaxiyaFaqItemData(
            question: '¿Qué incluyen los planes pagos para pasajeros?',
            answer:
                'El Plan Gratuito (\$ 0) incluye avisos de comercios locales. Podés optar por Sin publicidad (\$ 2 USD/mes) o Premium (\$ 3 USD/mes). No son obligatorios para viajar.',
          ),
        ],
        ticketCategories: const <String>[
          'Objeto olvidado en el taxi',
          'Problema con un viaje',
          'Demora o cancelación',
          'Error en ubicación o mapa',
          'Consulta sobre cuenta o plan',
          'Otro reclamo',
        ],
      ),
    ),
  );
}
