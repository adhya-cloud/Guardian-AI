import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/strings.dart';
import '../models/incident.dart';
import '../services/shake_detector.dart';
import '../state/safety_controller.dart';
import 'contacts/contacts_screen.dart';
import 'history/history_screen.dart';
import 'home/home_screen.dart';
import 'map/map_screen.dart';
import 'settings/settings_screen.dart';
import 'sos/sos_countdown_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, this.accelerometer});
  final Stream<(double, double, double)> Function()? accelerometer;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int _tab = 0;
  ShakeDetector? _shake;
  bool _countdownOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncShake());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncShake();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    // Sensor events are only delivered to foreground apps; re-arm on resume.
    _syncShake(force: true);
    // The user may have changed the SMS permission in system settings.
    context.read<SafetyController>().refreshSmsAccess();
  }

  void _syncShake({bool force = false}) {
    final enabled =
        widget.accelerometer != null &&
        context.read<SafetyController>().settings.shakeToSos;
    if (!enabled) {
      _shake?.stop();
      _shake = null;
      return;
    }
    if (_shake != null && !force) return;
    _shake?.stop();
    _shake = ShakeDetector(onShake: _onShake)..listen(widget.accelerometer!());
  }

  void _onShake() {
    final c = context.read<SafetyController>();
    if (_countdownOpen || c.activeSos != null || !mounted) return;
    openSosCountdown(SosTrigger.shake);
  }

  Future<void> openSosCountdown(SosTrigger trigger) async {
    _countdownOpen = true;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => SosCountdownScreen(trigger: trigger),
      ),
    );
    _countdownOpen = false;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _shake?.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    // Re-evaluate shake detection when the setting changes.
    context.select<SafetyController, bool>((c) => c.settings.shakeToSos);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncShake();
    });

    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: [
          HomeScreen(
            onOpenMap: () => setState(() => _tab = 1),
            onSos: () => openSosCountdown(SosTrigger.button),
          ),
          MapScreen(active: _tab == 1),
          const ContactsScreen(),
          const HistoryScreen(),
          const SettingsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.shield_outlined),
            selectedIcon: const Icon(Icons.shield),
            label: s.t('tabHome'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.map_outlined),
            selectedIcon: const Icon(Icons.map),
            label: s.t('tabMap'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.people_outline),
            selectedIcon: const Icon(Icons.people),
            label: s.t('tabContacts'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.history),
            label: s.t('tabHistory'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings),
            label: s.t('tabSettings'),
          ),
        ],
      ),
    );
  }
}
