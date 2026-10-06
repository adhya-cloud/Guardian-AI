import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/phone.dart';
import '../../core/strings.dart';
import '../../models/contact.dart';
import '../../services/device_bridge.dart';
import '../../state/safety_controller.dart';
import '../widgets/common.dart';

/// Opens the add/edit sheet.  Saves through the controller and returns the
/// saved contact, or null if cancelled.
Future<TrustedContact?> showContactEditor(
  BuildContext context, {
  TrustedContact? existing,
  String? name,
  String? phone,
}) async {
  final c = context.read<SafetyController>();
  final result = await showModalBottomSheet<TrustedContact>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => ChangeNotifierProvider.value(
      value: c,
      child: _ContactEditor(
        existing: existing,
        initialName: name,
        initialPhone: phone,
      ),
    ),
  );
  if (result != null) await c.saveContact(result);
  return result;
}

class _ContactEditor extends StatefulWidget {
  const _ContactEditor({this.existing, this.initialName, this.initialPhone});
  final TrustedContact? existing;
  final String? initialName;
  final String? initialPhone;

  @override
  State<_ContactEditor> createState() => _ContactEditorState();
}

class _ContactEditorState extends State<_ContactEditor> {
  late final _name = TextEditingController(
    text: widget.existing?.name ?? widget.initialName ?? '',
  );
  late final _phone = TextEditingController(
    text: widget.existing?.phone ?? widget.initialPhone ?? '',
  );
  late final _relationship = TextEditingController(
    text: widget.existing?.relationship ?? '',
  );
  late bool _primary =
      widget.existing?.isPrimary ??
      context.read<SafetyController>().contacts.isEmpty;
  late bool _alert = widget.existing?.alertOnSos ?? true;
  late bool _informed = widget.existing != null;
  bool _phoneTouched = false;

  @override
  void initState() {
    super.initState();
    _phoneTouched = _phone.text.isNotEmpty;
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _relationship.dispose();
    super.dispose();
  }

  String? get _normalized => normalizePhone(_phone.text);

  bool get _duplicate {
    final n = _normalized;
    if (n == null) return false;
    return context.read<SafetyController>().contacts.any(
      (c) => c.id != widget.existing?.id && samePhone(c.phone, n),
    );
  }

  bool get _valid =>
      _name.text.trim().isNotEmpty &&
      _normalized != null &&
      !_duplicate &&
      _informed;

  void _save() {
    Navigator.pop(
      context,
      TrustedContact(
        id:
            widget.existing?.id ??
            DateTime.now().microsecondsSinceEpoch.toRadixString(36),
        name: _name.text.trim(),
        phone: _normalized!,
        relationship: _relationship.text.trim(),
        isPrimary: _primary,
        alertOnSos: _alert,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final phoneError = !_phoneTouched
        ? null
        : _normalized == null
        ? s.t('invalidPhone')
        : _duplicate
        ? s.t('duplicatePhone')
        : null;
    return SheetScaffold(
      title: widget.existing == null ? s.t('addContact') : s.t('editContact'),
      children: [
        TextField(
          key: const ValueKey('contact_name'),
          controller: _name,
          textCapitalization: TextCapitalization.words,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: s.t('name'),
            prefixIcon: const Icon(Icons.person_outline),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey('contact_phone'),
          controller: _phone,
          keyboardType: TextInputType.phone,
          onChanged: (_) => setState(() => _phoneTouched = true),
          decoration: InputDecoration(
            labelText: s.t('phone'),
            hintText: '+91 98765 43210',
            errorText: phoneError,
            prefixIcon: const Icon(Icons.phone_outlined),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _relationship,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: s.t('relationship'),
            hintText: s.t('relationshipHint'),
            prefixIcon: const Icon(Icons.favorite_outline),
          ),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _alert,
          onChanged: (v) => setState(() => _alert = v),
          title: Text(s.t('alertOnSos')),
          subtitle: Text(s.t('alertOnSosHelp')),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _primary,
          onChanged: (v) => setState(() => _primary = v),
          title: Text(s.t('primaryContact')),
          subtitle: Text(s.t('primaryContactHelp')),
        ),
        CheckboxListTile(
          key: const ValueKey('contact_informed'),
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: _informed,
          onChanged: (v) => setState(() => _informed = v == true),
          title: Text(s.t('informedConsent')),
        ),
        const SizedBox(height: 12),
        FilledButton(
          key: const ValueKey('contact_save'),
          onPressed: _valid ? _save : null,
          child: Text(s.t('save')),
        ),
      ],
    );
  }
}

/// "Choose from contacts" + "Enter manually" buttons.
class AddContactButtons extends StatelessWidget {
  const AddContactButtons({super.key, required this.onAdded});
  final ValueChanged<TrustedContact> onAdded;

  Future<void> _fromPhonebook(BuildContext context) async {
    final picked = await context.read<DeviceBridge>().pickContact();
    if (picked == null || !context.mounted) return;
    final added = await showContactEditor(
      context,
      name: picked.name,
      phone: picked.phone,
    );
    if (added != null) onAdded(added);
  }

  Future<void> _manual(BuildContext context) async {
    final added = await showContactEditor(context);
    if (added != null) onAdded(added);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final canPick = context.select<SafetyController, bool>(
      (c) => c.capabilities.contactPicker,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (canPick) ...[
          FilledButton.icon(
            onPressed: () => _fromPhonebook(context),
            icon: const Icon(Icons.contacts),
            label: Text(s.t('chooseFromContacts')),
          ),
          const SizedBox(height: 8),
        ],
        OutlinedButton.icon(
          key: const ValueKey('add_contact_manual'),
          onPressed: () => _manual(context),
          icon: const Icon(Icons.dialpad),
          label: Text(s.t('enterManually')),
        ),
      ],
    );
  }
}
