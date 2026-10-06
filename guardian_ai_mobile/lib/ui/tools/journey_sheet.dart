import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../state/safety_controller.dart';
import '../widgets/common.dart';
import '../widgets/labels.dart';

Future<void> showJourneySheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _JourneySheet(),
    );

class _JourneySheet extends StatefulWidget {
  const _JourneySheet();

  @override
  State<_JourneySheet> createState() => _JourneySheetState();
}

class _JourneySheetState extends State<_JourneySheet> {
  static const _options = [
    Duration(minutes: 15),
    Duration(minutes: 30),
    Duration(minutes: 45),
    Duration(hours: 1),
    Duration(minutes: 90),
    Duration(hours: 2),
    Duration(hours: 3),
  ];

  final _destination = TextEditingController();
  Duration _duration = const Duration(minutes: 30);
  late Set<String> _selected = context
      .read<SafetyController>()
      .sosContacts
      .map((c) => c.id)
      .toSet();
  bool _starting = false;

  @override
  void dispose() {
    _destination.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    setState(() => _starting = true);
    final c = context.read<SafetyController>();
    final nav = Navigator.of(context);
    await c.startJourney(
      duration: _duration,
      destination: _destination.text,
      contactIds: _selected.toList(),
    );
    nav.pop();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final c = context.watch<SafetyController>();
    return SheetScaffold(
      title: s.t('journeyTitle'),
      subtitle: s.t('journeySubtitle'),
      children: [
        TextField(
          controller: _destination,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: s.t('destination'),
            hintText: s.t('destinationHint'),
            prefixIcon: const Icon(Icons.place_outlined),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          s.t('checkInWithin'),
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
          s.t('whoToAlert'),
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
            color: AppColors.journey.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            s.t(c.autoSms ? 'journeyExplainer' : 'journeyExplainerLite'),
            style: const TextStyle(fontSize: 13),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          key: const ValueKey('journey_start'),
          style: FilledButton.styleFrom(backgroundColor: AppColors.journey),
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
              : const Icon(Icons.play_arrow),
          label: Text(s.t('startJourney')),
        ),
      ],
    );
  }
}
