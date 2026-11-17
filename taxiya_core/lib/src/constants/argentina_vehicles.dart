/// Catálogo de marcas, modelos, colores y tipos de vehículos habituales en Argentina.
abstract final class ArgentinaVehicles {
  static const String customOption = 'Otro modelo';

  static const Map<String, List<String>> modelsByBrand = {
    'Fiat': ['Cronos', 'Siena', 'Uno', 'Argo'],
    'Chevrolet': ['Corsa / Classic', 'Prisma / Joy', 'Onix'],
    'Renault': ['Logan', 'Sandero', 'Kangoo'],
    'Volkswagen': ['Voyage', 'Gol Trend', 'Suran'],
    'Toyota': ['Etios', 'Yaris', 'Corolla'],
    'Peugeot': ['208', '301', 'Partner'],
    'Ford': ['Ka', 'Fiesta', 'Focus'],
  };

  static const List<String> commonColors = [
    'Blanco',
    'Gris plata',
    'Gris oscuro',
    'Negro',
    'Rojo',
    'Azul',
    'Bordó',
    'Otro',
  ];

  static const List<String> vehicleTypes = [
    'Sedán 4 puertas',
    'Hatchback 5 puertas',
    'Rural / Familiar',
    'Utilitario',
  ];
}
