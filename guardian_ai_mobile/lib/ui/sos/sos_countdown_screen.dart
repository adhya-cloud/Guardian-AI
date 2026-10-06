import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../models/incident.dart';
import '../../state/safety_controller.dart';
import 'sos_active_screen.dart';

/// Full-screen countdown giving the user a chance to cancel an accidental SOS.
class SosCountdownScreen extends StatefulWidget {
  const SosCountdownScreen({super.key, required this.trigger});
  final SosTrigger trigger;

  @override
  State<SosCountdownScreen> createState() => _SosCountdownScreenState();
}

class _SosCountdownScreenState extends State<SosCountdownScreen> {
  late int _remaining = context
      .read<SafetyController>()
      .settings
      .countdownSeconds;
  Timer? _timer;
  bool _fired = false;

  @override
  void initState() {
    super.initState();
    HapticFeedback.heavyImpact();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_remaining <= 1) {
        _fire();
      } else {
        HapticFeedback.heavyImpact();
        setState(() => _remaining--);
      }
    });
  }

  void _fire() {
    if (_fired) return;
    _fired = true;
    _timer?.cancel();
    final c = context.read<SafetyController>();
    unawaited(c.triggerSos(trigger: widget.trigger));
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const SosActiveScreen()),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final c = context.watch<SafetyController>();
    final total = c.settings.countdownSeconds;
    return Scaffold(
      backgroundColor: AppColors.sos,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Text(
                widget.trigger == SosTrigger.shake
                    ? s.t('shakeDetected')
                    : s.t('sendingSosIn'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Center(
                child: SizedBox(
                  width: 220,
                  height: 220,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      TweenAnimationBuilder<double>(
                        key: ValueKey(_remaining),
                        tween: Tween(
                          begin: _remaining / total,
                          end: (_remaining - 1) / total,
                        ),
                        duration: const Duration(seconds: 1),
                        builder: (_, v, _) => CircularProgressIndicator(
                          value: v,
                          strokeWidth: 10,
                          color: Colors.white,
                          backgroundColor: Colors.white24,
                        ),
                      ),
                      Center(
                        child: Text(
                          '$_remaining',
                          key: const ValueKey('sos_countdown_value'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 96,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                c.sosContacts.isEmpty
                    ? s.t('countdownNoContacts')
                    : s.t(c.autoSms ? 'countdownBody' : 'countdownBodyLite', {
                        'n': c.sosContacts.length,
                      }),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
              const Spacer(),
              SizedBox(
                height: 64,
                child: FilledButton(
                  key: const ValueKey('sos_cancel'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.sos,
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    s.t('cancelSos'),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                key: const ValueKey('sos_send_now'),
                onPressed: _fire,
                child: Text(
                  s.t('sendNow'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    decoration: TextDecoration.underline,
                    decorationColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
