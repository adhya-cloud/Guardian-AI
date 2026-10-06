import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/phone.dart';
import '../../core/strings.dart';
import '../../models/contact.dart';
import '../../models/incident.dart';
import '../../state/safety_controller.dart';
import '../widgets/common.dart';
import '../widgets/labels.dart';
import 'contact_editor.dart';

class ContactsScreen extends StatelessWidget {
  const ContactsScreen({super.key});

  Future<void> _sendTest(BuildContext context, TrustedContact contact) async {
    final s = AppStrings.of(context);
    final c = context.read<SafetyController>();
    final result = await c.sendTestMessage(contact);
    if (!context.mounted || result == null) return;
    showSnack(context, switch (result.status) {
      DeliveryStatus.sent => s.t('testSent', {'name': contact.name}),
      DeliveryStatus.composer => s.t('composerOpened'),
      DeliveryStatus.failed =>
        '${s.t('testFailed')} (${deliveryStatusLabel(result, s)})',
    });
  }

  Future<void> _delete(BuildContext context, TrustedContact contact) async {
    final s = AppStrings.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.t('removeContactTitle', {'name': contact.name})),
        content: Text(s.t('removeContactBody')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(s.t('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(s.t('remove')),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await context.read<SafetyController>().removeContact(contact.id);
    }
  }

  void _onAdded(BuildContext context, TrustedContact contact) {
    final s = AppStrings.of(context);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(s.t('contactAdded', {'name': contact.name})),
          action: SnackBarAction(
            label: s.t('sendIntro'),
            onPressed: () => _sendTest(context, contact),
          ),
          duration: const Duration(seconds: 6),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final c = context.watch<SafetyController>();
    return Scaffold(
      appBar: AppBar(title: Text(s.t('contactsTitle'))),
      floatingActionButton: c.contacts.isEmpty
          ? null
          : FloatingActionButton.extended(
              tooltip: s.t('addContact'),
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                showDragHandle: true,
                builder: (sheetContext) => MultiProvider(
                  providers: [
                    ChangeNotifierProvider.value(value: c),
                    Provider.value(value: c.device),
                  ],
                  child: SheetScaffold(
                    title: s.t('addContact'),
                    children: [
                      AddContactButtons(
                        onAdded: (added) {
                          Navigator.pop(sheetContext);
                          _onAdded(context, added);
                        },
                      ),
                    ],
                  ),
                ),
              ),
              icon: const Icon(Icons.person_add_alt_1),
              label: Text(s.t('addContact')),
            ),
      body: c.contacts.isEmpty
          ? ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const SizedBox(height: 32),
                Icon(
                  Icons.people_outline,
                  size: 72,
                  color: Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(height: 16),
                Text(
                  s.t('noContactsTitle'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(s.t('noContactsBody'), textAlign: TextAlign.center),
                const SizedBox(height: 24),
                AddContactButtons(onAdded: (added) => _onAdded(context, added)),
              ],
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
                  child: Text(
                    s.t('contactsSummary', {'n': c.sosContacts.length}),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                for (final contact in c.contacts)
                  Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      contentPadding: const EdgeInsets.fromLTRB(16, 6, 4, 6),
                      leading: ContactAvatar(
                        contact.name,
                        primary: contact.isPrimary,
                      ),
                      title: Row(
                        children: [
                          Flexible(
                            child: Text(
                              contact.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (contact.isPrimary) ...[
                            const SizedBox(width: 6),
                            _Badge(
                              s.t('primary'),
                              Theme.of(context).colorScheme.primary,
                            ),
                          ],
                        ],
                      ),
                      subtitle: Text(
                        [
                          formatPhone(contact.phone),
                          if (contact.relationship.isNotEmpty)
                            contact.relationship,
                          if (!contact.alertOnSos) s.t('noSosAlerts'),
                        ].join(' · '),
                      ),
                      onTap: () =>
                          showContactEditor(context, existing: contact),
                      trailing: PopupMenuButton<String>(
                        tooltip: s.t('more'),
                        onSelected: (v) async {
                          switch (v) {
                            case 'call':
                              await c.device.call(contact.phone);
                            case 'test':
                              await _sendTest(context, contact);
                            case 'primary':
                              await c.saveContact(
                                contact.copyWith(isPrimary: true),
                              );
                            case 'edit':
                              await showContactEditor(
                                context,
                                existing: contact,
                              );
                            case 'delete':
                              await _delete(context, contact);
                          }
                        },
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            value: 'call',
                            child: ListTile(
                              leading: const Icon(Icons.call),
                              title: Text(s.t('call')),
                            ),
                          ),
                          PopupMenuItem(
                            value: 'test',
                            child: ListTile(
                              leading: const Icon(Icons.sms_outlined),
                              title: Text(s.t('sendTestSms')),
                            ),
                          ),
                          if (!contact.isPrimary)
                            PopupMenuItem(
                              value: 'primary',
                              child: ListTile(
                                leading: const Icon(Icons.star_outline),
                                title: Text(s.t('makePrimary')),
                              ),
                            ),
                          PopupMenuItem(
                            value: 'edit',
                            child: ListTile(
                              leading: const Icon(Icons.edit_outlined),
                              title: Text(s.t('edit')),
                            ),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: ListTile(
                              leading: const Icon(Icons.delete_outline),
                              title: Text(s.t('remove')),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.label, this.color);
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
