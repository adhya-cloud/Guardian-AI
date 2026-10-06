import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/strings.dart';
import '../../services/device_bridge.dart';
import '../app.dart';
import '../widgets/common.dart' show DurationChips, SheetScaffold;
import '../widgets/labels.dart';

/// A fake incoming call to help the user leave an uncomfortable situation.
Future<void> showFakeCallSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _FakeCallSheet(),
    );

Timer? _pendingFakeCall;

class _FakeCallSheet extends StatefulWidget {
  const _FakeCallSheet();

  @override
  State<_FakeCallSheet> createState() => _FakeCallSheetState();
}

class _FakeCallSheetState extends State<_FakeCallSheet> {
  static const _delays = [
    Duration.zero,
    Duration(seconds: 10),
    Duration(seconds: 30),
    Duration(minutes: 1),
    Duration(minutes: 5),
  ];
  late final _caller = TextEditingController(
    text: AppStrings.of(context).t('fakeCallDefaultCaller'),
  );
  Duration _delay = const Duration(seconds: 10);

  @override
  void dispose() {
    _caller.dispose();
    super.dispose();
  }

  void _schedule() {
    final s = AppStrings.of(context);
    final device = context.read<DeviceBridge>();
    final name = _caller.text.trim().isEmpty
        ? s.t('fakeCallDefaultCaller')
        : _caller.text.trim();
    _pendingFakeCall?.cancel();
    void ring() {
      final nav = navigatorKey.currentState;
      if (nav == null) return;
      nav.push(
        PageRouteBuilder<void>(
          opaque: true,
          pageBuilder: (_, _, _) =>
              IncomingCallScreen(caller: name, device: device),
          transitionsBuilder: (_, a, _, child) =>
              FadeTransition(opacity: a, child: child),
        ),
      );
    }

    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    if (_delay == Duration.zero) {
      ring();
    } else {
      _pendingFakeCall = Timer(_delay, ring);
      final when = _delay.inSeconds < 60
          ? s.t('secondsShort', {'n': _delay.inSeconds})
          : formatDuration(_delay, s);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(s.t('fakeCallScheduled', {'time': when}))),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return SheetScaffold(
      title: s.t('fakeCallTitle'),
      subtitle: s.t('fakeCallSubtitle'),
      children: [
        TextField(
          controller: _caller,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: s.t('callerName'),
            prefixIcon: const Icon(Icons.person_outline),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          s.t('ringIn'),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        DurationChips(
          options: _delays,
          value: _delay,
          label: (d) => d == Duration.zero
              ? s.t('now')
              : d.inSeconds < 60
              ? s.t('secondsShort', {'n': d.inSeconds})
              : formatDuration(d, s),
          onChanged: (d) => setState(() => _delay = d),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: _schedule,
          icon: const Icon(Icons.phone_callback),
          label: Text(s.t('scheduleCall')),
        ),
      ],
    );
  }
}

class IncomingCallScreen extends StatefulWidget {
  const IncomingCallScreen({
    super.key,
    required this.caller,
    required this.device,
  });
  final String caller;
  final DeviceBridge device;

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen> {
  bool _answered = false;
  final _watch = Stopwatch();
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    widget.device.startRingtone();
  }

  void _answer() {
    widget.device.stopRingtone();
    HapticFeedback.mediumImpact();
    setState(() => _answered = true);
    _watch.start();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  void _hangUp() {
    widget.device.stopRingtone();
    Navigator.pop(context);
  }

  @override
  void dispose() {
    widget.device.stopRingtone();
    _clock?.cancel();
    super.dispose();
  }

  Widget _roundButton({
    required Color color,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Key? key,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: color,
          shape: const CircleBorder(),
          child: InkWell(
            key: key,
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: 72,
              height: 72,
              child: Icon(icon, color: Colors.white, size: 32),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white70)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final initials = widget.caller.trim().isEmpty
        ? '?'
        : widget.caller.trim().characters.first.toUpperCase();
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFF101828),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF1D2939), Color(0xFF0C111D)],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 56),
                Text(
                  _answered
                      ? formatCountdown(_watch.elapsed)
                      : s.t('incomingCall'),
                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.caller,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  s.t('mobile'),
                  style: const TextStyle(color: Colors.white60),
                ),
                const SizedBox(height: 40),
                CircleAvatar(
                  radius: 56,
                  backgroundColor: const Color(0xFF344054),
                  child: Text(
                    initials,
                    style: const TextStyle(color: Colors.white, fontSize: 44),
                  ),
                ),
                const Spacer(),
                if (_answered) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: const [
                      Icon(Icons.mic_off, color: Colors.white70, size: 30),
                      Icon(Icons.dialpad, color: Colors.white70, size: 30),
                      Icon(Icons.volume_up, color: Colors.white70, size: 30),
                    ],
                  ),
                  const SizedBox(height: 48),
                  _roundButton(
                    color: const Color(0xFFD92D20),
                    icon: Icons.call_end,
                    label: s.t('endCall'),
                    onTap: _hangUp,
                  ),
                ] else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _roundButton(
                        color: const Color(0xFFD92D20),
                        icon: Icons.call_end,
                        label: s.t('decline'),
                        onTap: _hangUp,
                      ),
                      _roundButton(
                        key: const ValueKey('fake_accept'),
                        color: const Color(0xFF12B76A),
                        icon: Icons.call,
                        label: s.t('accept'),
                        onTap: _answer,
                      ),
                    ],
                  ),
                const SizedBox(height: 56),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
