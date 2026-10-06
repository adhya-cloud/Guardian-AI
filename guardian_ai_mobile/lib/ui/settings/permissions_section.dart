import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../services/device_bridge.dart';
import '../../services/permissions.dart';
import '../../state/safety_controller.dart';
import 'sms_access.dart';

/// Lists each permission with why it's needed and an Allow button.
class PermissionsList extends StatefulWidget {
  const PermissionsList({super.key});

  @override
  State<PermissionsList> createState() => _PermissionsListState();
}

class _PermissionsListState extends State<PermissionsList>
    with WidgetsBindingObserver {
  final _states = <AppPermission, PermissionState>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final service = context.read<PermissionService>();
    final c = context.read<SafetyController>();
    for (final p in AppPermission.values) {
      final st = p == AppPermission.sms
          ? await c.refreshSmsAccess()
          : await service.status(p);
      if (!mounted) return;
      setState(() => _states[p] = st);
    }
  }

  Future<void> _request(AppPermission p) async {
    final service = context.read<PermissionService>();
    final c = context.read<SafetyController>();
    switch (_states[p]) {
      case PermissionState.permanentlyDenied:
        await service.openSettings();
      default:
        final st = p == AppPermission.sms
            ? await c.requestSmsAccess(userInitiated: true)
            : await service.request(p);
        if (!mounted) return;
        setState(() => _states[p] = st);
        if (st == PermissionState.restricted) {
          await showSmsRestrictedSheet(context);
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final caps = context.select<SafetyController, DeviceCapabilities>(
      (c) => c.capabilities,
    );
    // SMS / call permissions only matter when this edition can use them.
    bool relevant(AppPermission p) =>
        (p != AppPermission.sms || caps.directSms) &&
        (p != AppPermission.phone || caps.directCall);
    final items = [
      (
        AppPermission.location,
        Icons.location_on_outlined,
        s.t('permLocation'),
        s.t('permLocationWhy'),
      ),
      (
        AppPermission.sms,
        Icons.sms_outlined,
        s.t('permSms'),
        s.t('permSmsWhy'),
      ),
      (
        AppPermission.phone,
        Icons.call_outlined,
        s.t('permPhone'),
        s.t('permPhoneWhy'),
      ),
      (
        AppPermission.notifications,
        Icons.notifications_outlined,
        s.t('permNotifications'),
        s.t('permNotificationsWhy'),
      ),
    ];
    return Column(
      children: [
        for (final (perm, icon, title, why) in items)
          if (relevant(perm) && _states[perm] != PermissionState.unavailable)
            Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                contentPadding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
                leading: Icon(icon),
                title: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(why),
                trailing: switch (_states[perm]) {
                  PermissionState.granted => const Icon(
                    Icons.check_circle,
                    color: AppColors.success,
                  ),
                  null => const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  _ => FilledButton.tonal(
                    onPressed: () => _request(perm),
                    child: Text(switch (_states[perm]) {
                      PermissionState.permanentlyDenied => s.t('openSettings'),
                      PermissionState.restricted => s.t('howToAllow'),
                      _ => s.t('allow'),
                    }),
                  ),
                },
              ),
            ),
      ],
    );
  }
}
