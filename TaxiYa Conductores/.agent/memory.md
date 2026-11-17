Guarda y consulta la identidad de la empresa TaxiYa, su arquitectura técnica, reglas de negocio, localidades operativas (Belén y Andalgalá), flotas, paleta de colores y decisiones clave del proyecto. Activar siempre que se diseñe, programe, tome decisiones de producto o se inicie una nueva sesión sobre TaxiYa.

Instructions
Memory - Identidad y Arquitectura de TaxiYa
Este documento es la memoria viva del proyecto TaxiYa. Se actualiza cada vez que se incorpora una nueva localidad, regla de negocio, empresa privada o cambio técnico.

1. Identidad de la Empresa y Alcance
Nombre oficial: TaxiYa
Propósito: Plataforma de despacho y conexión entre pasajeros y taxis habilitados en localidades del interior, sin intermediación financiera en el cobro de viajes.
Localidades activas iniciales:
Belén (Catamarca, Argentina): Opera con 2 empresas privadas de taxis + taxis independientes. Todos con habilitación municipal obligatoria.
Andalgalá (Catamarca, Argentina): Opera únicamente con taxis independientes con habilitación municipal obligatoria.
Escalabilidad: Arquitectura multi-zona preparada para sumar nuevas localidades y flotas sin modificar el código base.
2. Reglas de Negocio Inamovibles
Sin cálculo de tarifas: La plataforma nunca estima ni muestra precios de viaje. El cobro se rige por reloj taxímetro físico o acuerdo directo según ordenanza municipal.
Sin pasarela de pagos por viaje: No se procesan tarjetas, transferencias ni billeteras virtuales para pagar traslados.
Sin comisiones por viaje: No se descuenta porcentaje sobre los recorridos completados.
Monetización directa:
Suscripciones mensuales vía RevenueCat + Google Play Billing (y a futuro Apple App Store): Plan Gratuito ($0 USD con publicidad), Plan Sin Publicidad ($2 USD/mes) y Plan Premium ($3 USD/mes).
Publicidad local en banners dentro de la app para usuarios gratuitos: $3 USD/mes por comercio local con redirección a WhatsApp o sitio web/red social. Si no hay anunciantes locales activos, se muestra publicidad aleatoria de respaldo (AdMob o banners internos de TaxiYa).
3. Ecosistema y Stack Técnico (Costo inicial $0)
Repositorios en GitHub:
taxiya-mobile (Monorepo Flutter / Dart 3 con taxiya_core, taxiya_pasajeros y taxiya_conductores).
taxiya-admin (Panel Web en Next.js 14+ App Router, TypeScript, Tailwind CSS y shadcn/ui, desplegado en Vercel).
Backend y Base de Datos: Supabase (PostgreSQL + PostGIS + Auth + Realtime + Storage).
Esquema oficial: taxiya.
Buckets de Storage: taxiya_public (avatares, fotos de autos, banners) y taxiya_private (selfies de validación, carnets de conducir, habilitaciones municipales).
Mapas y Geolocalización: Mapbox GL (mapbox_maps_flutter y react-map-gl).
Notificaciones Push: Firebase Cloud Messaging (taxiya-catamarca).
Paquetes Android: ar.com.taxiya.pasajeros y ar.com.taxiya.conductores.
Persistencia Offline: hive_flutter para operar en zonas periféricas con cortes de señal 4G.
4. Identidad Visual (Paleta de Colores)
Modo Claro (Daylight Mode):
Fondo principal: #F8FAFC
Superficies / Tarjetas: #FFFFFF (borde #E2E8F0)
Color primario: #F59E0B (texto sobre primario #0F172A)
Color secundario: #0284C7
Texto principal: #0F172A | Texto secundario: #475569
Estados: Éxito #16A34A | Alerta #EA580C | Error #DC2626
Modo Oscuro (Night Shift Mode):
Fondo principal: #0B0F19
Superficies / Tarjetas: #151C2C (borde #263147)
Color primario: #FBBF24 (texto sobre primario #0B0F19)
Color secundario: #38BDF8
Texto principal: #F1F5F9 | Texto secundario: #94A3B8
Estados: Éxito #22C55E | Alerta #FB923C | Error #F87171
5. Funcionalidades Diferenciales Clave
Prevención de fallos tipo Uber: Interpolación GPS cada 3 segundos (marcador gris tras 15s sin señal), liberación automática de viaje a los 4 minutos si el taxi no avanza hacia el origen, y confirmación visual de pin cuando el margen de error GPS supera los 20 metros.
Puntos de referencia: Destinos personales privados (sin aprobación) y puntos públicos colaborativos (requieren aprobación del admin).
Viajes especiales: Repetir último viaje en un toque, reserva programada (dispara aviso 30 min antes) y viaje ida y vuelta con espera inteligente (umbral de 10 minutos para que el taxista decida si espera o libera el móvil).
Gamificación local: Metas adaptadas a pueblos chicos, Turno Nocturno (00:00 a 06:00 o 12:00 AM a 06:00 AM según reloj del teléfono), insignias visibles y recompensas operativas.
Legajo y privacidad: Carga de selfie del auto (frontal o lateral), selector de modelos argentinos con carga manual opcional y controles de privacidad para ocultar patente completa o número de habilitación al pasajero.
6. Protocolo de Actualización
Cuando el usuario pida agregar una localidad, modificar tarifas de suscripción, cambiar reglas de negocio o sumar un módulo, actualizar esta memoria manteniendo la estructura limpia y concreta.