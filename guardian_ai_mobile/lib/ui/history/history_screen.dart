import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:provider/provider.dart';

import '../../core/phone.dart';
import '../../core/strings.dart';
import '../../models/incident.dart';
import '../../state/safety_controller.dart';
import '../widgets/labels.dart';
import '../widgets/safety_map.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  Future<void> _clear(BuildContext context) async {
    final s = AppStrings.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.t('clearHistoryTitle')),
        content: Text(s.t('clearHistoryBody')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(s.t('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(s.t('clear')),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await context.read<SafetyController>().clearHistory();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final c = context.watch<SafetyController>();
    final items = c.incidents;
    return Scaffold(
      appBar: AppBar(
        title: Text(s.t('historyTitle')),
        actions: [
          if (items.any((i) => !i.isActive))
            IconButton(
              tooltip: s.t('clearHistoryTitle'),
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: () => _clear(context),
            ),
        ],
      ),
      body: items.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.history_toggle_off,
                      size: 64,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    const SizedBox(height: 12),
                    Text(s.t('noHistory'), textAlign: TextAlign.center),
                  ],
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final i = items[index];
                final color = incidentColor(i);
                final messages = i.deliveries.length;
                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
                    leading: CircleAvatar(
                      backgroundColor: color.withValues(alpha: 0.12),
                      child: Icon(incidentIcon(i), color: color),
                    ),
                    title: Text(
                      incidentTitle(i, s),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      '${formatDateTime(context, i.startedAt)}\n'
                      '${s.t('messagesCount', {'n': messages})}'
                      '${i.failedCount > 0 ? ' · ${s.t('failedCount', {'n': i.failedCount})}' : ''}',
                    ),
                    isThreeLine: true,
                    trailing: _StatusChip(incident: i),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => IncidentDetailScreen(incidentId: i.id),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.incident});
  final Incident incident;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final color = incident.isActive
        ? incidentColor(incident)
        : Theme.of(context).colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        incidentStatusLabel(incident, s),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class IncidentDetailScreen extends StatelessWidget {
  const IncidentDetailScreen({super.key, required this.incidentId});
  final String incidentId;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final c = context.watch<SafetyController>();
    final matches = c.incidents.where((i) => i.id == incidentId);
    if (matches.isEmpty) return Scaffold(appBar: AppBar());
    final i = matches.first;
    final color = incidentColor(i);
    final start = i.path.isEmpty ? null : i.path.first;
    final end = i.lastPoint;

    return Scaffold(
      appBar: AppBar(
        title: Text(incidentTitle(i, s)),
        actions: [
          if (!i.isActive)
            IconButton(
              tooltip: s.t('delete'),
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                final nav = Navigator.of(context);
                await c.deleteIncident(i.id);
                nav.pop();
              },
            ),
        ],
      ),
      body: ListView(
        children: [
          SizedBox(
            height: 260,
            child: i.path.isEmpty
                ? Container(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    alignment: Alignment.center,
                    child: Text(s.t('noLocationRecorded')),
                  )
                : SafetyMap(
                    path: i.path,
                    pathColor: color,
                    initialZoom: 15,
                    markers: [
                      if (start != null && i.path.length > 1)
                        Marker(
                          point: toLatLng(start),
                          width: 30,
                          height: 30,
                          child: const PinMarker(
                            icon: Icons.trip_origin,
                            color: Colors.black54,
                          ),
                        ),
                      if (end != null)
                        Marker(
                          point: toLatLng(end),
                          width: 34,
                          height: 34,
                          child: PinMarker(icon: incidentIcon(i), color: color),
                        ),
                    ],
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Row(
                  Icons.flag_outlined,
                  s.t('status'),
                  incidentStatusLabel(i, s),
                ),
                _Row(
                  Icons.play_circle_outline,
                  s.t('started'),
                  formatDateTime(context, i.startedAt),
                ),
                if (i.endedAt != null)
                  _Row(
                    Icons.stop_circle_outlined,
                    s.t('ended'),
                    formatDateTime(context, i.endedAt!),
                  ),
                if (i.destination != null)
                  _Row(
                    Icons.place_outlined,
                    s.t('destination'),
                    i.destination!,
                  ),
                if (i.deadline != null)
                  _Row(
                    Icons.timer_outlined,
                    s.t('checkInDeadline'),
                    formatDateTime(context, i.deadline!),
                  ),
                if (end != null)
                  _Row(
                    Icons.my_location,
                    s.t('lastLocation'),
                    '${end.coordinates} (${formatTime(context, end.time)})',
                  ),
                _Row(Icons.timeline, s.t('pointsRecorded'), '${i.path.length}'),
                if (i.tracking != null)
                  _Row(Icons.public, s.t('liveMapLink'), i.tracking!.viewUrl),
                const SizedBox(height: 16),
                Text(
                  s.t('messages'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                if (i.deliveries.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(s.t('noMessagesSent')),
                  ),
                for (final d in i.deliveries.reversed)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      deliveryStatusIcon(d.status),
                      color: deliveryStatusColor(d.status),
                    ),
                    title: Text('${d.contactName} · ${formatPhone(d.phone)}'),
                    subtitle: Text(
                      '${deliveryKindLabel(d.kind, s)} · ${deliveryStatusLabel(d, s)}\n${formatDateTime(context, d.at)}',
                    ),
                    isThreeLine: true,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.icon, this.label, this.value);
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 20,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: SelectableText(value)),
        ],
      ),
    );
  }
}
