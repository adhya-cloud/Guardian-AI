import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/helplines.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../models/incident.dart';
import '../../state/safety_controller.dart';
import '../settings/sms_access.dart';
import '../sos/sos_active_screen.dart';
import '../tools/fake_call.dart';
import '../tools/helplines_screen.dart';
import '../tools/journey_sheet.dart';
import '../tools/live_share_sheet.dart';
import '../widgets/common.dart';
import '../widgets/labels.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.onOpenMap, required this.onSos});
  final VoidCallback onOpenMap;
  final VoidCallback onSos;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final c = context.watch<SafetyController>();
    final sos = c.activeSos;
    final journey = c.activeJourney;
    final live = c.activeLiveShare;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            _Header(
              name: c.profile?.name ?? '',
              protected: c.sosContacts.isNotEmpty,
            ),
            const SizedBox(height: 16),
            const SmsAccessBanner(),
            if (sos != null) _SosActiveCard(incident: sos),
            if (journey != null) _JourneyCard(incident: journey),
            if (live != null) _LiveShareCard(incident: live),
            if (sos == null) ...[
              const SizedBox(height: 8),
              Center(
                child: SosButton(
                  onPressed: onSos,
                  contactCount: c.sosContacts.length,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                c.sosContacts.isEmpty
                    ? s.t('sosNeedsContacts')
                    : s.t(c.autoSms ? 'sosHint' : 'sosHintLite', {
                        'n': c.sosContacts.length,
                        'sec': c.settings.countdownSeconds,
                      }),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: c.sosContacts.isEmpty
                      ? AppColors.sos
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              if (c.settings.shakeToSos)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    s.t('shakeHint'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
            SectionHeader(s.t('quickActions')),
            const _QuickActions(),
            SectionHeader(
              s.t('helplines'),
              trailing: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const HelplinesScreen(),
                  ),
                ),
                child: Text(s.t('seeAll')),
              ),
            ),
            SizedBox(
              height: 92,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final h in indiaHelplines.take(5))
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _HelplineChip(
                        number: h.number,
                        label: s.t(h.titleKey),
                        icon: h.icon,
                        color: h.color,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: AppColors.police,
                  child: Icon(Icons.local_police, color: Colors.white),
                ),
                title: Text(s.t('nearbyHelp')),
                subtitle: Text(s.t('nearbyHelpBody')),
                trailing: const Icon(Icons.chevron_right),
                onTap: onOpenMap,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.name, required this.protected});
  final String name;
  final bool protected;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final hour = DateTime.now().hour;
    final greeting = hour >= 5 && hour < 12
        ? s.t('goodMorning')
        : hour >= 12 && hour < 17
        ? s.t('goodAfternoon')
        : s.t('goodEvening');
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$greeting, ${name.split(' ').first}',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    protected ? Icons.verified_user : Icons.warning_amber,
                    size: 16,
                    color: protected ? AppColors.success : AppColors.journey,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      protected
                          ? s.t('statusProtected')
                          : s.t('statusNoContacts'),
                      style: TextStyle(
                        color: protected
                            ? AppColors.success
                            : AppColors.journey,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The big red SOS button with a gentle pulse.
class SosButton extends StatefulWidget {
  const SosButton({
    super.key,
    required this.onPressed,
    required this.contactCount,
  });
  final VoidCallback onPressed;
  final int contactCount;

  @override
  State<SosButton> createState() => _SosButtonState();
}

class _SosButtonState extends State<SosButton>
    with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    const size = 190.0;
    return Semantics(
      button: true,
      label: s.t('sosButtonLabel'),
      child: SizedBox(
        width: size + 40,
        height: size + 40,
        child: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedBuilder(
              animation: _pulse,
              builder: (_, _) => Container(
                width: size + 40 * _pulse.value,
                height: size + 40 * _pulse.value,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.sos.withValues(
                    alpha: 0.25 * (1 - _pulse.value),
                  ),
                ),
              ),
            ),
            Material(
              color: AppColors.sos,
              shape: const CircleBorder(),
              elevation: 8,
              shadowColor: AppColors.sos.withValues(alpha: 0.6),
              child: InkWell(
                key: const ValueKey('sos_button'),
                customBorder: const CircleBorder(),
                onTap: widget.onPressed,
                child: SizedBox(
                  width: size,
                  height: size,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'SOS',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 52,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                        ),
                      ),
                      Text(
                        s.t('tapForHelp'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
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

/// Rebuilds every second (for countdowns).
class _Ticking extends StatefulWidget {
  const _Ticking({required this.builder});
  final WidgetBuilder builder;

  @override
  State<_Ticking> createState() => _TickingState();
}

class _TickingState extends State<_Ticking> {
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context);
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({
    required this.color,
    required this.icon,
    required this.title,
    required this.body,
    required this.actions,
    this.onTap,
  });
  final Color color;
  final IconData icon;
  final String title;
  final Widget body;
  final List<Widget> actions;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: color,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: DefaultTextStyle.merge(
            style: const TextStyle(color: Colors.white),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, color: Colors.white),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    if (onTap != null)
                      const Icon(Icons.chevron_right, color: Colors.white),
                  ],
                ),
                const SizedBox(height: 8),
                body,
                const SizedBox(height: 12),
                Wrap(spacing: 8, runSpacing: 8, children: actions),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

ButtonStyle _onColor(Color color) => FilledButton.styleFrom(
  backgroundColor: Colors.white,
  foregroundColor: color,
  minimumSize: const Size(0, 44),
);

ButtonStyle _outlineWhite() => OutlinedButton.styleFrom(
  foregroundColor: Colors.white,
  side: const BorderSide(color: Colors.white70),
  minimumSize: const Size(0, 44),
);

class _SosActiveCard extends StatelessWidget {
  const _SosActiveCard({required this.incident});
  final Incident incident;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final alerts = incident.deliveries.where(
      (d) => d.kind == DeliveryKind.sosAlert,
    );
    final sent = alerts.where((d) => d.status == DeliveryStatus.sent).length;
    final awaitingSend =
        sent == 0 && alerts.any((d) => d.status == DeliveryStatus.composer);
    void open() => Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => const SosActiveScreen()),
    );
    return _SessionCard(
      color: AppColors.sos,
      icon: Icons.sos,
      title: s.t('sosActive'),
      onTap: open,
      body: Text(
        awaitingSend
            ? s.t('sosActiveCardBodyComposer')
            : s.t('sosActiveCardBody', {
                'sent': sent,
                'total': incident.recipientIds.length,
              }),
      ),
      actions: [
        FilledButton(
          style: _onColor(AppColors.sos),
          onPressed: open,
          child: Text(s.t('open')),
        ),
      ],
    );
  }
}

class _JourneyCard extends StatelessWidget {
  const _JourneyCard({required this.incident});
  final Incident incident;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final c = context.read<SafetyController>();
    return _Ticking(
      builder: (context) {
        final left = incident.deadline!.difference(DateTime.now());
        final urgent = left <= SafetyController.journeyReminderLead;
        return _SessionCard(
          color: urgent ? AppColors.sosDark : AppColors.journey,
          icon: Icons.route,
          title: urgent ? s.t('journeyAreYouSafe') : s.t('journeyActive'),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                formatCountdown(left),
                key: const ValueKey('journey_countdown'),
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                [
                  if (incident.destination != null)
                    s.t('toDestination', {'place': incident.destination!}),
                  s.t('checkInBy', {
                    'time': formatTime(context, incident.deadline!),
                  }),
                ].join(' · '),
              ),
              const SizedBox(height: 4),
              Text(
                s.t(c.autoSms ? 'journeyAutoAlert' : 'journeyAutoAlertLite'),
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
            ],
          ),
          actions: [
            FilledButton.icon(
              style: _onColor(AppColors.journey),
              onPressed: () async {
                await c.finishJourney(arrived: true);
                if (context.mounted) {
                  showSnack(context, s.t('journeyArrivedSnack'));
                }
              },
              icon: const Icon(Icons.check_circle),
              label: Text(s.t('imSafeArrived')),
            ),
            OutlinedButton(
              style: _outlineWhite(),
              onPressed: () => c.extendJourney(const Duration(minutes: 15)),
              child: Text(s.t('plus15')),
            ),
            OutlinedButton(
              style: _outlineWhite(),
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(s.t('cancelJourneyTitle')),
                    content: Text(s.t('cancelJourneyBody')),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text(s.t('keepRunning')),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text(s.t('cancelJourney')),
                      ),
                    ],
                  ),
                );
                if (ok == true) await c.finishJourney(arrived: false);
              },
              child: Text(s.t('cancel')),
            ),
          ],
        );
      },
    );
  }
}

class _LiveShareCard extends StatelessWidget {
  const _LiveShareCard({required this.incident});
  final Incident incident;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final c = context.read<SafetyController>();
    return _Ticking(
      builder: (context) {
        final left = incident.endsAt!.difference(DateTime.now());
        return _SessionCard(
          color: AppColors.live,
          icon: Icons.share_location,
          title: s.t('liveSharingOn'),
          body: Text(
            '${s.t('liveSharingWith', {'n': incident.recipientIds.length})}\n'
            '${s.t('endsIn', {'time': formatCountdown(left)})}'
            '${incident.tracking != null ? '\n${s.t('viaLiveMap')}' : '\n${(c.autoSms ? s.t('viaSms', {'n': c.settings.updateIntervalMinutes}) : s.t('viaSmsOnce'))}'}',
          ),
          actions: [
            FilledButton.icon(
              style: _onColor(AppColors.live),
              onPressed: () => c.stopLiveShare(),
              icon: const Icon(Icons.stop_circle),
              label: Text(s.t('stopSharing')),
            ),
            if (incident.tracking != null)
              OutlinedButton.icon(
                style: _outlineWhite(),
                onPressed: () => SharePlus.instance.share(
                  ShareParams(text: incident.tracking!.viewUrl),
                ),
                icon: const Icon(Icons.link),
                label: Text(s.t('shareLink')),
              ),
          ],
        );
      },
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  Future<void> _shareOnce(BuildContext context) async {
    final s = AppStrings.of(context);
    final c = context.read<SafetyController>();
    showSnack(context, s.t('gettingLocation'));
    final text = await c.locationShareText();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    if (text == null) {
      showSnack(context, s.t('locationUnavailable'));
      return;
    }
    await SharePlus.instance.share(ShareParams(text: text));
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final c = context.watch<SafetyController>();
    final tiles = <_ActionTile>[
      _ActionTile(
        icon: Icons.share_location,
        color: AppColors.live,
        label: s.t('actionLiveShare'),
        active: c.activeLiveShare != null,
        onTap: c.activeLiveShare != null
            ? null
            : () => showLiveShareSheet(context),
      ),
      _ActionTile(
        icon: Icons.route,
        color: AppColors.journey,
        label: s.t('actionJourney'),
        active: c.activeJourney != null,
        onTap: c.activeJourney != null ? null : () => showJourneySheet(context),
      ),
      _ActionTile(
        icon: Icons.phone_callback,
        color: AppColors.brand,
        label: s.t('actionFakeCall'),
        onTap: () => showFakeCallSheet(context),
      ),
      _ActionTile(
        icon: Icons.campaign,
        color: AppColors.sos,
        label: c.sirenOn ? s.t('actionSirenStop') : s.t('actionSiren'),
        active: c.sirenOn,
        onTap: () => c.setSiren(!c.sirenOn),
      ),
      if (c.capabilities.torch)
        _ActionTile(
          icon: Icons.flashlight_on,
          color: const Color(0xFF6941C6),
          label: c.strobeOn ? s.t('actionStrobeStop') : s.t('actionStrobe'),
          active: c.strobeOn,
          onTap: () => c.setStrobe(!c.strobeOn),
        ),
      _ActionTile(
        icon: Icons.my_location,
        color: const Color(0xFF0E9384),
        label: s.t('actionShareOnce'),
        onTap: () => _shareOnce(context),
      ),
    ];
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 0.95,
      children: tiles,
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.color,
    required this.label,
    this.onTap,
    this.active = false,
  });
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback? onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: active ? color : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: active
                    ? Colors.white24
                    : color.withValues(alpha: 0.12),
                child: Icon(icon, color: active ? Colors.white : color),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: active ? Colors.white : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HelplineChip extends StatelessWidget {
  const _HelplineChip({
    required this.number,
    required this.label,
    required this.icon,
    required this.color,
  });
  final String number;
  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 104,
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => callHelpline(context, number, label),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, color: color, size: 20),
                    const Spacer(),
                    Icon(Icons.call, size: 16, color: color),
                  ],
                ),
                const Spacer(),
                Text(
                  number,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
