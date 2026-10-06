import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../state/safety_controller.dart';
import '../widgets/common.dart';
import '../widgets/labels.dart';

Future<void> showLiveShareSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _LiveShareSheet(),
    );

class _LiveShareSheet extends StatefulWidget {
  const _LiveShareSheet();

  @override
  State<_LiveShareSheet> createState() => _LiveShareSheetState();
}

class _LiveShareSheetState extends State<_LiveShareSheet> {
  static const _options = [
    Duration(minutes: 15),
    Duration(minutes: 30),
    Duration(hours: 1),
    Duration(hours: 2),
    Duration(hours: 4),
    Duration(hours: 8),
  ];

  Duration _duration = const Duration(hours: 1);
  late Set<String> _selected = {
    if (context.read<SafetyController>().primaryContact != null)
      context.read<SafetyController>().primaryContact!.id,
  };
  bool _starting = false;

  Future<void> _start() async {
    setState(() => _starting = true);
    final c = context.read<SafetyController>();
    final nav = Navigator.of(context);
    await c.startLiveShare(duration: _duration, contactIds: _selected.toList());
    nav.pop();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final c = context.watch<SafetyController>();
    return SheetScaffold(
      title: s.t('liveShareTitle'),
      subtitle: s.t('liveShareSubtitle'),
      children: [
        Text(
          s.t('shareFor'),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        DurationChips(
          options: _options,
          value: _duration,
          label: (d) => formatDuration(d, s),
          onChanged: (d) => setState(() => _duration = d),
        ),
        const SizedBox(height: 16),
        Text(
          s.t('shareWith'),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        ContactSelector(
          contacts: c.contacts,
          selected: _selected,
          onChanged: (v) => setState(() => _selected = v),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.live.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            c.settings.hasTrackingServer
                ? s.t('liveShareViaLink')
                : !c.autoSms
                ? s.t('liveShareViaSmsLite')
                : s.t('liveShareViaSms', {
                    'n': c.settings.updateIntervalMinutes,
                  }),
            style: const TextStyle(fontSize: 13),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          key: const ValueKey('live_start'),
          style: FilledButton.styleFrom(backgroundColor: AppColors.live),
          onPressed: _selected.isEmpty || _starting ? null : _start,
          icon: _starting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.share_location),
          label: Text(s.t('startSharing')),
        ),
      ],
    );
  }
}
