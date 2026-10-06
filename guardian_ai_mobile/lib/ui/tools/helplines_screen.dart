import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/helplines.dart';
import '../../core/strings.dart';
import '../../services/device_bridge.dart';

/// Opens the dialer with [number].  Emergency numbers always go through the
/// dialer (Android does not allow apps to auto-dial them).
Future<void> callHelpline(
  BuildContext context,
  String number,
  String label,
) async {
  final ok = await context.read<DeviceBridge>().call(number);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppStrings.of(context).t('cannotCall', {'number': number}),
        ),
      ),
    );
  }
}

class HelplinesScreen extends StatelessWidget {
  const HelplinesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s.t('helplinesTitle'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final h in indiaHelplines)
            Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                contentPadding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                leading: CircleAvatar(
                  backgroundColor: h.color.withValues(alpha: 0.12),
                  child: Icon(h.icon, color: h.color),
                ),
                title: Text(
                  s.t(h.titleKey),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(s.t(h.descKey)),
                trailing: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: h.color,
                    minimumSize: const Size(0, 44),
                  ),
                  onPressed: () =>
                      callHelpline(context, h.number, s.t(h.titleKey)),
                  icon: const Icon(Icons.call, size: 18),
                  label: Text(h.number),
                ),
              ),
            ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => launchUrl(
              Uri.parse(emergencySourceUrl),
              mode: LaunchMode.externalApplication,
            ),
            icon: const Icon(Icons.open_in_new, size: 18),
            label: Text(s.t('helplinesSource')),
          ),
        ],
      ),
    );
  }
}
