import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taxiya_core/taxiya_core.dart';

/// Pantalla de rendimiento local, horas conectado, Turno Nocturno, metas e insignias del chofer.
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
        repo.fetchDriverBadges(widget.profile.id),
      ]);
      final trips = results[0] as List<Trip>;
      final ratings = results[1] as List<TripRating>;
      var badges = results[2] as List<DriverBadge>;

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
        profileRatingAvg: widget.details.ratingAvg,
      );

      if (computed.earnedBadgeCodes.isNotEmpty) {
        badges = await repo.syncEarnedDriverBadges(
          driverId: widget.profile.id,
          earnedCodes: computed.earnedBadgeCodes,
        );
      }

      if (mounted) {
        setState(() {
          _trips = trips;
          _ratings = ratings;
          _dbBadges = badges;
        });
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
      profileRatingAvg: widget.details.ratingAvg,
    );

    final activeDbCodes = _dbBadges
        .where((DriverBadge b) => b.isActive && b.badgeCode != null)
        .map((DriverBadge b) => b.badgeCode!)
        .toSet();
    final combinedEarned = <DriverBadgeCode>{
      ...stats.earnedBadgeCodes,
      ...activeDbCodes,
    };

    // Estadística desbloqueable de zonas más activas en la localidad.
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
        title: const Text('Tu rendimiento y logros'),
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
                  'Metas locales',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _GoalProgressRow(
                          title: '20 viajes semanales',
                          progressLabel:
                              '${stats.weeklyCompletedTrips} / 20 viajes',
                          fraction: (stats.weeklyCompletedTrips / 20).clamp(
                            0.0,
                            1.0,
                          ),
                          color: colors.success,
                        ),
                        const SizedBox(height: 14),
                        _GoalProgressRow(
                          title:
                              '5 viajes en Turno Nocturno (${TaxiyaDateUtils.nightShiftRangeLabel(context)})',
                          progressLabel: '${stats.weeklyNightTrips} / 5 viajes',
                          fraction: (stats.weeklyNightTrips / 5).clamp(
                            0.0,
                            1.0,
                          ),
                          color: scheme.secondary,
                        ),
                        const SizedBox(height: 14),
                        _GoalProgressRow(
                          title: 'Calificación mínima 4,8 en 15 viajes',
                          progressLabel:
                              '${stats.averageRating?.toStringAsFixed(1) ?? '0.0'} · ${stats.evaluatedTripsCount}/15 viajes',
                          fraction: (((stats.averageRating ?? 0) / 4.8) * 0.5 +
                                  (stats.evaluatedTripsCount / 15).clamp(
                                        0.0,
                                        1.0,
                                      ) *
                                      0.5)
                              .clamp(0.0, 1.0),
                          color: scheme.primary,
                        ),
                        const SizedBox(height: 14),
                        _GoalProgressRow(
                          title: '10 viajes seguidos sin cancelar',
                          progressLabel: '${stats.noCancelStreak} / 10 seguidos',
                          fraction: (stats.noCancelStreak / 10).clamp(
                            0.0,
                            1.0,
                          ),
                          color: colors.success,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Recompensas activas',
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
                          title: 'Prioridad de 5 s al recibir pedidos nuevos',
                          active: combinedEarned.any(
                            (DriverBadgeCode c) => c.grantsOrderPriority,
                          ),
                        ),
                        const Divider(height: 18),
                        _RewardRow(
                          title: 'Borde dorado visible en la tarjeta del pasajero',
                          active: combinedEarned.any(
                            (DriverBadgeCode c) => c.grantsGoldBorder,
                          ),
                        ),
                        const Divider(height: 18),
                        _RewardRow(
                          title: 'Estadísticas de zonas activas en la localidad',
                          active: combinedEarned.contains(
                            DriverBadgeCode.nightShift,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (combinedEarned.contains(DriverBadgeCode.nightShift) &&
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
                            'Zonas con mayor demanda en tu historial',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...topZones.take(4).map((e) {
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
                  'Insignias',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                ...DriverBadgeCode.values.map((DriverBadgeCode code) {
                  final unlocked = combinedEarned.contains(code);
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: TaxiyaBadgePill(badgeCode: code),
                      title: Text(
                        code.descriptionAr,
                        style: const TextStyle(fontSize: 13.5),
                      ),
                      subtitle: Text(
                        'Beneficio: ${code.rewardAr}',
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.textSecondary,
                        ),
                      ),
                      trailing: Icon(
                        unlocked
                            ? Icons.check_circle_rounded
                            : Icons.lock_outline_rounded,
                        color: unlocked ? colors.success : colors.textSecondary,
                      ),
                    ),
                  );
                }),
              ],
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

class _GoalProgressRow extends StatelessWidget {
  const _GoalProgressRow({
    required this.title,
    required this.progressLabel,
    required this.fraction,
    required this.color,
  });

  final String title;
  final String progressLabel;
  final double fraction;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = context.taxiyaColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                ),
              ),
            ),
            Text(
              progressLabel,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: colors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            minHeight: 8,
            value: fraction,
            color: color,
          ),
        ),
      ],
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
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
          ),
        ),
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
