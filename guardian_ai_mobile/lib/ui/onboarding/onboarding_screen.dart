import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/phone.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../models/profile.dart';
import '../../state/safety_controller.dart';
import '../contacts/contact_editor.dart';
import '../settings/permissions_section.dart';
import '../widgets/common.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pages = PageController();
  final _name = TextEditingController();
  final _emergency = TextEditingController(text: '112');
  final _medical = TextEditingController();
  int _page = 0;

  @override
  void dispose() {
    _pages.dispose();
    _name.dispose();
    _emergency.dispose();
    _medical.dispose();
    super.dispose();
  }

  bool get _profileValid =>
      _name.text.trim().isNotEmpty &&
      normalizeDialNumber(_emergency.text) != null;

  void _go(int page) {
    FocusScope.of(context).unfocus();
    setState(() => _page = page);
    _pages.animateToPage(
      page,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _finish() async {
    final c = context.read<SafetyController>();
    await c.saveProfile(
      Profile(
        name: _name.text.trim(),
        language: c.onboardingLanguage,
        emergencyNumber: normalizeDialNumber(_emergency.text) ?? '112',
        medicalInfo: _medical.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                children: [
                  for (var i = 0; i < 4; i++)
                    Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: 4,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          color: i <= _page
                              ? AppColors.brand
                              : Theme.of(context).colorScheme.outlineVariant,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pages,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _WelcomePage(onNext: () => _go(1)),
                  _ProfilePage(
                    name: _name,
                    emergency: _emergency,
                    medical: _medical,
                    onChanged: () => setState(() {}),
                    onBack: () => _go(0),
                    onNext: _profileValid ? () => _go(2) : null,
                  ),
                  _ContactsPage(onBack: () => _go(1), onNext: () => _go(3)),
                  _PermissionsPage(onBack: () => _go(2), onFinish: _finish),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PageFrame extends StatelessWidget {
  const _PageFrame({required this.children, required this.actions});
  final List<Widget> children;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            children: children,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: Row(children: actions),
        ),
      ],
    );
  }
}

class _WelcomePage extends StatelessWidget {
  const _WelcomePage({required this.onNext});
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final c = context.watch<SafetyController>();
    Widget feature(IconData icon, String title, String body) => Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: AppColors.brand.withValues(alpha: 0.12),
            child: Icon(icon, color: AppColors.brand),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return _PageFrame(
      actions: [
        Expanded(
          child: FilledButton(
            onPressed: onNext,
            child: Text(s.t('getStarted')),
          ),
        ),
      ],
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'en', label: Text('English')),
              ButtonSegment(value: 'hi', label: Text('हिन्दी')),
            ],
            selected: {c.onboardingLanguage},
            onSelectionChanged: (v) => c.setOnboardingLanguage(v.first),
          ),
        ),
        const SizedBox(height: 24),
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: AppColors.brand,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(
              Icons.verified_user,
              color: Colors.white,
              size: 48,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          s.t('welcomeTitle'),
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          s.t('welcomeBody'),
          style: TextStyle(
            fontSize: 16,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 28),
        feature(Icons.sos, s.t('featureSosTitle'), s.t('featureSosBody')),
        feature(
          Icons.share_location,
          s.t('featureLiveTitle'),
          s.t('featureLiveBody'),
        ),
        feature(
          Icons.route,
          s.t('featureJourneyTitle'),
          s.t('featureJourneyBody'),
        ),
        feature(
          Icons.local_police,
          s.t('featureMapTitle'),
          s.t('featureMapBody'),
        ),
      ],
    );
  }
}

class _ProfilePage extends StatelessWidget {
  const _ProfilePage({
    required this.name,
    required this.emergency,
    required this.medical,
    required this.onChanged,
    required this.onBack,
    required this.onNext,
  });

  final TextEditingController name;
  final TextEditingController emergency;
  final TextEditingController medical;
  final VoidCallback onChanged;
  final VoidCallback onBack;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final numberInvalid =
        emergency.text.trim().isNotEmpty &&
        normalizeDialNumber(emergency.text) == null;
    return _PageFrame(
      actions: [
        TextButton(onPressed: onBack, child: Text(s.t('back'))),
        const Spacer(),
        FilledButton(onPressed: onNext, child: Text(s.t('next'))),
      ],
      children: [
        Text(
          s.t('profileTitle'),
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          s.t('profileBody'),
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
        TextField(
          key: const ValueKey('onboarding_name'),
          controller: name,
          textCapitalization: TextCapitalization.words,
          onChanged: (_) => onChanged(),
          decoration: InputDecoration(
            labelText: s.t('yourName'),
            prefixIcon: const Icon(Icons.person_outline),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: emergency,
          keyboardType: TextInputType.phone,
          onChanged: (_) => onChanged(),
          decoration: InputDecoration(
            labelText: s.t('emergencyNumber'),
            helperText: s.t('emergencyNumberHelp'),
            helperMaxLines: 2,
            errorText: numberInvalid ? s.t('invalidNumber') : null,
            prefixIcon: const Icon(Icons.emergency_outlined),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: medical,
          maxLines: 2,
          decoration: InputDecoration(
            labelText: s.t('medicalInfo'),
            hintText: s.t('medicalInfoHint'),
            helperText: s.t('medicalInfoHelp'),
            helperMaxLines: 2,
            prefixIcon: const Icon(Icons.medical_information_outlined),
          ),
        ),
      ],
    );
  }
}

class _ContactsPage extends StatelessWidget {
  const _ContactsPage({required this.onBack, required this.onNext});
  final VoidCallback onBack;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final c = context.watch<SafetyController>();
    return _PageFrame(
      actions: [
        TextButton(onPressed: onBack, child: Text(s.t('back'))),
        const Spacer(),
        FilledButton(
          onPressed: onNext,
          child: Text(c.contacts.isEmpty ? s.t('skipForNow') : s.t('next')),
        ),
      ],
      children: [
        Text(
          s.t('contactsTitle'),
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          s.t('contactsOnboardingBody'),
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 20),
        for (final contact in c.contacts)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: ContactAvatar(contact.name, primary: contact.isPrimary),
              title: Text(contact.name),
              subtitle: Text(formatPhone(contact.phone)),
              trailing: IconButton(
                tooltip: s.t('remove'),
                icon: const Icon(Icons.close),
                onPressed: () => c.removeContact(contact.id),
              ),
            ),
          ),
        const SizedBox(height: 8),
        AddContactButtons(onAdded: (_) {}),
      ],
    );
  }
}

class _PermissionsPage extends StatelessWidget {
  const _PermissionsPage({required this.onBack, required this.onFinish});
  final VoidCallback onBack;
  final Future<void> Function() onFinish;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return _PageFrame(
      actions: [
        TextButton(onPressed: onBack, child: Text(s.t('back'))),
        const Spacer(),
        FilledButton(
          key: const ValueKey('onboarding_finish'),
          onPressed: onFinish,
          child: Text(s.t('finish')),
        ),
      ],
      children: [
        Text(
          s.t('permissionsTitle'),
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          s.t('permissionsBody'),
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        const PermissionsList(),
      ],
    );
  }
}
