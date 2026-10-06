import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/phone.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../models/incident.dart';
import '../../state/safety_controller.dart';
import '../widgets/labels.dart';
import '../widgets/safety_map.dart';

class SosActiveScreen extends StatelessWidget {
  const SosActiveScreen({super.key});

  Future<void> _stop(BuildContext context) async {
    final s = AppStrings.of(context);
    var notify = true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(s.t('stopSosTitle')),
          content: CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: notify,
            onChanged: (v) => setState(() => notify = v == true),
            title: Text(s.t('tellContactsSafe')),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(s.t('keepSosOn')),
            ),
            FilledButton(
              key: const ValueKey('sos_stop_confirm'),
              style: FilledButton.styleFrom(backgroundColor: AppColors.success),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(s.t('imSafe')),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !context.mounted) return;
    final c = context.read<SafetyController>();
    final nav = Navigator.of(context);
    await c.stopSos(notifyContacts: notify);
    if (nav.canPop()) nav.pop();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final c = context.watch<SafetyController>();
    final sos = c.activeSos;

    if (sos == null && !c.sendingSos) {
      // SOS ended (possibly from another screen).
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(s.t('sosEnded'))),
      );
    }

    final me = c.lastLocation ?? sos?.lastPoint;
    final alerts =
        sos?.deliveries
            .where((d) => d.kind == DeliveryKind.sosAlert)
            .toList() ??
        const <Delivery>[];
    // Only OS-confirmed messages count; the SMS app still needs a tap on Send.
    final sent = alerts.where((d) => d.status == DeliveryStatus.sent).length;
    final awaitingSend =
        sent == 0 && alerts.any((d) => d.status == DeliveryStatus.composer);
    final primary = c.primaryContact;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.sos,
        foregroundColor: Colors.white,
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
        title: Text(s.t('sosActive')),
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            color: AppColors.sos,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                if (c.sendingSos)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                else
                  Icon(
                    awaitingSend ? Icons.sms_outlined : Icons.check_circle,
                    color: Colors.white,
                  ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    c.sendingSos
                        ? s.t('sosSending')
                        : sos!.recipientIds.isEmpty
                        ? s.t('sosNoRecipients')
                        : awaitingSend
                        ? s.t('sosComposerSummary')
                        : s.t('sosSentSummary', {
                            'sent': sent,
                            'total': sos.recipientIds.length,
                          }),
                    key: const ValueKey('sos_status_text'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 220,
            child: SafetyMap(
              me: me,
              path: sos?.path ?? const [],
              pathColor: AppColors.sos,
              meColor: AppColors.sos,
              followMe: true,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  me == null
                      ? s.t('waitingForGps')
                      : '${me.coordinates}${me.accuracy == null ? '' : '  ±${me.accuracy!.round()} m'}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 56,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.sos,
                    ),
                    onPressed: () => c.callEmergency(),
                    icon: const Icon(Icons.call),
                    label: Text(
                      s.t('callEmergency', {
                        'number': c.profile?.emergencyNumber ?? '112',
                      }),
                      style: const TextStyle(fontSize: 17),
                    ),
                  ),
                ),
                if (primary != null) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => c.device.call(primary.phone),
                    icon: const Icon(Icons.call_outlined),
                    label: Text(s.t('callName', {'name': primary.name})),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _ToggleButton(
                        on: c.sirenOn,
                        icon: Icons.campaign,
                        label: c.sirenOn
                            ? s.t('actionSirenStop')
                            : s.t('actionSiren'),
                        onTap: () => c.setSiren(!c.sirenOn),
                      ),
                    ),
                    if (c.capabilities.torch) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: _ToggleButton(
                          on: c.strobeOn,
                          icon: Icons.flashlight_on,
                          label: c.strobeOn
                              ? s.t('actionStrobeStop')
                              : s.t('actionStrobe'),
                          onTap: () => c.setStrobe(!c.strobeOn),
                        ),
                      ),
                    ],
                  ],
                ),
                if (sos?.tracking != null) ...[
                  const SizedBox(height: 12),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.public, color: AppColors.live),
                      title: Text(s.t('liveMapLink')),
                      subtitle: Text(
                        sos!.tracking!.viewUrl,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: IconButton(
                        tooltip: s.t('shareLink'),
                        icon: const Icon(Icons.share),
                        onPressed: () => SharePlus.instance.share(
                          ShareParams(text: sos.tracking!.viewUrl),
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                if (c.sosAlertNeedsResend) ...[
                  FilledButton.icon(
                    key: const ValueKey('sos_resend'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.sosDark,
                    ),
                    onPressed: () => c.resendSosAlert(),
                    icon: const Icon(Icons.send),
                    label: Text(s.t('sendAlertAgain')),
                  ),
                  const SizedBox(height: 12),
                ],
                Text(
                  c.autoSms
                      ? s.t('sosUpdatesInfo', {
                          'n': c.settings.updateIntervalMinutes,
                        })
                      : s.t('sosUpdatesInfoLite'),
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                if (sos != null && sos.deliveries.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    s.t('messages'),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  for (final d in sos.deliveries.reversed.take(20))
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        deliveryStatusIcon(d.status),
                        color: deliveryStatusColor(d.status),
                      ),
                      title: Text('${d.contactName} · ${formatPhone(d.phone)}'),
                      subtitle: Text(
                        '${deliveryKindLabel(d.kind, s)} · ${deliveryStatusLabel(d, s)} · ${formatTime(context, d.at)}',
                      ),
                    ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  height: 56,
                  child: FilledButton.icon(
                    key: const ValueKey('sos_stop'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.success,
                    ),
                    onPressed: c.sendingSos ? null : () => _stop(context),
                    icon: const Icon(Icons.verified_user),
                    label: Text(
                      s.t('imSafeStop'),
                      style: const TextStyle(fontSize: 17),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleButton extends StatelessWidget {
  const _ToggleButton({
    required this.on,
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final bool on;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return on
        ? FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Colors.black87),
            onPressed: onTap,
            icon: Icon(icon),
            label: Text(label),
          )
        : OutlinedButton.icon(
            onPressed: onTap,
            icon: Icon(icon),
            label: Text(label),
          );
  }
}
