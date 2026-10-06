import 'package:flutter/material.dart';

import '../../core/phone.dart';
import '../../core/strings.dart';
import '../../models/contact.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                letterSpacing: 0.3,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class ContactAvatar extends StatelessWidget {
  const ContactAvatar(
    this.name, {
    super.key,
    this.primary = false,
    this.radius = 20,
  });
  final String name;
  final bool primary;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final initials = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .take(2)
        .map((p) => p.characters.first.toUpperCase())
        .join();
    return CircleAvatar(
      radius: radius,
      backgroundColor: primary ? scheme.primary : scheme.secondaryContainer,
      foregroundColor: primary ? scheme.onPrimary : scheme.onSecondaryContainer,
      child: Text(
        initials.isEmpty ? '?' : initials,
        style: TextStyle(fontWeight: FontWeight.w700, fontSize: radius * 0.75),
      ),
    );
  }
}

/// Multi-select list of trusted contacts used by the journey and live-share sheets.
class ContactSelector extends StatelessWidget {
  const ContactSelector({
    super.key,
    required this.contacts,
    required this.selected,
    required this.onChanged,
  });

  final List<TrustedContact> contacts;
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    if (contacts.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          s.t('noContactsYet'),
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      );
    }
    return Column(
      children: [
        for (final c in contacts)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: selected.contains(c.id),
            onChanged: (v) {
              final next = {...selected};
              v == true ? next.add(c.id) : next.remove(c.id);
              onChanged(next);
            },
            secondary: ContactAvatar(c.name, primary: c.isPrimary, radius: 16),
            title: Text(c.name),
            subtitle: Text(formatPhone(c.phone)),
          ),
      ],
    );
  }
}

/// A row of selectable duration chips.
class DurationChips extends StatelessWidget {
  const DurationChips({
    super.key,
    required this.options,
    required this.value,
    required this.label,
    required this.onChanged,
  });

  final List<Duration> options;
  final Duration value;
  final String Function(Duration) label;
  final ValueChanged<Duration> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final d in options)
          ChoiceChip(
            label: Text(label(d)),
            selected: d == value,
            onSelected: (_) => onChanged(d),
          ),
      ],
    );
  }
}

/// Bottom-sheet scaffold with a grab handle and title.
class SheetScaffold extends StatelessWidget {
  const SheetScaffold({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
  });
  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

void showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
