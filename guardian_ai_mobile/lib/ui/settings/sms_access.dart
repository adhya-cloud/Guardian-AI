import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../services/permissions.dart';
import '../../state/safety_controller.dart';
import '../widgets/common.dart';

/// Gets the SMS permission granted, whatever is in the way: asks for it,
/// opens app settings after "Don't allow", or explains Android's restricted
/// settings.
Future<void> fixSmsAccess(BuildContext context) async {
  final c = context.read<SafetyController>();
  if (c.smsAccess == PermissionState.permanentlyDenied) {
    await context.read<PermissionService>().openSettings();
    return;
  }
  final state = await c.requestSmsAccess(userInitiated: true);
  if (state == PermissionState.restricted && context.mounted) {
    await showSmsRestrictedSheet(context);
  }
}

Future<void> showSmsRestrictedSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _SmsRestrictedSheet(),
    );

class _SmsRestrictedSheet extends StatelessWidget {
  const _SmsRestrictedSheet();

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    // Refreshed when the user returns from system settings.
    final allowed = context.select<SafetyController, bool>(
      (c) => c.smsAccess == PermissionState.granted,
    );
    final muted = TextStyle(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );

    if (allowed) {
      return SheetScaffold(
        title: s.t('smsRestrictedTitle'),
        children: [
          const Icon(Icons.check_circle, color: AppColors.success, size: 56),
          const SizedBox(height: 12),
          Text(s.t('smsAllowedNow'), textAlign: TextAlign.center),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: Text(s.t('done')),
          ),
        ],
      );
    }

    Widget step(int n, String text) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 13,
            backgroundColor: AppColors.brand,
            child: Text(
              '$n',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );

    return SheetScaffold(
      title: s.t('smsRestrictedTitle'),
      subtitle: s.t('smsRestrictedIntro'),
      children: [
        step(1, s.t('smsRestrictedStep1')),
        step(2, s.t('smsRestrictedStep2')),
        step(3, s.t('smsRestrictedStep3')),
        Text(s.t('smsRestrictedNoMenu'), style: muted),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.journey.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            s.t('smsRestrictedMeanwhile'),
            style: const TextStyle(fontSize: 13),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          key: const ValueKey('sms_open_settings'),
          onPressed: () => context.read<PermissionService>().openSettings(),
          icon: const Icon(Icons.settings_outlined),
          label: Text(s.t('openAppSettings')),
        ),
      ],
    );
  }
}

/// Warns that the full edition can't send SMS by itself, with a fix button.
class SmsAccessBanner extends StatelessWidget {
  const SmsAccessBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final c = context.watch<SafetyController>();
    if (!c.smsPermissionMissing) return const SizedBox.shrink();
    final restricted = c.smsAccess == PermissionState.restricted;
    return Card(
      key: const ValueKey('sms_access_banner'),
      margin: const EdgeInsets.only(bottom: 12),
      color: AppColors.sos.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.sms_failed_outlined, color: AppColors.sos),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.t('smsOffTitle'),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        s.t(restricted ? 'smsOffRestrictedBody' : 'smsOffBody'),
                        style: const TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => fixSmsAccess(context),
                child: Text(
                  s.t(
                    restricted
                        ? 'howToAllow'
                        : c.smsAccess == PermissionState.permanentlyDenied
                        ? 'openAppSettings'
                        : 'allowSms',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
