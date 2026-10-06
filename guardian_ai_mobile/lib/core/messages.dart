import '../models/geo_point.dart';

/// Composes the SMS texts sent to trusted contacts, in the user's language.
///
/// English messages stay within plain GSM characters so they fit in as few
/// SMS segments as possible.
class AlertMessages {
  AlertMessages(this.language, {required this.name});

  final String language;
  final String name;

  bool get _hi => language == 'hi';

  static String clock(DateTime t) {
    final local = t.toLocal();
    final h = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final m = local.minute.toString().padLeft(2, '0');
    return '$h:$m ${local.hour < 12 ? 'AM' : 'PM'}';
  }

  String _where(GeoPoint p) {
    final acc = p.accuracy == null
        ? ''
        : ' (+/-${p.accuracy!.round()}m, ${clock(p.time)})';
    return '${p.mapsUrl}$acc';
  }

  String _battery(int? battery) {
    if (battery == null) return '';
    return _hi ? ' बैटरी $battery%.' : ' Battery $battery%.';
  }

  String _live(String? url) {
    if (url == null) return '';
    return _hi ? ' लाइव मैप: $url' : ' Live map: $url';
  }

  String sosAlert({
    GeoPoint? location,
    int? battery,
    String medical = '',
    String? liveUrl,
  }) {
    final med = medical.trim().isEmpty
        ? ''
        : (_hi
              ? ' चिकित्सा जानकारी: ${medical.trim()}.'
              : ' Medical: ${medical.trim()}.');
    if (location == null) {
      return _hi
          ? 'SOS: $name को तुरंत मदद चाहिए! अभी लोकेशन उपलब्ध नहीं है, मिलते ही भेजी जाएगी।${_battery(battery)}$med${_live(liveUrl)}'
          : 'SOS from $name: I need help now! My location is not available yet; it will follow as soon as possible.${_battery(battery)}$med${_live(liveUrl)}';
    }
    return _hi
        ? 'SOS: $name को तुरंत मदद चाहिए! लोकेशन: ${_where(location)}.${_battery(battery)}$med${_live(liveUrl)}'
        : 'SOS from $name: I need help now! My location: ${_where(location)}.${_battery(battery)}$med${_live(liveUrl)}';
  }

  String locationUpdate(GeoPoint location, {int? battery, bool sos = true}) {
    if (_hi) {
      return '${sos ? 'SOS अपडेट' : 'लोकेशन अपडेट'} - $name: ${_where(location)}.${_battery(battery)}';
    }
    return '${sos ? 'SOS update' : 'Location update'} from $name: ${_where(location)}.${_battery(battery)}';
  }

  String safe() => _hi
      ? '$name अब सुरक्षित है। SOS अलर्ट समाप्त। धन्यवाद।'
      : '$name is safe now. The SOS alert is over. Thank you.';

  String journeyStart({
    required DateTime deadline,
    String? destination,
    String? liveUrl,
  }) {
    final dest = destination == null || destination.trim().isEmpty
        ? ''
        : destination.trim();
    if (_hi) {
      final to = dest.isEmpty ? '' : ' ($dest)';
      return '$name ने यात्रा शुरू की$to, ${clock(deadline)} तक पहुंचना है। समय पर चेक-इन न होने पर आपको अलर्ट मिलेगा।${_live(liveUrl)}';
    }
    final to = dest.isEmpty ? '' : ' to $dest';
    return '$name started a journey$to and expects to arrive by ${clock(deadline)}. You will get an alert if they do not check in.${_live(liveUrl)}';
  }

  String missedCheckIn({
    required DateTime deadline,
    String? destination,
    GeoPoint? location,
    int? battery,
    String? liveUrl,
  }) {
    final dest = destination == null || destination.trim().isEmpty
        ? ''
        : destination.trim();
    final where = location == null
        ? (_hi ? 'लोकेशन उपलब्ध नहीं।' : 'Location unavailable.')
        : (_hi
              ? 'अंतिम लोकेशन: ${_where(location)}.'
              : 'Last location: ${_where(location)}.');
    if (_hi) {
      final to = dest.isEmpty ? '' : ' ($dest)';
      return 'अलर्ट: $name ने ${clock(deadline)} तक यात्रा$to का चेक-इन नहीं किया। $where${_battery(battery)} कृपया उनसे संपर्क करें।${_live(liveUrl)}';
    }
    final to = dest.isEmpty ? '' : ' from their journey to $dest';
    return 'ALERT: $name did not check in$to by ${clock(deadline)}. $where${_battery(battery)} Please contact them now.${_live(liveUrl)}';
  }

  String arrived({String? destination}) {
    final dest = destination == null || destination.trim().isEmpty
        ? ''
        : destination.trim();
    if (_hi) {
      return dest.isEmpty
          ? '$name सुरक्षित पहुंच गए हैं।'
          : '$name सुरक्षित $dest पहुंच गए हैं।';
    }
    return dest.isEmpty
        ? '$name has arrived safely.'
        : '$name has arrived safely at $dest.';
  }

  String liveStart({
    required DateTime until,
    GeoPoint? location,
    String? liveUrl,
    required int intervalMinutes,
  }) {
    if (liveUrl != null) {
      return _hi
          ? '$name ${clock(until)} तक आपके साथ अपनी लाइव लोकेशन शेयर कर रहे हैं: $liveUrl'
          : '$name is sharing their live location with you until ${clock(until)}: $liveUrl';
    }
    final where = location == null
        ? ''
        : (_hi ? ' अभी: ${_where(location)}.' : ' Now: ${_where(location)}.');
    return _hi
        ? '$name ${clock(until)} तक अपनी लोकेशन शेयर कर रहे हैं, हर $intervalMinutes मिनट में अपडेट।$where'
        : '$name is sharing their location with you until ${clock(until)}, with updates every $intervalMinutes min.$where';
  }

  String liveEnd() => _hi
      ? '$name ने लोकेशन शेयर करना बंद कर दिया है।'
      : '$name has stopped sharing their location.';

  String locationOnce(GeoPoint location) => _hi
      ? '$name की वर्तमान लोकेशन: ${_where(location)}'
      : '$name\'s current location: ${_where(location)}';

  String test(String contactName) => _hi
      ? 'नमस्ते $contactName, $name ने आपको Guardian सुरक्षा ऐप में भरोसेमंद संपर्क के रूप में जोड़ा है। आपात स्थिति में आपको उनकी लोकेशन के साथ SMS मिलेगा।'
      : 'Hi $contactName, $name added you as a trusted contact in the Guardian safety app. In an emergency you will get an SMS like this with their location.';
}
