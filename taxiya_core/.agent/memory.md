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
  * `driver_badges`: `id, driver_id, badge_code, level (1..6), awarded_at, expires_at`.
  * `badge_configs`: `id, locality_id, badge_code, thresholds (integer[6]), updated_at`.
  * `support_tickets`: `id, user_id, trip_id, locality_id, category, description, is_emergency, status (open, in_review, in_progress, resolved, closed), created_at` (las coordenadas de emergencia se registran dentro de `description`).
Mapas y Geolocalización: Mapbox GL (`mapbox_maps_flutter` sin `scaleBar`/`logo`/`attribution` en móvil, y `react-map-gl` con estilo `streets-v12` en Modo Claro y `dark-v11` en Modo Oscuro). Token y constantes móviles inyectadas con `--dart-define-from-file=../env.local.json`.
Notificaciones Push y Alertas Locales: Firebase Cloud Messaging (`taxiya-catamarca`), `flutter_local_notifications` (`22.0.0` en móvil por compatibilidad con AGP `8.11.1`) y `audioplayers` (`6.8.1`).
Configuración Android verificada:
- Paquetes: `ar.com.taxiya.pasajeros` y `ar.com.taxiya.conductores`.
- Tooling Android: Gradle `8.14`, AGP `8.11.1`, Kotlin `2.2.20`, `JavaVersion.VERSION_17`.
- Iconos oficiales, avatares y 30 insignias progresivas:
  * Lanzadores: `TaxiYa Conductores/assets/icon/TaxiYa_Conductores.png` y `TaxiYa Pasajeros/assets/icon/TaxiYa_Pasajeros.png`.
  * 24 avatares PNG en `taxiya_core/assets/avatars/` (`conductor_masc_1..8`, `conductor_fem_1..4`, `pasajero_masc_1..6`, `pasajero_fem_1..6`).
  * 30 insignias PNG (5 categorías × 6 niveles, con fallback vectorial automático si aún falta el PNG) en `taxiya_core/assets/badges/` (móvil) y `Panel Web/public/badges/` (web). Nomenclatura: `<prefijo>_<nivel>_<material>.png` (`puntual`, `favorito`, `impecable`, `nocturno`, `veterano` × `1_madera` .. `6_obsidiana`).
- Favicon Web oficial: `Panel Web/src/app/icon.png` y `Panel Web/src/app/apple-icon.png` (copiados de `public/brand/TaxiYa_admin_favicon.png`) + respaldo `?v=2` en `src/app/layout.tsx`.
Cuentas de prueba QA en Belén: `chofer@taxiya.com` y `pasajero@taxiya.com` (contraseña `TaxiYa2026!`).
Persistencia Offline: `hive_flutter` para operar en zonas periféricas con cortes de señal 4G (perfil, legajo, GPS pendiente, último viaje, cola de actualizaciones de viaje, horas en línea, metas `badge_configs` y niveles conocidos).

4. Identidad Visual (Paleta de Colores)
Modo Claro (Daylight Mode — contraste reforzado):
- Fondo principal: #F8FAFC
- Superficies / Tarjetas: #FFFFFF (borde #CBD5E1)
- Color primario: #F59E0B (texto sobre primario #0F172A)
- Color secundario: #0284C7
- Texto principal: #0F172A | Texto secundario: #334155
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
- Sistema de 30 Insignias Progresivas por Niveles (5 categorías × 6 niveles):
  * Categorías (`DriverBadgeCode`): `punctual` ("Conductor Puntual", `puntual`), `local_fav` ("Favorito del Pueblo", `favorito`), `impeccable` ("Servicio Impecable", `impecable`), `night_shift` ("Turno Nocturno" 00:00–06:00 / 12:00 AM–06:00 AM, `nocturno`) y `veteran` ("Veterano Local", `veterano`).
  * Evolución de Niveles (desde Nivel 0): 1 Madera (`#8B5A2B`), 2 Cobre (`#B87333`), 3 Plata (`#94A3B8`), 4 Oro (`#F59E0B`), 5 Diamante (`#38BDF8`) y 6 Obsidiana (`#312E81`). Al ascender reemplaza el nivel anterior y dispara alerta local + sonora.
  * Recompensas escalonadas: Niveles 1–2 (insignia visible al pasajero + 2 s de prioridad en pedidos cercanos), Niveles 3–4 (borde de material en ficha del pasajero + 5 s de prioridad), Niveles 5–6 (borde especial Diamante/Obsidiana + 8 s de prioridad + estadísticas avanzadas por zona gratis por 15 días).
  * Configuración web editable por localidad (`badge_configs`) desde "Usuarios y legajos" -> pestaña "Configurar metas e insignias".
- Legajo, privacidad, panel operativo, soporte y ayuda: Carga de foto del auto (frontal o lateral), selector modal de marcas/modelos argentinos y selector estilizado en Soporte (`TaxiyaSelectorField`), legajo amplio de 2 columnas sin superposición en Web, marcadores de Mapa en vivo con nombre del conductor, popups temáticos sin borde amarillo y menú lateral izquierdo fijo y colapsable en `AdminShell`.

6. Protocolo de Actualización
Cuando el usuario pida agregar una localidad, modificar tarifas de suscripción, cambiar reglas de negocio o sumar un módulo, actualizar esta memoria manteniendo la estructura limpia y concreta.
