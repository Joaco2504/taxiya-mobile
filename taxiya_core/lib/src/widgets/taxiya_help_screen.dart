import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/taxiya_models.dart';
import '../providers/core_providers.dart';
import '../theme/taxiya_theme.dart';
import '../utils/date_format_utils.dart';
import '../utils/taxiya_external_launcher.dart';
import 'taxiya_selector_field.dart';

/// Tarjeta ilustrada de la guía rápida de uso (4 pasos por rol).
class TaxiyaHelpGuideCardData {
  const TaxiyaHelpGuideCardData({
    required this.stepLabel,
    required this.title,
    required this.description,
    required this.icon,
  });

  final String stepLabel;
  final String title;
  final String description;
  final IconData icon;
}

/// Pregunta frecuente local sobre funcionamiento y reglas de TaxiYa.
class TaxiyaFaqItemData {
  const TaxiyaFaqItemData({
    required this.question,
    required this.answer,
  });

  final String question;
  final String answer;
}

/// Pantalla compartida "Ayuda y guía de uso" con 4 tarjetas, FAQ locales, WhatsApp pre-cargado y reclamos en `taxiya.support_tickets`.
class TaxiyaHelpGuideScreen extends ConsumerStatefulWidget {
  const TaxiyaHelpGuideScreen({
    super.key,
    required this.profile,
    required this.roleLabel,
    required this.localityName,
    required this.guideCards,
    required this.faqItems,
    required this.ticketCategories,
    this.activeTripId,
  });

  final Profile profile;
  final String roleLabel;
  final String localityName;
  final List<TaxiyaHelpGuideCardData> guideCards;
  final List<TaxiyaFaqItemData> faqItems;
  final List<String> ticketCategories;
  final String? activeTripId;

  @override
  ConsumerState<TaxiyaHelpGuideScreen> createState() =>
      _TaxiyaHelpGuideScreenState();
}

class _TaxiyaHelpGuideScreenState extends ConsumerState<TaxiyaHelpGuideScreen> {
  final TextEditingController _descCtrl = TextEditingController();
  late String _selectedCategory;
  bool _sendingTicket = false;
  List<SupportTicket> _myTickets = const [];
  bool _loadingTickets = true;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.ticketCategories.first;
    _loadTickets();
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadTickets() async {
    setState(() => _loadingTickets = true);
    try {
      final list = await ref
          .read(taxiyaRepositoryProvider)
          .fetchMySupportTickets(widget.profile.id);
      if (mounted) setState(() => _myTickets = list);
    } catch (_) {
      // Sin señal 4G mantenemos la vista accesible sin bloquear FAQ ni WhatsApp.
    } finally {
      if (mounted) setState(() => _loadingTickets = false);
    }
  }

  Future<void> _submitTicket() async {
    final desc = _descCtrl.text.trim();
    if (desc.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Contanos brevemente qué pasó para poder ayudarte.'),
        ),
      );
      return;
    }
    setState(() => _sendingTicket = true);
    try {
      await ref.read(taxiyaRepositoryProvider).createSupportTicket(
        userId: widget.profile.id,
        tripId: widget.activeTripId,
        localityId: widget.profile.localityId,
        category: _selectedCategory,
        description: desc,
        isEmergency: false,
      );
      _descCtrl.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Consulta enviada. El equipo de TaxiYa la revisa en el panel.',
            ),
          ),
        );
      }
      await _loadTickets();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No pudimos enviar tu consulta porque no hay señal. Probá de nuevo en un momento.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sendingTicket = false);
    }
  }

  Color _ticketStatusColor(
    SupportTicketStatus status,
    TaxiyaSemanticColors colors,
    ColorScheme scheme,
  ) {
    switch (status) {
      case SupportTicketStatus.open:
        return colors.warning;
      case SupportTicketStatus.inReview:
      case SupportTicketStatus.inProgress:
        return scheme.secondary;
      case SupportTicketStatus.resolved:
      case SupportTicketStatus.closed:
        return colors.success;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.taxiyaColors;

    return Scaffold(
      appBar: AppBar(title: const Text('Ayuda y guía de uso')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Cómo funciona TaxiYa (${widget.roleLabel})',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 184,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: widget.guideCards.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (BuildContext context, int index) {
                final card = widget.guideCards[index];
                return SizedBox(
                  width: 256,
                  child: Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary
                                      .withValues(alpha: 0.16),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  card.icon,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                card.stepLabel,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: colors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            card.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14.5,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Expanded(
                            child: Text(
                              card.description,
                              style: TextStyle(
                                fontSize: 12.5,
                                color: colors.textSecondary,
                                height: 1.32,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Preguntas frecuentes',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: widget.faqItems.map((TaxiyaFaqItemData faq) {
                return ExpansionTile(
                  title: Text(
                    faq.question,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        faq.answer,
                        style: TextStyle(
                          color: colors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 18),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Soporte por WhatsApp',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Abre WhatsApp con tu ID, rol y localidad cargados para atenderte directo.',
                    style: TextStyle(
                      fontSize: 13,
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () async {
                      final ok = await TaxiyaExternalLauncher
                          .openWhatsAppSupport(
                            userId: widget.profile.id,
                            roleLabel: widget.roleLabel,
                            localityName: widget.localityName,
                          );
                      if (!ok && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'No encontramos WhatsApp instalado en este teléfono.',
                            ),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.chat_rounded),
                    label: const Text('Escribir por WhatsApp'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Enviar consulta o reclamo al panel',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TaxiyaSelectorField<String>(
                    label: 'Motivo',
                    sheetTitle: 'Elegí el motivo de tu reporte',
                    prefixIcon: Icons.label_outline_rounded,
                    value: _selectedCategory,
                    options: widget.ticketCategories
                        .map(
                          (String c) => TaxiyaSelectorOption<String>(
                            value: c,
                            label: c,
                          ),
                        )
                        .toList(),
                    onChanged: (String? value) {
                      if (value != null) {
                        setState(() => _selectedCategory = value);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _descCtrl,
                    minLines: 3,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'Detalle',
                      hintText:
                          'Escribí qué sucedió, la fecha o la zona para revisarlo rápido.',
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _sendingTicket ? null : _submitTicket,
                    icon: _sendingTicket
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded),
                    label: const Text('Enviar reporte'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tus reportes recientes',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              IconButton(
                onPressed: _loadTickets,
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'Actualizar reportes',
              ),
            ],
          ),
          if (_loadingTickets)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_myTickets.isEmpty)
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Todavía no enviaste reportes desde esta cuenta.',
                  style: TextStyle(color: colors.textSecondary),
                ),
              ),
            )
          else
            ..._myTickets.map((SupportTicket t) {
              final badgeColor = _ticketStatusColor(
                t.status,
                colors,
                theme.colorScheme,
              );
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              t.isEmergency
                                  ? 'Alerta de emergencia'
                                  : (t.category ?? 'Soporte'),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: badgeColor.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              t.status.labelAr,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: badgeColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (t.description != null &&
                          t.description!.trim().isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          t.description!,
                          style: TextStyle(
                            fontSize: 13.5,
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                      if (t.createdAt != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          TaxiyaDateUtils.formatDateTimeAr(
                            context,
                            t.createdAt,
                          ),
                          style: TextStyle(
                            fontSize: 11.5,
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
