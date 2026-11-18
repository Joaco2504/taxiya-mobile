import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/taxiya_models.dart';
import '../providers/core_providers.dart';
import '../theme/taxiya_theme.dart';
import '../utils/date_format_utils.dart';
import '../utils/taxiya_external_launcher.dart';

/// Abre la hoja modal de chat en tiempo real asociada a un viaje.
Future<void> showTaxiyaTripChatSheet({
  required BuildContext context,
  required String tripId,
  required String currentUserId,
  required String counterpartName,
  String? counterpartPhone,
  required List<String> quickReplies,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (BuildContext ctx) {
      return SizedBox(
        height: MediaQuery.sizeOf(ctx).height * 0.78,
        child: TaxiyaTripChatSheet(
          tripId: tripId,
          currentUserId: currentUserId,
          counterpartName: counterpartName,
          counterpartPhone: counterpartPhone,
          quickReplies: quickReplies,
        ),
      );
    },
  );
}

/// Chat en tiempo real sobre `taxiya.trip_messages` con respuestas rápidas y bloqueo a los 15 minutos post-viaje.
class TaxiyaTripChatSheet extends ConsumerStatefulWidget {
  const TaxiyaTripChatSheet({
    super.key,
    required this.tripId,
    required this.currentUserId,
    required this.counterpartName,
    this.counterpartPhone,
    required this.quickReplies,
  });

  final String tripId;
  final String currentUserId;
  final String counterpartName;
  final String? counterpartPhone;
  final List<String> quickReplies;

  @override
  ConsumerState<TaxiyaTripChatSheet> createState() =>
      _TaxiyaTripChatSheetState();
}

class _TaxiyaTripChatSheetState extends ConsumerState<TaxiyaTripChatSheet> {
  final TextEditingController _msgCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  bool _sending = false;
  Timer? _lockTick;

  @override
  void initState() {
    super.initState();
    _lockTick = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _lockTick?.cancel();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _send(String text) async {
    final clean = text.trim();
    if (clean.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await ref.read(taxiyaRepositoryProvider).sendTripMessage(
        tripId: widget.tripId,
        senderId: widget.currentUserId,
        message: clean,
      );
      _msgCtrl.clear();
      if (_scrollCtrl.hasClients) {
        unawaited(
          _scrollCtrl.animateTo(
            _scrollCtrl.position.maxScrollExtent + 80,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No pudimos enviar el mensaje sin señal. Probá de nuevo.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(taxiyaRepositoryProvider);
    final colors = context.taxiyaColors;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: StreamBuilder<Trip?>(
        stream: repo.watchTripById(widget.tripId),
        builder: (BuildContext context, AsyncSnapshot<Trip?> tripSnap) {
          final trip = tripSnap.data;
          final writable = trip?.isChatWritable ?? true;
          final minsLeft = trip?.remainingChatMinutes ?? 15;
          final hasPhone =
              widget.counterpartPhone != null &&
              widget.counterpartPhone!.trim().isNotEmpty;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Chat con ${widget.counterpartName}',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            trip != null && trip.status.isTerminal
                                ? (writable
                                    ? 'Podés escribir durante $minsLeft min más'
                                    : 'Chat cerrado tras finalizar el viaje')
                                : 'Mensajes del viaje en vivo',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: writable
                                  ? colors.textSecondary
                                  : colors.error,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (hasPhone)
                      OutlinedButton.icon(
                        onPressed: () async {
                          final ok = await TaxiyaExternalLauncher
                              .openPhoneDialer(widget.counterpartPhone);
                          if (!ok && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'No pudimos abrir el marcador telefónico.',
                                ),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.call_rounded, size: 18),
                        label: const Text('Llamar'),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: StreamBuilder<List<TripMessage>>(
                  stream: repo.watchTripMessages(widget.tripId),
                  builder: (
                    BuildContext context,
                    AsyncSnapshot<List<TripMessage>> snap,
                  ) {
                    final messages = snap.data ?? const <TripMessage>[];
                    if (snap.connectionState == ConnectionState.waiting &&
                        messages.isEmpty) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (messages.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'Todavía no hay mensajes en este viaje. Elegí una respuesta rápida o escribí abajo.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: colors.textSecondary),
                          ),
                        ),
                      );
                    }
                    return ListView.builder(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.all(14),
                      itemCount: messages.length,
                      itemBuilder: (BuildContext context, int index) {
                        final msg = messages[index];
                        final isMine = msg.senderId == widget.currentUserId;
                        final scheme = Theme.of(context).colorScheme;
                        return Align(
                          alignment: isMine
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.sizeOf(context).width * 0.74,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 13,
                              vertical: 9,
                            ),
                            decoration: BoxDecoration(
                              color: isMine
                                  ? scheme.primary
                                  : colors.surfaceCard,
                              borderRadius: BorderRadius.circular(14),
                              border: isMine
                                  ? null
                                  : Border.all(color: colors.border),
                            ),
                            child: Column(
                              crossAxisAlignment: isMine
                                  ? CrossAxisAlignment.end
                                  : CrossAxisAlignment.start,
                              children: [
                                Text(
                                  msg.message,
                                  style: TextStyle(
                                    color: isMine
                                        ? scheme.onPrimary
                                        : scheme.onSurface,
                                    fontSize: 14.5,
                                  ),
                                ),
                                if (msg.createdAt != null) ...[
                                  const SizedBox(height: 3),
                                  Text(
                                    TaxiyaDateUtils.formatTime(
                                      context,
                                      msg.createdAt!,
                                    ),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isMine
                                          ? scheme.onPrimary
                                                .withValues(alpha: 0.75)
                                          : colors.textSecondary,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              if (!writable)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  color: colors.surfaceCard,
                  child: Text(
                    'El chat cerró 15 minutos después de finalizar el viaje. Si quedó algún objeto o reclamo, usá Ayuda y soporte.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: colors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              else ...[
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                  child: Row(
                    children: widget.quickReplies.map((String q) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ActionChip(
                          label: Text(q),
                          onPressed: _sending ? null : () => _send(q),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _msgCtrl,
                          textInputAction: TextInputAction.send,
                          onSubmitted: _send,
                          decoration: const InputDecoration(
                            hintText: 'Escribí un mensaje...',
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _sending ? null : () => _send(_msgCtrl.text),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(52, 48),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                        ),
                        child: _sending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.send_rounded),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
