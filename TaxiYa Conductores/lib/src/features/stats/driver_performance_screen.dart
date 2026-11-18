import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taxiya_core/taxiya_core.dart';

/// Pantalla de rendimiento local, horas conectado, Turno Nocturno,
/// y progreso de las 30 insignias (5 categorías × 6 niveles evolutivos).
class DriverPerformanceScreen extends ConsumerStatefulWidget {
  const DriverPerformanceScreen({
    super.key,
    required this.profile,
    required this.details,
  });

  final Profile profile;
  final DriverDetails details;

  @override
  ConsumerState<DriverPerformanceScreen> createState() =>
      _DriverPerformanceScreenState();
}

class _DriverPerformanceScreenState
    extends ConsumerState<DriverPerformanceScreen> {
  StatsPeriod _period = StatsPeriod.week;
  bool _loading = true;
  List<Trip> _trips = const <Trip>[];
  List<TripRating> _ratings = const <TripRating>[];
  Map<DriverBadgeCode, BadgeConfig> _badgeConfigs = BadgeConfig.defaultsMap();
  List<DriverBadge> _dbBadges = const <DriverBadge>[];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final repo = ref.read(taxiyaRepositoryProvider);
    try {
      final results = await Future.wait<dynamic>([
        repo.fetchDriverTripsHistory(widget.profile.id),
        repo.fetchDriverRatings(widget.profile.id),
        repo.fetchBadgeConfigs(widget.profile.localityId),
      ]);
      final trips = results[0] as List<Trip>;
      final ratings = results[1] as List<TripRating>;
      final configs = results[2] as Map<DriverBadgeCode, BadgeConfig>;

      final weekStart = DriverStatsCalculator.startOfPeriod(
        DateTime.now(),
        StatsPeriod.week,
      );
      final weekHours = ref
          .read(hiveCacheProvider)
          .calculateOnlineHoursSince(weekStart);
      final computed = DriverStatsCalculator.compute(
        driverId: widget.profile.id,
        period: StatsPeriod.week,
        trips: trips,
        ratings: ratings,
        onlineHoursInPeriod: weekHours,
        badgeConfigs: configs,
        profileRatingAvg: widget.details.ratingAvg,
      );

      final syncRes = await repo.syncProgressiveDriverBadges(
        driverId: widget.profile.id,
        progressByCode: computed.badgeProgress,
      );

      if (mounted) {
        setState(() {
          _trips = trips;
          _ratings = ratings;
          _badgeConfigs = configs;
          _dbBadges = syncRes.badges;
        });
        if (syncRes.levelUps.isNotEmpty) {
          final first = syncRes.levelUps.first;
          unawaited(TaxiyaSoundService().playChime());
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              duration: const Duration(seconds: 6),
              content: Text(
                'Subiste a nivel ${first.newLevel.labelAr} en ${first.badgeCode.labelAr}.',
              ),
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = context.taxiyaColors;
    final cache = ref.watch(hiveCacheProvider);

    final periodStart = DriverStatsCalculator.startOfPeriod(
      DateTime.now(),
      _period,
    );
    final onlineHours = cache.calculateOnlineHoursSince(periodStart);
    final stats = DriverStatsCalculator.compute(
      driverId: widget.profile.id,
      period: _period,
      trips: _trips,
      ratings: _ratings,
      onlineHoursInPeriod: onlineHours,
      badgeConfigs: _badgeConfigs,
      profileRatingAvg: widget.details.ratingAvg,
    );

    final dbLevelByCode = <DriverBadgeCode, BadgeLevel>{
      for (final b in _dbBadges)
        if (b.isActive && b.badgeCode != null) b.badgeCode!: b.level,
    };

    var effectiveHighest = stats.highestBadgeLevel;
    for (final lvl in dbLevelByCode.values) {
      if (lvl.level > effectiveHighest.level) {
        effectiveHighest = lvl;
      }
    }

    // Zonas de demanda desbloqueables (Nivel 5 Diamante / Nivel 6 Obsidiana).
    final zoneCounts = <String, int>{};
    for (final trip in _trips.where((t) => t.status == TripStatus.completed)) {
      final zone = (trip.originAddress?.trim().isNotEmpty ?? false)
          ? trip.originAddress!.trim()
          : 'Zona céntrica';
      zoneCounts[zone] = (zoneCounts[zone] ?? 0) + 1;
    }
    final topZones = zoneCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tu rendimiento e insignias'),
        actions: [
          IconButton(
            tooltip: 'Actualizar métricas',
            onPressed: _loadData,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SegmentedButton<StatsPeriod>(
                  segments: StatsPeriod.values
                      .map(
                        (StatsPeriod p) => ButtonSegment<StatsPeriod>(
                          value: p,
                          label: Text(p.labelAr),
                        ),
                      )
                      .toList(),
                  selected: <StatsPeriod>{_period},
                  onSelectionChanged: (Set<StatsPeriod> sel) {
                    setState(() => _period = sel.first);
                  },
                ),
                const SizedBox(height: 14),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.48,
                  children: [
                    _KpiTile(
                      label: 'Viajes completados',
                      value: '${stats.completedTrips}',
                      icon: Icons.check_circle_outline_rounded,
                      accent: colors.success,
                    ),
                    _KpiTile(
                      label: 'Horas conectado',
                      value: '${stats.onlineHours.toStringAsFixed(1)} h',
                      icon: Icons.timer_outlined,
                      accent: scheme.secondary,
                    ),
                    _KpiTile(
                      label: 'Calificación',
                      value: stats.averageRating != null
                          ? stats.averageRating!.toStringAsFixed(1)
                          : 'Sin votos',
                      icon: Icons.star_rounded,
                      accent: scheme.primary,
                    ),
                    _KpiTile(
                      label:
                          'Turno Nocturno (${TaxiyaDateUtils.nightShiftRangeLabel(context)})',
                      value: '${stats.nightShiftTrips}',
                      icon: Icons.nightlight_round,
                      accent: scheme.secondary,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  'Recompensas activas (${effectiveHighest.labelAr})',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      children: [
                        _RewardRow(
                          title:
                              'Niveles 1-2 (Madera / Cobre): insignia visible y +2 s de prioridad',
                          active: effectiveHighest.level >= 1,
                        ),
                        const Divider(height: 16),
                        _RewardRow(
                          title:
                              'Niveles 3-4 (Plata / Oro): borde en tarjeta del pasajero y +5 s de prioridad',
                          active: effectiveHighest.level >= 3,
                        ),
                        const Divider(height: 16),
                        _RewardRow(
                          title:
                              'Niveles 5-6 (Diamante / Obsidiana): borde especial, +8 s de prioridad y estadísticas Premium por 15 días',
                          active: effectiveHighest.level >= 5,
                        ),
                      ],
                    ),
                  ),
                ),
                if (effectiveHighest.grantsPremiumZoneStatsFor15Days &&
                    topZones.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Estadísticas avanzadas por zona (desbloqueo 15 días)',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...topZones.take(5).map((e) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      e.key,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text(
                                    '${e.value} viajes',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                Text(
                  'Tus 5 categorías de insignias (6 niveles)',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Arrancás en Nivel 0 y evolucionás de Madera a Obsidiana en cada categoría.',
                  style: TextStyle(fontSize: 12.5, color: colors.textSecondary),
                ),
                const SizedBox(height: 10),
                ...DriverBadgeCode.values.map((DriverBadgeCode code) {
                  final progress = stats.badgeProgress[code]!;
                  final dbLevel = dbLevelByCode[code] ?? BadgeLevel.none;
                  final currentLevel =
                      dbLevel.level > progress.currentLevel.level
                      ? dbLevel
                      : progress.currentLevel;
                  final accent = Color(
                    (currentLevel.isEarned ? currentLevel : BadgeLevel.madera)
                        .colorHex,
                  );

                  return _BadgeCategoryCard(
                    code: code,
                    progress: progress,
                    effectiveLevel: currentLevel,
                    accent: accent,
                  );
                }),
              ],
            ),
    );
  }
}

class _BadgeCategoryCard extends StatelessWidget {
  const _BadgeCategoryCard({
    required this.code,
    required this.progress,
    required this.effectiveLevel,
    required this.accent,
  });

  final DriverBadgeCode code;
  final DriverBadgeProgress progress;
  final BadgeLevel effectiveLevel;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final colors = context.taxiyaColors;
    final nextTarget = progress.nextTargetCount;
    final nextLevel = effectiveLevel.level < 6
        ? BadgeLevel.fromLevelInt(effectiveLevel.level + 1)
        : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                TaxiyaBadgeArtwork(
                  badgeCode: code,
                  level: effectiveLevel,
                  size: 48,
                  locked: !effectiveLevel.isEarned,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        code.labelAr,
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        code.descriptionAr,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: accent.withValues(alpha: 0.6)),
                  ),
                  child: Text(
                    effectiveLevel.isEarned
                        ? 'Nivel ${effectiveLevel.level} · ${effectiveLevel.labelAr}'
                        : 'Nivel 0',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: effectiveLevel.isEarned
                          ? accent
                          : colors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    nextTarget != null && nextLevel != null
                        ? 'Próximo nivel (${nextLevel.labelAr}): ${progress.currentCount} / $nextTarget ${code.unitAr}'
                        : 'Nivel máximo Obsidiana alcanzado (${progress.currentCount} ${code.unitAr})',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: colors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                minHeight: 8,
                value: progress.progressFraction,
                color: accent,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List<Widget>.generate(6, (int idx) {
                final tierLevel = BadgeLevel.unlockableLevels[idx];
                final unlocked = effectiveLevel.level >= tierLevel.level;
                final threshold = idx < progress.thresholds.length
                    ? progress.thresholds[idx]
                    : code.defaultThresholds[idx];

                return Expanded(
                  child: Column(
                    children: [
                      TaxiyaBadgeArtwork(
                        badgeCode: code,
                        level: tierLevel,
                        size: 36,
                        locked: !unlocked,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tierLevel.labelAr,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight:
                              unlocked ? FontWeight.w800 : FontWeight.w500,
                          color: unlocked
                              ? Color(tierLevel.colorHex)
                              : colors.textSecondary,
                        ),
                      ),
                      Text(
                        '$threshold',
                        style: TextStyle(
                          fontSize: 10,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

class _KpiTile extends StatelessWidget {
  const _KpiTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final colors = context.taxiyaColors;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: accent, size: 22),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: colors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RewardRow extends StatelessWidget {
  const _RewardRow({required this.title, required this.active});

  final String title;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final colors = context.taxiyaColors;
    return Row(
      children: [
        Icon(
          active ? Icons.verified_rounded : Icons.schedule_rounded,
          color: active ? colors.success : colors.textSecondary,
          size: 20,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          active ? 'Activa' : 'Bloqueada',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: active ? colors.success : colors.textSecondary,
          ),
        ),
      ],
    );
  }
}
