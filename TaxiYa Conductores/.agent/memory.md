Guarda y consulta la identidad de la empresa TaxiYa, su arquitectura técnica, reglas de negocio, localidades operativas (Belén y Andalgalá), flotas, paleta de colores y decisiones clave del proyecto. Activar siempre que se diseñe, programe, tome decisiones de producto o se inicie una nueva sesión sobre TaxiYa.

Instructions
Memory - Identidad y Arquitectura de TaxiYa
Este documento es la memoria viva del proyecto TaxiYa. Se actualiza cada vez que se incorpora una nueva localidad, regla de negocio, empresa privada o cambio técnico.

1. Identidad de la Empresa y Alcance
Nombre oficial: TaxiYa
Propósito: Plataforma de despacho y conexión entre pasajeros y taxis habilitados en localidades del interior, sin intermediación financiera en el cobro de viajes.
Localidades activas iniciales (esquema `taxiya.localities`):
- Belén (Catamarca, Argentina — `locality_id = 6d4de2a8-9e44-45f0-a1ac-5ac12a2a087d`): Opera con 2 empresas privadas de taxis + taxis independientes. Todos con habilitación municipal obligatoria.
- Andalgalá (Catamarca, Argentina — `locality_id = dd97e662-feff-42db-a84a-bf3752e9e714`): Opera únicamente con taxis independientes con habilitación municipal obligatoria.
Escalabilidad: Arquitectura multi-zona preparada para sumar nuevas localidades y flotas sin modificar el código base.

2. Reglas de Negocio Inamovibles
Sin cálculo de tarifas: La plataforma nunca estima ni muestra precios de viaje. El cobro se rige por reloj taxímetro físico o acuerdo directo según ordenanza municipal.
Sin pasarela de pagos por viaje: No se procesan tarjetas, transferencias ni billeteras virtuales para pagar traslados.
Sin comisiones por viaje: No se descuenta porcentaje sobre los recorridos completados.
Monetización directa:
- Suscripciones mensuales vía RevenueCat + Google Play Billing (y a futuro Apple App Store): Plan Gratuito ($0 USD con publicidad), Plan Sin Publicidad ($2 USD/mes) y Plan Premium ($3 USD/mes).
- Publicidad local en banners dentro de la app para usuarios gratuitos: $3 USD/mes por comercio local con redirección a WhatsApp o sitio web/red social. Si no hay anunciantes locales activos, se muestra publicidad aleatoria de respaldo (AdMob o banners internos de TaxiYa).

3. Ecosistema, Stack Técnico y Entorno Verificado (Costo inicial $0)
Repositorios en GitHub:
- `taxiya-mobile` (Monorepo Flutter / Dart 3 con `taxiya_core`, `TaxiYa Conductores` y `TaxiYa Pasajeros`).
- `taxiya-admin` (Panel Web en `Taxi_ya/Panel Web` con Next.js App Router, TypeScript, Tailwind CSS y shadcn/ui, desplegado en Vercel).
Backend y Base de Datos: Supabase (`jblsngzlpstojzwsdchb`, PostgreSQL + PostGIS + Auth + Realtime + Storage).
- Esquema oficial: `taxiya`.
- Buckets de Storage: `taxiya_public` (avatares, fotos de autos, banners) y `taxiya_private` (selfies de validación, carnets de conducir, habilitaciones municipales).
- Esquema real de tablas Fase 4 verificado:
  * `trips`: `id, passenger_id, driver_id, locality_id, status (searching, requested, accepted, arriving, in_door, in_progress, waiting, waiting_return, completed, cancelled), origin_address, origin_point, dest_address, dest_point, is_round_trip, wait_minutes, scheduled_for, cancel_reason, cancelled_by, accepted_at, started_at, completed_at, created_at` (sin `updated_at`, `arrived_at`, `return_trip_id` ni `parent_trip_id`).
  * `trip_messages`: `id, trip_id, sender_id, message, created_at`.
  * `ratings`: `id, trip_id, passenger_id, driver_id, stars, comment, created_at`.
  * `driver_badges`: `id, driver_id, badge_code, awarded_at, expires_at`.
  * `support_tickets`: `id, user_id, trip_id, locality_id, category, description, is_emergency, status (open, in_review, in_progress, resolved, closed), created_at` (las coordenadas de emergencia se registran dentro de `description`).
Mapas y Geolocalización: Mapbox GL (`mapbox_maps_flutter` y `react-map-gl`). Token y constantes móviles inyectadas con `--dart-define-from-file=../env.local.json`.
Notificaciones Push y Alertas Locales: Firebase Cloud Messaging (`taxiya-catamarca`), `flutter_local_notifications` (`22.0.0` en móvil por compatibilidad con AGP `8.11.1`) y `audioplayers` (`6.8.1`).
Configuración Android verificada:
- Paquetes: `ar.com.taxiya.pasajeros` y `ar.com.taxiya.conductores`.
- Tooling Android: Gradle `8.14`, AGP `8.11.1`, Kotlin `2.2.20`, `JavaVersion.VERSION_17`.
- Iconos oficiales y avatares: `TaxiYa Conductores/assets/icon/TaxiYa_Conductores.png`, `TaxiYa Pasajeros/assets/icon/TaxiYa_Pasajeros.png` y 24 avatares PNG (`conductor_masc_1..8`, `conductor_fem_1..4`, `pasajero_masc_1..6`, `pasajero_fem_1..6`) en `taxiya_core/assets/avatars/`.
- Favicon Web oficial: `Panel Web/src/app/icon.png` y `Panel Web/src/app/apple-icon.png` (copiados de `public/brand/TaxiYa_admin_favicon.png`) + respaldo `?v=2` en `src/app/layout.tsx`.
Cuentas de prueba QA en Belén: `chofer@taxiya.com` y `pasajero@taxiya.com` (contraseña `TaxiYa2026!`).
Persistencia Offline: `hive_flutter` para operar en zonas periféricas con cortes de señal 4G (perfil, legajo, GPS pendiente, último viaje, cola de actualizaciones de viaje, horas en línea e insignias).

4. Identidad Visual (Paleta de Colores)
Modo Claro (Daylight Mode):
- Fondo principal: #F8FAFC
- Superficies / Tarjetas: #FFFFFF (borde #E2E8F0)
- Color primario: #F59E0B (texto sobre primario #0F172A)
- Color secundario: #0284C7
- Texto principal: #0F172A | Texto secundario: #475569
- Estados: Éxito #16A34A | Alerta #EA580C | Error #DC2626
Modo Oscuro (Night Shift Mode):
- Fondo principal: #0B0F19
- Superficies / Tarjetas: #151C2C (borde #263147)
- Color primario: #FBBF24 (texto sobre primario #0B0F19)
- Color secundario: #38BDF8
- Texto principal: #F1F5F9 | Texto secundario: #94A3B8
- Estados: Éxito #22C55E | Alerta #FB923C | Error #F87171

5. Funcionalidades Diferenciales por Fase (Fases 1 a 4 Implementadas)
- Prevención de fallos tipo Uber: Interpolación GPS cada 3 segundos (marcador gris tras 15s sin señal), seguimiento inteligente de cámara (`_followUserLocation` con botón "Mi ubicación"), liberación automática de viaje a los 4 minutos si el taxi no se acerca al origen (con alerta sonora a los 3 minutos), y confirmación visual de pin cuando el margen de error GPS supera los 20 metros.
- Puntos de referencia: Destinos personales privados (sin aprobación) y puntos públicos colaborativos (moderados desde Panel Web `/puntos`).
- Motor de viajes y casos especiales (Fase 4): Pedido instantáneo (`searching`), repetir último viaje en un toque, reserva programada (`scheduled_for`, activa aviso/despacho 30 minutos antes), viaje ida y vuelta con espera inteligente (`wait_minutes` con umbral de 10 minutos: `<=10m` pasa a `waiting_return`, `>10m` el chofer elige esperar o liberar y el pasajero recibe el botón flotante "Ya estoy listo para volver" con prioridad), aviso al llegar a menos de 100 metros / en puerta, y cola offline en Hive.
- Chat y seguridad en viaje (Fase 4): Mensajería en tiempo real (`taxiya.trip_messages`) con respuestas rápidas locales, llamada telefónica directa (`tel:`), bloqueo automático de envío a los 15 minutos de finalizado/cancelado el viaje, compartir viaje por WhatsApp y botón de pánico que crea `support_tickets` (`is_emergency = true`) reflejado al instante en el banner y mapa del Panel Web y en `/soporte`.
- Gamificación local (Fase 4): Pantalla de Rendimiento en `TaxiYa Conductores` filtrable por Día, Semana y Mes; métricas de viajes completados, horas conectado, calificación promedio y viajes en Turno Nocturno (`00:00 a 06:00` o `12:00 AM a 06:00 AM` según reloj del teléfono); insignias (`punctual`, `local_fav`, `impeccable`, `night_shift`, `veteran`) y recompensas activas (ventaja de 5 segundos al recibir pedidos y borde dorado en la tarjeta del pasajero).
- Legajo, privacidad, soporte y ayuda (Fases 3 y 4): Carga de foto del auto (frontal o lateral), selector modal de marcas/modelos argentinos, DNI y N° de móvil municipal opcional, privacidad de patente/habilitación, sección "Ayuda y guía de uso" en 4 tarjetas + FAQ + WhatsApp + formulario de tickets conectado con `/soporte` en `Panel Web`.

6. Protocolo de Actualización
Cuando el usuario pida agregar una localidad, modificar tarifas de suscripción, cambiar reglas de negocio o sumar un módulo, actualizar esta memoria manteniendo la estructura limpia y concreta.
