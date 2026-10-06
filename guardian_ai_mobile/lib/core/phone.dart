// Phone-number helpers tuned for Indian numbers.

/// Strips formatting and validates 7–15 digits (optional leading `+`).
/// Returns the normalised number, or null if invalid.
///
///   '+91 98765 43210' → '+919876543210'
///   '098765-43210'    → '09876543210'
String? normalizePhone(String raw) {
  final trimmed = raw.trim();
  if (RegExp(r'[A-Za-z]').hasMatch(trimmed)) return null;
  final hasPlus = trimmed.startsWith('+');
  final digits = trimmed.replaceAll(RegExp(r'\D'), '');
  if (digits.length < 7 || digits.length > 15) return null;
  return hasPlus ? '+$digits' : digits;
}

/// Validates a number that will be dialled (allows short codes like 112).
String? normalizeDialNumber(String raw) {
  final trimmed = raw.trim().replaceAll(RegExp(r'[\s().-]'), '');
  return RegExp(r'^\+?\d{2,15}$').hasMatch(trimmed) ? trimmed : null;
}

/// '+919876543210' → '+91 98765 43210'; other formats are returned as-is.
String formatPhone(String? phone) {
  if (phone == null || phone.isEmpty) return '';
  final m = RegExp(r'^\+91(\d{5})(\d{5})$').firstMatch(phone);
  if (m != null) return '+91 ${m.group(1)} ${m.group(2)}';
  final local = RegExp(r'^(\d{5})(\d{5})$').firstMatch(phone);
  if (local != null) return '${local.group(1)} ${local.group(2)}';
  return phone;
}

/// True when two numbers refer to the same subscriber (ignores +91 / 0).
bool samePhone(String a, String b) {
  String tail(String s) {
    final d = s.replaceAll(RegExp(r'\D'), '');
    return d.length > 10 ? d.substring(d.length - 10) : d;
  }

  return tail(a) == tail(b);
}
