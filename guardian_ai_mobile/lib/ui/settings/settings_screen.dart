import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/phone.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../models/profile.dart';
import '../../services/tracking_client.dart';
import '../../state/safety_controller.dart';
import '../tools/helplines_screen.dart';
import '../widgets/common.dart';
import 'permissions_section.dart';
import 'sms_access.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<T?> _choose<T>(
    BuildContext context,
    String title,
    List<(T, String)> options,
    T current,
  ) {
    return showDialog<T>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(title),
        children: [
          RadioGroup<T>(
            groupValue: current,
            onChanged: (v) => Navigator.pop(ctx, v),
            child: Column(
              children: [
                for (final (value, label) in options)
                  RadioListTile<T>(value: value, title: Text(label)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final c = context.watch<SafetyController>();
    final profile = c.profile!;
    final st = c.settings;

    String autoCallLabel(AutoCall a) => switch (a) {
      AutoCall.off => s.t('autoCallOff'),
      AutoCall.primaryContact => s.t('autoCallPrimary'),
      AutoCall.emergencyNumber => s.t('autoCallEmergency', {
        'number': profile.emergencyNumber,
      }),
    };

    return Scaffold(
      appBar: AppBar(title: Text(s.t('settingsTitle'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          SectionHeader(s.t('profileSection')),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: Text(profile.name),
                  subtitle: Text(
                    profile.medicalInfo.isEmpty
                        ? s.t('editProfileHint')
                        : profile.medicalInfo,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const ProfileEditScreen(),
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.translate),
                  title: Text(s.t('language')),
                  subtitle: Text(
                    profile.language == 'hi' ? 'हिन्दी' : 'English',
                  ),
                  onTap: () async {
                    final v = await _choose(context, s.t('language'), const [
                      ('en', 'English'),
                      ('hi', 'हिन्दी'),
                    ], profile.language);
                    if (v != null) {
                      await c.saveProfile(profile.copyWith(language: v));
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.emergency_outlined),
                  title: Text(s.t('emergencyNumber')),
                  subtitle: Text(profile.emergencyNumber),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const ProfileEditScreen(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SectionHeader(s.t('sosSection')),
          const SmsAccessBanner(),
          if (!c.capabilities.directSms)
            Card(
              margin: const EdgeInsets.only(bottom: 10),
              color: AppColors.journey.withValues(alpha: 0.1),
              child: ListTile(
                leading: const Icon(
                  Icons.info_outline,
                  color: AppColors.journey,
                ),
                title: Text(s.t('editionLiteNote')),
              ),
            ),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.timer_outlined),
                  title: Text(s.t('countdown')),
                  subtitle: Text(
                    s.t('secondsLong', {'n': st.countdownSeconds}),
                  ),
                  onTap: () async {
                    final v = await _choose(context, s.t('countdown'), [
                      for (final n in [3, 5, 10])
                        (n, s.t('secondsLong', {'n': n})),
                    ], st.countdownSeconds);
                    if (v != null) {
                      await c.saveSettings(st.copyWith(countdownSeconds: v));
                    }
                  },
                ),
                if (c.capabilities.directSms)
                  ListTile(
                    leading: const Icon(Icons.update),
                    title: Text(s.t('updateInterval')),
                    subtitle: Text(
                      s.t('everyNMinutes', {'n': st.updateIntervalMinutes}),
                    ),
                    onTap: () async {
                      final v = await _choose(context, s.t('updateInterval'), [
                        for (final n in [2, 5, 10, 15])
                          (n, s.t('everyNMinutes', {'n': n})),
                      ], st.updateIntervalMinutes);
                      if (v != null) {
                        await c.saveSettings(
                          st.copyWith(updateIntervalMinutes: v),
                        );
                      }
                    },
                  ),
                ListTile(
                  leading: const Icon(Icons.phone_forwarded_outlined),
                  title: Text(s.t('autoCall')),
                  subtitle: Text(autoCallLabel(st.autoCall)),
                  onTap: () async {
                    final v = await _choose(context, s.t('autoCall'), [
                      for (final a in AutoCall.values) (a, autoCallLabel(a)),
                    ], st.autoCall);
                    if (v != null) {
                      await c.saveSettings(st.copyWith(autoCall: v));
                    }
                  },
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.vibration),
                  title: Text(s.t('shakeToSos')),
                  subtitle: Text(s.t('shakeToSosHelp')),
                  value: st.shakeToSos,
                  onChanged: (v) => c.saveSettings(st.copyWith(shakeToSos: v)),
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.campaign_outlined),
                  title: Text(s.t('sirenOnSos')),
                  subtitle: Text(s.t('sirenOnSosHelp')),
                  value: st.sirenOnSos,
                  onChanged: (v) => c.saveSettings(st.copyWith(sirenOnSos: v)),
                ),
              ],
            ),
          ),
          SectionHeader(s.t('journeySection')),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.outgoing_mail),
                  title: Text(s.t('notifyJourneyStart')),
                  value: st.notifyJourneyStart,
                  onChanged: (v) =>
                      c.saveSettings(st.copyWith(notifyJourneyStart: v)),
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.where_to_vote_outlined),
                  title: Text(s.t('notifyArrival')),
                  value: st.notifyArrival,
                  onChanged: (v) =>
                      c.saveSettings(st.copyWith(notifyArrival: v)),
                ),
              ],
            ),
          ),
          SectionHeader(s.t('liveMapSection')),
          Card(
            child: ListTile(
              leading: const Icon(Icons.public),
              title: Text(s.t('trackingServer')),
              subtitle: Text(
                st.hasTrackingServer
                    ? st.trackingServerUrl
                    : s.t('trackingServerOff'),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                showDragHandle: true,
                builder: (_) => const _TrackingServerSheet(),
              ),
            ),
          ),
          SectionHeader(s.t('permissionsTitle')),
          const PermissionsList(),
          SectionHeader(s.t('moreSection')),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.support_agent),
                  title: Text(s.t('helplinesTitle')),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const HelplinesScreen(),
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(
                    Icons.delete_forever_outlined,
                    color: AppColors.sos,
                  ),
                  title: Text(
                    s.t('deleteAllData'),
                    style: const TextStyle(color: AppColors.sos),
                  ),
                  subtitle: Text(s.t('deleteAllDataHelp')),
                  onTap: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text(s.t('deleteAllData')),
                        content: Text(s.t('deleteAllDataConfirm')),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: Text(s.t('cancel')),
                          ),
                          FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.sos,
                            ),
                            onPressed: () => Navigator.pop(ctx, true),
                            child: Text(s.t('delete')),
                          ),
                        ],
                      ),
                    );
                    if (ok == true) await c.deleteAllData();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              s.t(c.capabilities.directSms ? 'aboutLine' : 'aboutLineLite'),
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  late final Profile _p = context.read<SafetyController>().profile!;
  late final _name = TextEditingController(text: _p.name);
  late final _number = TextEditingController(text: _p.emergencyNumber);
  late final _medical = TextEditingController(text: _p.medicalInfo);

  @override
  void dispose() {
    _name.dispose();
    _number.dispose();
    _medical.dispose();
    super.dispose();
  }

  bool get _valid =>
      _name.text.trim().isNotEmpty && normalizeDialNumber(_number.text) != null;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s.t('editProfile'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: s.t('yourName'),
              prefixIcon: const Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _number,
            keyboardType: TextInputType.phone,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: s.t('emergencyNumber'),
              helperText: s.t('emergencyNumberHelp'),
              helperMaxLines: 2,
              errorText: normalizeDialNumber(_number.text) == null
                  ? s.t('invalidNumber')
                  : null,
              prefixIcon: const Icon(Icons.emergency_outlined),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _medical,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: s.t('medicalInfo'),
              hintText: s.t('medicalInfoHint'),
              helperText: s.t('medicalInfoHelp'),
              helperMaxLines: 2,
              prefixIcon: const Icon(Icons.medical_information_outlined),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: !_valid
                ? null
                : () async {
                    final nav = Navigator.of(context);
                    await context.read<SafetyController>().saveProfile(
                      _p.copyWith(
                        name: _name.text.trim(),
                        emergencyNumber: normalizeDialNumber(_number.text),
                        medicalInfo: _medical.text.trim(),
                      ),
                    );
                    nav.pop();
                  },
            child: Text(s.t('save')),
          ),
        ],
      ),
    );
  }
}

class _TrackingServerSheet extends StatefulWidget {
  const _TrackingServerSheet();

  @override
  State<_TrackingServerSheet> createState() => _TrackingServerSheetState();
}

class _TrackingServerSheetState extends State<_TrackingServerSheet> {
  late final _url = TextEditingController(
    text: context.read<SafetyController>().settings.trackingServerUrl,
  );
  bool? _ok;
  bool _testing = false;

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  bool get _valid {
    final t = _url.text.trim();
    if (t.isEmpty) return true;
    final u = Uri.tryParse(t);
    return u != null &&
        (u.scheme == 'https' || u.scheme == 'http') &&
        u.host.isNotEmpty;
  }

  Future<void> _test() async {
    setState(() {
      _testing = true;
      _ok = null;
    });
    final ok = await TrackingClient(_url.text).ping();
    if (mounted) {
      setState(() {
        _testing = false;
        _ok = ok;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final c = context.read<SafetyController>();
    return SheetScaffold(
      title: s.t('trackingServer'),
      subtitle: s.t('trackingServerHelp'),
      children: [
        TextField(
          controller: _url,
          keyboardType: TextInputType.url,
          autocorrect: false,
          onChanged: (_) => setState(() => _ok = null),
          decoration: InputDecoration(
            labelText: s.t('serverUrl'),
            hintText: 'https://track.example.org',
            errorText: _valid ? null : s.t('invalidUrl'),
            prefixIcon: const Icon(Icons.link),
          ),
        ),
        const SizedBox(height: 8),
        if (_ok != null)
          Row(
            children: [
              Icon(
                _ok! ? Icons.check_circle : Icons.error,
                color: _ok! ? AppColors.success : AppColors.sos,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(_ok! ? s.t('serverOk') : s.t('serverUnreachable')),
              ),
            ],
          ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: !_valid || _url.text.trim().isEmpty || _testing
                    ? null
                    : _test,
                child: _testing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(s.t('testConnection')),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton(
                onPressed: !_valid
                    ? null
                    : () async {
                        final nav = Navigator.of(context);
                        await c.saveSettings(
                          c.settings.copyWith(
                            trackingServerUrl: _url.text.trim(),
                          ),
                        );
                        nav.pop();
                      },
                child: Text(s.t('save')),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
