import 'package:flutter/widgets.dart';

/// English and Hindi UI strings.  Look up with `AppStrings.of(context).t(key)`;
/// `{placeholders}` are filled from the optional args map.
///
/// To add a language: add a map below, register it in [_maps] and
/// [supportedLocales].  Missing keys fall back to English.
class AppStrings {
  const AppStrings(this.language);

  final String language;

  static const supportedLocales = [Locale('en'), Locale('hi')];
  static const delegate = _AppStringsDelegate();

  static AppStrings of(BuildContext context) =>
      Localizations.of<AppStrings>(context, AppStrings) ??
      const AppStrings('en');

  static const _maps = {'en': en, 'hi': hi};

  String t(String key, [Map<String, Object> args = const {}]) {
    var text = _maps[language]?[key] ?? en[key] ?? key;
    args.forEach((k, v) => text = text.replaceAll('{$k}', '$v'));
    return text;
  }

  static const en = <String, String>{
    'appName': 'Guardian',

    // Navigation
    'tabHome': 'Home',
    'tabMap': 'Map',
    'tabContacts': 'Contacts',
    'tabHistory': 'History',
    'tabSettings': 'Settings',

    // Common
    'back': 'Back',
    'next': 'Next',
    'finish': 'Finish',
    'save': 'Save',
    'cancel': 'Cancel',
    'delete': 'Delete',
    'remove': 'Remove',
    'edit': 'Edit',
    'clear': 'Clear',
    'open': 'Open',
    'call': 'Call',
    'share': 'Share',
    'retry': 'Retry',
    'enable': 'Enable',
    'allow': 'Allow',
    'more': 'More',
    'now': 'Now',
    'seeAll': 'See all',
    'openSettings': 'Settings',
    'minutesShort': '{n} min',
    'hoursShort': '{n} h',
    'hoursMinutesShort': '{h} h {m} min',
    'secondsShort': '{n} sec',
    'secondsLong': '{n} seconds',
    'everyNMinutes': 'Every {n} minutes',

    // Onboarding
    'getStarted': 'Get started',
    'skipForNow': 'Skip for now',
    'welcomeTitle': 'Help is one tap away',
    'welcomeBody':
        'Guardian alerts the people you trust with your exact location when you need help — by SMS, so it works even without mobile data.',
    'featureSosTitle': 'SOS alerts',
    'featureSosBody':
        'Tap or shake to send your location to trusted contacts, then keep them updated automatically.',
    'featureLiveTitle': 'Live location',
    'featureLiveBody':
        'Share where you are for a set time, with a live map link or regular SMS updates.',
    'featureJourneyTitle': 'Journey check-in',
    'featureJourneyBody':
        'Set a timer for your trip. If you don\'t check in, your contacts are alerted automatically.',
    'featureMapTitle': 'Nearby help',
    'featureMapBody':
        'Find the closest police stations, hospitals and pharmacies with directions.',
    'profileTitle': 'About you',
    'profileBody':
        'Your name appears in alerts so your contacts know it\'s you. Everything stays encrypted on this phone.',
    'yourName': 'Your name',
    'emergencyNumber': 'Emergency number',
    'emergencyNumberHelp':
        '112 is India\'s all-in-one emergency number (police, fire, ambulance).',
    'invalidNumber': 'Enter a valid number',
    'medicalInfo': 'Medical information (optional)',
    'medicalInfoHint': 'e.g. Blood group O+, asthma, allergic to penicillin',
    'medicalInfoHelp':
        'Added to SOS messages so responders can help you faster.',
    'contactsOnboardingBody':
        'Add at least one person who should get your SOS alerts. We recommend 2–3 people.',
    'permissionsTitle': 'Permissions',
    'permissionsBody':
        'Guardian only asks for what it needs to reach your contacts. You can change these any time.',
    'permLocation': 'Location',
    'permLocationWhy':
        'To include where you are in alerts and show nearby help.',
    'permSms': 'Send SMS',
    'permSmsWhy': 'To send alerts automatically, even without internet.',
    'permPhone': 'Phone calls',
    'permPhoneWhy': 'To call your contact or 112 straight after an SOS.',
    'permNotifications': 'Notifications',
    'permNotificationsWhy': 'For check-in reminders and SOS status.',

    // Home
    'goodMorning': 'Good morning',
    'goodAfternoon': 'Good afternoon',
    'goodEvening': 'Good evening',
    'statusProtected': 'Your contacts are ready to be alerted',
    'statusNoContacts': 'Add a trusted contact to enable SOS alerts',
    'tapForHelp': 'Tap for help',
    'sosButtonLabel': 'SOS emergency button',
    'sosHint':
        'Alerts {n} contact(s) with your location after a {sec}-second countdown.',
    'sosNeedsContacts':
        'No trusted contacts yet — SOS can only call for help. Add contacts in the Contacts tab.',
    'shakeHint': 'Tip: shake your phone firmly to start SOS.',
    'quickActions': 'Quick actions',
    'actionLiveShare': 'Share live location',
    'actionJourney': 'Journey check-in',
    'actionFakeCall': 'Fake call',
    'actionSiren': 'Loud siren',
    'actionSirenStop': 'Stop siren',
    'actionStrobe': 'Flash strobe',
    'actionStrobeStop': 'Stop strobe',
    'actionShareOnce': 'Send my location',
    'helplines': 'Helplines',
    'nearbyHelp': 'Nearby help',
    'nearbyHelpBody': 'Police, hospitals and pharmacies around you',
    'gettingLocation': 'Getting your location…',
    'locationUnavailable': 'Couldn\'t get your location. Check that GPS is on.',

    // SOS
    'sendingSosIn': 'Sending SOS in',
    'shakeDetected': 'Shake detected — sending SOS in',
    'countdownBody':
        '{n} trusted contact(s) will get an SMS with your location.',
    'countdownNoContacts':
        'You have no trusted contacts. Your location will be recorded and you can call 112.',
    'cancelSos': 'Cancel',
    'sendNow': 'Send now',
    'sosActive': 'SOS active',
    'sosActiveCardBody':
        'Alert sent to {sent} of {total}. Your location keeps updating.',
    'sosSending': 'Getting your location and alerting your contacts…',
    'sosSentSummary': 'Alert sent to {sent} of {total} contact(s)',
    'sosNoRecipients': 'No contacts to alert — call for help below',
    'sosUpdatesInfo':
        'While SOS is on, your contacts get a location update every {n} minutes. You can leave this screen; it keeps running.',
    'waitingForGps': 'Waiting for GPS…',
    'callEmergency': 'Call {number}',
    'callName': 'Call {name}',
    'liveMapLink': 'Live map link',
    'shareLink': 'Share link',
    'messages': 'Messages',
    'imSafeStop': 'I\'m safe — stop SOS',
    'stopSosTitle': 'Stop the SOS?',
    'tellContactsSafe': 'Tell my contacts I\'m safe',
    'keepSosOn': 'Keep SOS on',
    'imSafe': 'I\'m safe',
    'sosEnded': 'The SOS has ended.',

    // Delivery
    'deliverySent': 'Sent',
    'deliveryComposer': 'Opened in SMS app',
    'deliveryFailed': 'Failed',
    'deliveryFailedPermission': 'Failed — SMS permission off',
    'deliveryFailedUnavailable': 'Failed — SMS not available',
    'kind_sosAlert': 'SOS alert',
    'kind_locationUpdate': 'Location update',
    'kind_safe': 'I\'m safe',
    'kind_journeyStart': 'Journey started',
    'kind_arrived': 'Arrived',
    'kind_liveStart': 'Live sharing started',
    'kind_liveEnd': 'Live sharing stopped',
    'kind_locationOnce': 'Location',
    'kind_test': 'Test message',

    // Journey
    'journeyTitle': 'Journey check-in',
    'journeySubtitle':
        'Tell us when you expect to arrive. If you don\'t check in by then, your contacts get an alert with your location.',
    'destination': 'Destination',
    'destinationHint': 'e.g. Home, Office, Priya\'s place',
    'checkInWithin': 'Check in within',
    'whoToAlert': 'Who to alert',
    'journeyExplainer':
        'Your location is tracked in the background while the journey runs. You\'ll get a reminder 2 minutes before the deadline.',
    'startJourney': 'Start journey',
    'journeyActive': 'Journey in progress',
    'journeyAreYouSafe': 'Are you safe? Check in now',
    'toDestination': 'to {place}',
    'checkInBy': 'check in by {time}',
    'journeyAutoAlert':
        'Your contacts will be alerted automatically if you don\'t check in.',
    'imSafeArrived': 'I\'ve arrived',
    'plus15': '+15 min',
    'cancelJourneyTitle': 'Cancel this journey?',
    'cancelJourneyBody': 'Your contacts won\'t be alerted and tracking stops.',
    'keepRunning': 'Keep running',
    'cancelJourney': 'Cancel journey',
    'journeyArrivedSnack': 'Glad you\'re safe! Journey ended.',

    // Live share
    'liveShareTitle': 'Share live location',
    'liveShareSubtitle':
        'Your chosen contacts can follow your location for a limited time.',
    'shareFor': 'Share for',
    'shareWith': 'Share with',
    'liveShareViaLink':
        'Contacts get an SMS with a live map link that updates every few seconds.',
    'liveShareViaSms':
        'Contacts get an SMS with your location now and every {n} minutes. Set up a live-map server in Settings for a real-time map link.',
    'startSharing': 'Start sharing',
    'liveSharingOn': 'Sharing live location',
    'liveSharingWith': 'With {n} contact(s)',
    'endsIn': 'Ends in {time}',
    'viaLiveMap': 'Via live map link',
    'viaSms': 'SMS update every {n} min',
    'stopSharing': 'Stop',

    // Fake call
    'fakeCallTitle': 'Fake incoming call',
    'fakeCallSubtitle':
        'A realistic incoming call with your ringtone, to help you leave an uncomfortable situation.',
    'fakeCallDefaultCaller': 'Mom',
    'callerName': 'Caller name',
    'ringIn': 'Ring in',
    'scheduleCall': 'Schedule call',
    'fakeCallScheduled': 'Your phone will ring in {time}. Keep Guardian open.',
    'incomingCall': 'Incoming call',
    'mobile': 'Mobile',
    'accept': 'Accept',
    'decline': 'Decline',
    'endCall': 'End',

    // Helplines
    'helplinesTitle': 'Emergency helplines',
    'helplinesSource': 'Official source: 112.gov.in',
    'cannotCall': 'Couldn\'t open the dialer. Dial {number} manually.',
    'hl112': 'Emergency (all services)',
    'hl112Desc': 'National emergency number — police, fire, ambulance',
    'hl100': 'Police',
    'hl100Desc': 'Police control room',
    'hl1091': 'Women helpline',
    'hl1091Desc': 'Police helpline for women in distress',
    'hl181': 'Women helpline (181)',
    'hl181Desc': 'Support for women facing violence (state-run)',
    'hl108': 'Ambulance',
    'hl108Desc': 'Emergency medical services in most states',
    'hl102': 'Ambulance (102)',
    'hl102Desc': 'Ambulance, mother & child care in many states',
    'hl101': 'Fire',
    'hl101Desc': 'Fire and rescue services',
    'hl1098': 'Child helpline',
    'hl1098Desc': 'For children in need of care and protection',
    'hl1930': 'Cyber crime',
    'hl1930Desc': 'Report online fraud and cyber crime',
    'hl14567': 'Elder line',
    'hl14567Desc': 'Help for senior citizens',

    // Map
    'filterAll': 'All',
    'place_police': 'Police',
    'place_hospital': 'Hospital',
    'place_pharmacy': 'Pharmacy',
    'place_fireStation': 'Fire station',
    'searchThisArea': 'Search this area',
    'myLocation': 'My location',
    'gpsOff': 'GPS is turned off',
    'locationPermissionNeeded': 'Location permission is needed',
    'searchingNearby': 'Searching nearby…',
    'placesFound': '{n} places nearby',
    'placesError': 'Couldn\'t load nearby places. Check your internet.',
    'placesAttribution':
        'Place data © OpenStreetMap contributors. Details may be incomplete — in an emergency call 112.',
    'directions': 'Directions',
    'distanceAway': '{d} away',

    // Contacts
    'contactsTitle': 'Trusted contacts',
    'addContact': 'Add contact',
    'editContact': 'Edit contact',
    'chooseFromContacts': 'Choose from phone contacts',
    'enterManually': 'Enter manually',
    'name': 'Name',
    'phone': 'Phone number',
    'relationship': 'Relationship',
    'relationshipHint': 'e.g. Mother, Friend',
    'invalidPhone': 'Enter a valid phone number',
    'duplicatePhone': 'This number is already a contact',
    'alertOnSos': 'Send SOS alerts',
    'alertOnSosHelp': 'Gets your SOS and missed check-in alerts',
    'primaryContact': 'Primary contact',
    'primaryContactHelp': 'Called automatically after SOS, if enabled',
    'informedConsent': 'I have told this person they are my emergency contact',
    'noContactsTitle': 'No trusted contacts yet',
    'noContactsBody':
        'Add family or friends who should be alerted when you need help.',
    'noContactsYet': 'Add a trusted contact first.',
    'contactsSummary': '{n} contact(s) receive SOS alerts',
    'primary': 'PRIMARY',
    'noSosAlerts': 'No SOS alerts',
    'sendTestSms': 'Send test SMS',
    'makePrimary': 'Make primary',
    'removeContactTitle': 'Remove {name}?',
    'removeContactBody': 'They will no longer receive your alerts.',
    'contactAdded': '{name} added',
    'sendIntro': 'Let them know',
    'testSent': 'Test SMS sent to {name}',
    'testFailed': 'Couldn\'t send the SMS',
    'composerOpened': 'Opened your SMS app — press send',

    // History
    'historyTitle': 'History',
    'noHistory':
        'Your SOS alerts, journeys and location shares will appear here.',
    'incidentSos': 'SOS alert',
    'incidentMissedCheckIn': 'Missed check-in alert',
    'incidentJourney': 'Journey',
    'incidentLiveShare': 'Live location share',
    'statusActive': 'Active',
    'statusArrived': 'Arrived',
    'statusEnded': 'Ended',
    'statusCancelled': 'Cancelled',
    'statusEscalated': 'Alert sent',
    'messagesCount': '{n} message(s)',
    'failedCount': '{n} failed',
    'clearHistoryTitle': 'Clear history',
    'clearHistoryBody': 'Delete all finished records from this phone?',
    'status': 'Status',
    'started': 'Started',
    'ended': 'Ended',
    'checkInDeadline': 'Check-in by',
    'lastLocation': 'Last location',
    'pointsRecorded': 'Points recorded',
    'noLocationRecorded': 'No location was recorded',
    'noMessagesSent': 'No messages were sent.',

    // Settings
    'settingsTitle': 'Settings',
    'profileSection': 'Profile',
    'editProfile': 'Edit profile',
    'editProfileHint': 'Name, emergency number, medical info',
    'language': 'Language',
    'sosSection': 'SOS',
    'countdown': 'Countdown before sending',
    'updateInterval': 'Location updates by SMS',
    'autoCall': 'Call after SOS',
    'autoCallOff': 'Don\'t call',
    'autoCallPrimary': 'Call primary contact',
    'autoCallEmergency': 'Call {number}',
    'shakeToSos': 'Shake to SOS',
    'shakeToSosHelp': 'Shake the phone firmly while Guardian is open',
    'sirenOnSos': 'Siren on SOS',
    'sirenOnSosHelp': 'Play a loud siren when SOS is sent',
    'journeySection': 'Journey check-in',
    'notifyJourneyStart': 'Tell contacts when a journey starts',
    'notifyArrival': 'Tell contacts when I arrive',
    'liveMapSection': 'Live map',
    'trackingServer': 'Live-map server',
    'trackingServerOff': 'Not set — live sharing uses SMS updates',
    'trackingServerHelp':
        'Optional. Enter the address of your Guardian tracking server to send contacts a real-time map link.',
    'serverUrl': 'Server address',
    'invalidUrl': 'Enter a valid http(s) address',
    'testConnection': 'Test',
    'serverOk': 'Connected',
    'serverUnreachable': 'Server not reachable',
    'moreSection': 'More',
    'deleteAllData': 'Delete all data',
    'deleteAllDataHelp':
        'Removes your profile, contacts and history from this phone',
    'deleteAllDataConfirm':
        'This permanently deletes your profile, trusted contacts and history from this phone and stops any active SOS or sharing.',
    'aboutLine': 'Guardian 2.0 · Your data stays on this phone',

    // Notifications (controller)
    'notifSosTitle': 'SOS sent',
    'notifSosBody':
        'Alert sent to {sent} of {total} contact(s). Location updates continue until you stop SOS.',
    'notifTrackingTitle': 'Guardian is sharing your location',
    'notifTrackingSos': 'SOS active — your contacts receive location updates',
    'notifTrackingJourney': 'Journey check-in is running',
    'notifTrackingLive': 'Live location sharing is on',
    'notifJourneyReminderTitle': 'Are you safe?',
    'notifJourneyReminderBody':
        'Your check-in ends in {min} min. Open Guardian to check in or extend, or your contacts will be alerted.',
    'notifJourneyEscalatedTitle': 'Missed check-in — contacts alerted',
    'notifJourneyEscalatedBody':
        'Alert sent to {sent} of {total} contact(s). Open Guardian to stop the SOS when you are safe.',
    // Lite edition (no background SMS)
    'sosHintLite':
        'After a {sec}-second countdown your SMS app opens with an alert and your location for {n} contact(s) — press Send.',
    'countdownBodyLite':
        'Your SMS app will open with the alert and your location for {n} contact(s). Press Send.',
    'sosUpdatesInfoLite':
        'This edition cannot send SMS in the background. Tap “Send alert again” to send your latest location. With a live-map server your contacts can follow you continuously.',
    'sendAlertAgain': 'Send alert again',
    'liveShareViaSmsLite':
        'Contacts get your current location by SMS (you press Send). For continuous tracking, set up a live-map server in Settings.',
    'viaSmsOnce': 'Location sent by SMS once',
    'journeyExplainerLite':
        'You will get a reminder 2 minutes before the deadline. If you do not check in, Guardian alerts you and opens a pre-filled SMS to your contacts — this edition cannot send it automatically.',
    'journeyAutoAlertLite':
        'If you do not check in, Guardian will ask you to alert your contacts.',
    'notifJourneyMissedTitle': 'Check-in missed',
    'notifJourneyMissedBody':
        'Open Guardian now to send the alert to your contacts.',
    'aboutLineLite': 'Guardian 2.0 Lite · Your data stays on this phone',
    'editionLiteNote':
        'This edition opens your SMS app for alerts — you press Send. For fully automatic SMS alerts, install the full edition over USB.',
    'notifSosComposerTitle': 'SOS ready - press Send',
    'notifSosComposerBody':
        'Your SMS app opened with the alert and your location. Press Send to alert your contacts.',
    'sosActiveCardBodyComposer':
        'Alert opened in your SMS app - make sure you pressed Send.',
    'sosComposerSummary': 'Alert opened in your SMS app - press Send',

    // SMS permission blocked (full edition)
    'smsOffTitle': 'Automatic SMS is off',
    'smsOffBody':
        'Allow SMS so alerts go out on their own. Until then, SOS opens your SMS app with the alert ready and you press Send.',
    'smsOffRestrictedBody':
        'Android is blocking SMS for Guardian because it was installed from a file. Until you allow it, SOS opens your SMS app with the alert ready and you press Send.',
    'allowSms': 'Allow SMS',
    'howToAllow': 'How to allow',
    'openAppSettings': 'Open app settings',
    'done': 'Done',
    'smsRestrictedTitle': 'Allow SMS for Guardian',
    'smsRestrictedIntro':
        'Android 15 and newer block SMS for apps installed from a file (WhatsApp, Drive, a browser). That is the “App was denied access to SMS” message. You only need to unblock it once:',
    'smsRestrictedStep1': 'Tap “Open app settings” below.',
    'smsRestrictedStep2':
        'Tap ⋮ at the top right, then “Allow restricted settings”, and confirm with your PIN or fingerprint.',
    'smsRestrictedStep3':
        'Open Permissions → SMS → Allow, then come back to Guardian.',
    'smsRestrictedNoMenu':
        'No “Allow restricted settings” in the ⋮ menu? Open Permissions → SMS once, close the “Restricted setting” message, go back, and tap ⋮ again.',
    'smsRestrictedMeanwhile':
        'Until then SOS still works: your SMS app opens with the alert and your location ready, and you press Send.',
    'smsAllowedNow': 'SMS allowed. Alerts will now be sent automatically.',
  };

  static const hi = <String, String>{
    'appName': 'गार्जियन',

    'tabHome': 'होम',
    'tabMap': 'मैप',
    'tabContacts': 'संपर्क',
    'tabHistory': 'इतिहास',
    'tabSettings': 'सेटिंग्स',

    'back': 'पीछे',
    'next': 'आगे',
    'finish': 'पूरा करें',
    'save': 'सहेजें',
    'cancel': 'रद्द करें',
    'delete': 'हटाएं',
    'remove': 'हटाएं',
    'edit': 'बदलें',
    'clear': 'साफ़ करें',
    'open': 'खोलें',
    'call': 'कॉल',
    'share': 'शेयर',
    'retry': 'फिर कोशिश करें',
    'enable': 'चालू करें',
    'allow': 'अनुमति दें',
    'more': 'और',
    'now': 'अभी',
    'seeAll': 'सभी देखें',
    'openSettings': 'सेटिंग्स',
    'minutesShort': '{n} मिनट',
    'hoursShort': '{n} घंटे',
    'hoursMinutesShort': '{h} घंटे {m} मिनट',
    'secondsShort': '{n} सेकंड',
    'secondsLong': '{n} सेकंड',
    'everyNMinutes': 'हर {n} मिनट',

    'getStarted': 'शुरू करें',
    'skipForNow': 'अभी छोड़ें',
    'welcomeTitle': 'मदद बस एक टैप दूर',
    'welcomeBody':
        'ज़रूरत पड़ने पर गार्जियन आपके भरोसेमंद लोगों को आपकी सटीक लोकेशन SMS से भेजता है — मोबाइल डेटा के बिना भी।',
    'featureSosTitle': 'SOS अलर्ट',
    'featureSosBody':
        'टैप करें या फ़ोन हिलाएं — संपर्कों को आपकी लोकेशन जाएगी और अपडेट मिलते रहेंगे।',
    'featureLiveTitle': 'लाइव लोकेशन',
    'featureLiveBody':
        'तय समय के लिए अपनी लोकेशन लाइव मैप लिंक या SMS अपडेट से शेयर करें।',
    'featureJourneyTitle': 'यात्रा चेक-इन',
    'featureJourneyBody':
        'यात्रा का टाइमर लगाएं। चेक-इन न करने पर संपर्कों को अपने-आप अलर्ट जाएगा।',
    'featureMapTitle': 'पास में मदद',
    'featureMapBody':
        'नज़दीकी पुलिस स्टेशन, अस्पताल और दवा की दुकानें रास्ते के साथ देखें।',
    'profileTitle': 'आपके बारे में',
    'profileBody':
        'अलर्ट में आपका नाम दिखेगा ताकि संपर्क आपको पहचानें। सब कुछ इसी फ़ोन पर एन्क्रिप्टेड रहता है।',
    'yourName': 'आपका नाम',
    'emergencyNumber': 'आपातकालीन नंबर',
    'emergencyNumberHelp':
        '112 भारत का एकीकृत आपातकालीन नंबर है (पुलिस, फायर, एम्बुलेंस)।',
    'invalidNumber': 'सही नंबर डालें',
    'medicalInfo': 'चिकित्सा जानकारी (वैकल्पिक)',
    'medicalInfoHint': 'जैसे ब्लड ग्रुप O+, अस्थमा, पेनिसिलिन से एलर्जी',
    'medicalInfoHelp': 'SOS संदेश में जोड़ी जाती है ताकि मदद जल्दी मिले।',
    'contactsOnboardingBody':
        'कम से कम एक व्यक्ति जोड़ें जिसे आपका SOS अलर्ट मिलना चाहिए। 2–3 लोग बेहतर हैं।',
    'permissionsTitle': 'अनुमतियां',
    'permissionsBody':
        'गार्जियन सिर्फ़ वही अनुमति मांगता है जो संपर्कों तक पहुंचने के लिए ज़रूरी है। आप इन्हें कभी भी बदल सकते हैं।',
    'permLocation': 'लोकेशन',
    'permLocationWhy': 'अलर्ट में आपकी जगह भेजने और पास की मदद दिखाने के लिए।',
    'permSms': 'SMS भेजना',
    'permSmsWhy': 'इंटरनेट के बिना भी अपने-आप अलर्ट भेजने के लिए।',
    'permPhone': 'फ़ोन कॉल',
    'permPhoneWhy': 'SOS के तुरंत बाद संपर्क या 112 को कॉल करने के लिए।',
    'permNotifications': 'सूचनाएं',
    'permNotificationsWhy': 'चेक-इन रिमाइंडर और SOS स्थिति के लिए।',

    'goodMorning': 'सुप्रभात',
    'goodAfternoon': 'नमस्ते',
    'goodEvening': 'शुभ संध्या',
    'statusProtected': 'आपके संपर्क अलर्ट के लिए तैयार हैं',
    'statusNoContacts': 'SOS अलर्ट के लिए एक भरोसेमंद संपर्क जोड़ें',
    'tapForHelp': 'मदद के लिए टैप करें',
    'sosButtonLabel': 'SOS आपातकालीन बटन',
    'sosHint':
        '{sec} सेकंड की उलटी गिनती के बाद {n} संपर्क(ों) को आपकी लोकेशन भेजी जाएगी।',
    'sosNeedsContacts':
        'अभी कोई भरोसेमंद संपर्क नहीं — SOS सिर्फ़ मदद के लिए कॉल कर सकता है। संपर्क टैब में जोड़ें।',
    'shakeHint': 'सुझाव: SOS शुरू करने के लिए फ़ोन को ज़ोर से हिलाएं।',
    'quickActions': 'त्वरित विकल्प',
    'actionLiveShare': 'लाइव लोकेशन शेयर',
    'actionJourney': 'यात्रा चेक-इन',
    'actionFakeCall': 'नकली कॉल',
    'actionSiren': 'तेज़ सायरन',
    'actionSirenStop': 'सायरन बंद',
    'actionStrobe': 'फ़्लैश स्ट्रोब',
    'actionStrobeStop': 'स्ट्रोब बंद',
    'actionShareOnce': 'मेरी लोकेशन भेजें',
    'helplines': 'हेल्पलाइन',
    'nearbyHelp': 'पास में मदद',
    'nearbyHelpBody': 'आसपास के पुलिस स्टेशन, अस्पताल और दवा दुकानें',
    'gettingLocation': 'आपकी लोकेशन ली जा रही है…',
    'locationUnavailable': 'लोकेशन नहीं मिली। देखें कि GPS चालू है।',

    'sendingSosIn': 'SOS भेजा जाएगा',
    'shakeDetected': 'फ़ोन हिलाया गया — SOS भेजा जाएगा',
    'countdownBody': '{n} भरोसेमंद संपर्क(ों) को आपकी लोकेशन के साथ SMS जाएगा।',
    'countdownNoContacts':
        'कोई भरोसेमंद संपर्क नहीं है। आपकी लोकेशन दर्ज होगी और आप 112 पर कॉल कर सकते हैं।',
    'cancelSos': 'रद्द करें',
    'sendNow': 'अभी भेजें',
    'sosActive': 'SOS चालू है',
    'sosActiveCardBody':
        '{total} में से {sent} को अलर्ट भेजा गया। आपकी लोकेशन अपडेट होती रहेगी।',
    'sosSending': 'लोकेशन ली जा रही है और संपर्कों को अलर्ट भेजा जा रहा है…',
    'sosSentSummary': '{total} में से {sent} संपर्क(ों) को अलर्ट भेजा गया',
    'sosNoRecipients':
        'अलर्ट के लिए कोई संपर्क नहीं — नीचे मदद के लिए कॉल करें',
    'sosUpdatesInfo':
        'SOS चालू रहने तक संपर्कों को हर {n} मिनट में लोकेशन अपडेट मिलेगा। आप यह स्क्रीन छोड़ सकते हैं; यह चलता रहेगा।',
    'waitingForGps': 'GPS का इंतज़ार…',
    'callEmergency': '{number} पर कॉल करें',
    'callName': '{name} को कॉल करें',
    'liveMapLink': 'लाइव मैप लिंक',
    'shareLink': 'लिंक शेयर करें',
    'messages': 'संदेश',
    'imSafeStop': 'मैं सुरक्षित हूं — SOS बंद करें',
    'stopSosTitle': 'SOS बंद करें?',
    'tellContactsSafe': 'संपर्कों को बताएं कि मैं सुरक्षित हूं',
    'keepSosOn': 'SOS चालू रखें',
    'imSafe': 'मैं सुरक्षित हूं',
    'sosEnded': 'SOS समाप्त हो गया है।',

    'deliverySent': 'भेजा गया',
    'deliveryComposer': 'SMS ऐप में खोला गया',
    'deliveryFailed': 'विफल',
    'deliveryFailedPermission': 'विफल — SMS अनुमति बंद',
    'deliveryFailedUnavailable': 'विफल — SMS उपलब्ध नहीं',
    'kind_sosAlert': 'SOS अलर्ट',
    'kind_locationUpdate': 'लोकेशन अपडेट',
    'kind_safe': 'मैं सुरक्षित हूं',
    'kind_journeyStart': 'यात्रा शुरू',
    'kind_arrived': 'पहुंच गए',
    'kind_liveStart': 'लाइव शेयर शुरू',
    'kind_liveEnd': 'लाइव शेयर बंद',
    'kind_locationOnce': 'लोकेशन',
    'kind_test': 'परीक्षण संदेश',

    'journeyTitle': 'यात्रा चेक-इन',
    'journeySubtitle':
        'बताएं कि आप कब तक पहुंचेंगे। तब तक चेक-इन न करने पर संपर्कों को आपकी लोकेशन के साथ अलर्ट जाएगा।',
    'destination': 'मंज़िल',
    'destinationHint': 'जैसे घर, ऑफिस, प्रिया का घर',
    'checkInWithin': 'इतने समय में चेक-इन',
    'whoToAlert': 'किसे अलर्ट करें',
    'journeyExplainer':
        'यात्रा के दौरान बैकग्राउंड में आपकी लोकेशन ट्रैक होगी। समय खत्म होने से 2 मिनट पहले रिमाइंडर मिलेगा।',
    'startJourney': 'यात्रा शुरू करें',
    'journeyActive': 'यात्रा जारी है',
    'journeyAreYouSafe': 'क्या आप सुरक्षित हैं? अभी चेक-इन करें',
    'toDestination': '{place} तक',
    'checkInBy': '{time} तक चेक-इन',
    'journeyAutoAlert': 'चेक-इन न करने पर संपर्कों को अपने-आप अलर्ट जाएगा।',
    'imSafeArrived': 'मैं पहुंच गई/गया',
    'plus15': '+15 मिनट',
    'cancelJourneyTitle': 'यह यात्रा रद्द करें?',
    'cancelJourneyBody':
        'संपर्कों को अलर्ट नहीं जाएगा और ट्रैकिंग बंद हो जाएगी।',
    'keepRunning': 'जारी रखें',
    'cancelJourney': 'यात्रा रद्द करें',
    'journeyArrivedSnack': 'खुशी है कि आप सुरक्षित हैं! यात्रा समाप्त।',

    'liveShareTitle': 'लाइव लोकेशन शेयर करें',
    'liveShareSubtitle': 'चुने हुए संपर्क सीमित समय तक आपकी लोकेशन देख सकेंगे।',
    'shareFor': 'कितनी देर',
    'shareWith': 'किसके साथ',
    'liveShareViaLink':
        'संपर्कों को लाइव मैप लिंक के साथ SMS मिलेगा जो हर कुछ सेकंड में अपडेट होता है।',
    'liveShareViaSms':
        'संपर्कों को अभी और हर {n} मिनट में आपकी लोकेशन का SMS मिलेगा। रियल-टाइम मैप लिंक के लिए सेटिंग्स में लाइव-मैप सर्वर जोड़ें।',
    'startSharing': 'शेयर करना शुरू करें',
    'liveSharingOn': 'लाइव लोकेशन शेयर हो रही है',
    'liveSharingWith': '{n} संपर्क(ों) के साथ',
    'endsIn': '{time} में समाप्त',
    'viaLiveMap': 'लाइव मैप लिंक से',
    'viaSms': 'हर {n} मिनट SMS अपडेट',
    'stopSharing': 'बंद करें',

    'fakeCallTitle': 'नकली इनकमिंग कॉल',
    'fakeCallSubtitle':
        'आपकी रिंगटोन के साथ असली जैसी कॉल, ताकि आप असहज स्थिति से निकल सकें।',
    'fakeCallDefaultCaller': 'मम्मी',
    'callerName': 'कॉल करने वाले का नाम',
    'ringIn': 'कितनी देर में बजे',
    'scheduleCall': 'कॉल सेट करें',
    'fakeCallScheduled': '{time} में फ़ोन बजेगा। गार्जियन खुला रखें।',
    'incomingCall': 'इनकमिंग कॉल',
    'mobile': 'मोबाइल',
    'accept': 'उठाएं',
    'decline': 'काटें',
    'endCall': 'समाप्त',

    'helplinesTitle': 'आपातकालीन हेल्पलाइन',
    'helplinesSource': 'आधिकारिक स्रोत: 112.gov.in',
    'cannotCall': 'डायलर नहीं खुला। {number} खुद डायल करें।',
    'hl112': 'आपातकाल (सभी सेवाएं)',
    'hl112Desc': 'राष्ट्रीय आपातकालीन नंबर — पुलिस, फायर, एम्बुलेंस',
    'hl100': 'पुलिस',
    'hl100Desc': 'पुलिस कंट्रोल रूम',
    'hl1091': 'महिला हेल्पलाइन',
    'hl1091Desc': 'संकट में महिलाओं के लिए पुलिस हेल्पलाइन',
    'hl181': 'महिला हेल्पलाइन (181)',
    'hl181Desc': 'हिंसा झेल रही महिलाओं के लिए सहायता (राज्य संचालित)',
    'hl108': 'एम्बुलेंस',
    'hl108Desc': 'अधिकांश राज्यों में आपातकालीन चिकित्सा सेवा',
    'hl102': 'एम्बुलेंस (102)',
    'hl102Desc': 'कई राज्यों में एम्बुलेंस, मां और शिशु देखभाल',
    'hl101': 'फायर',
    'hl101Desc': 'अग्निशमन और बचाव सेवाएं',
    'hl1098': 'चाइल्ड हेल्पलाइन',
    'hl1098Desc': 'देखभाल और सुरक्षा की ज़रूरत वाले बच्चों के लिए',
    'hl1930': 'साइबर अपराध',
    'hl1930Desc': 'ऑनलाइन धोखाधड़ी और साइबर अपराध की रिपोर्ट करें',
    'hl14567': 'एल्डर लाइन',
    'hl14567Desc': 'वरिष्ठ नागरिकों के लिए सहायता',

    'filterAll': 'सभी',
    'place_police': 'पुलिस',
    'place_hospital': 'अस्पताल',
    'place_pharmacy': 'दवा की दुकान',
    'place_fireStation': 'फायर स्टेशन',
    'searchThisArea': 'इस क्षेत्र में खोजें',
    'myLocation': 'मेरी लोकेशन',
    'gpsOff': 'GPS बंद है',
    'locationPermissionNeeded': 'लोकेशन अनुमति चाहिए',
    'searchingNearby': 'आसपास खोज रहे हैं…',
    'placesFound': 'आसपास {n} जगहें',
    'placesError': 'आसपास की जगहें लोड नहीं हुईं। इंटरनेट जांचें।',
    'placesAttribution':
        'जगहों का डेटा © OpenStreetMap योगदानकर्ता। जानकारी अधूरी हो सकती है — आपात स्थिति में 112 पर कॉल करें।',
    'directions': 'रास्ता',
    'distanceAway': '{d} दूर',

    'contactsTitle': 'भरोसेमंद संपर्क',
    'addContact': 'संपर्क जोड़ें',
    'editContact': 'संपर्क बदलें',
    'chooseFromContacts': 'फ़ोन के संपर्कों से चुनें',
    'enterManually': 'खुद लिखें',
    'name': 'नाम',
    'phone': 'फ़ोन नंबर',
    'relationship': 'रिश्ता',
    'relationshipHint': 'जैसे मां, दोस्त',
    'invalidPhone': 'सही फ़ोन नंबर डालें',
    'duplicatePhone': 'यह नंबर पहले से संपर्क में है',
    'alertOnSos': 'SOS अलर्ट भेजें',
    'alertOnSosHelp': 'आपके SOS और छूटे चेक-इन के अलर्ट पाएंगे',
    'primaryContact': 'मुख्य संपर्क',
    'primaryContactHelp': 'चालू होने पर SOS के बाद इन्हें अपने-आप कॉल होगी',
    'informedConsent':
        'मैंने इस व्यक्ति को बता दिया है कि वे मेरे आपातकालीन संपर्क हैं',
    'noContactsTitle': 'अभी कोई भरोसेमंद संपर्क नहीं',
    'noContactsBody':
        'परिवार या दोस्तों को जोड़ें जिन्हें ज़रूरत पड़ने पर अलर्ट मिले।',
    'noContactsYet': 'पहले एक भरोसेमंद संपर्क जोड़ें।',
    'contactsSummary': '{n} संपर्क(ों) को SOS अलर्ट मिलेगा',
    'primary': 'मुख्य',
    'noSosAlerts': 'SOS अलर्ट नहीं',
    'sendTestSms': 'परीक्षण SMS भेजें',
    'makePrimary': 'मुख्य बनाएं',
    'removeContactTitle': '{name} को हटाएं?',
    'removeContactBody': 'उन्हें अब आपके अलर्ट नहीं मिलेंगे।',
    'contactAdded': '{name} जोड़ा गया',
    'sendIntro': 'उन्हें बताएं',
    'testSent': '{name} को परीक्षण SMS भेजा गया',
    'testFailed': 'SMS नहीं भेजा जा सका',
    'composerOpened': 'SMS ऐप खुला — भेजें दबाएं',

    'historyTitle': 'इतिहास',
    'noHistory': 'आपके SOS अलर्ट, यात्राएं और लोकेशन शेयर यहां दिखेंगे।',
    'incidentSos': 'SOS अलर्ट',
    'incidentMissedCheckIn': 'छूटा चेक-इन अलर्ट',
    'incidentJourney': 'यात्रा',
    'incidentLiveShare': 'लाइव लोकेशन शेयर',
    'statusActive': 'चालू',
    'statusArrived': 'पहुंचे',
    'statusEnded': 'समाप्त',
    'statusCancelled': 'रद्द',
    'statusEscalated': 'अलर्ट भेजा',
    'messagesCount': '{n} संदेश',
    'failedCount': '{n} विफल',
    'clearHistoryTitle': 'इतिहास साफ़ करें',
    'clearHistoryBody': 'इस फ़ोन से सभी पूरे हो चुके रिकॉर्ड हटाएं?',
    'status': 'स्थिति',
    'started': 'शुरू',
    'ended': 'समाप्त',
    'checkInDeadline': 'चेक-इन समय',
    'lastLocation': 'अंतिम लोकेशन',
    'pointsRecorded': 'दर्ज बिंदु',
    'noLocationRecorded': 'कोई लोकेशन दर्ज नहीं हुई',
    'noMessagesSent': 'कोई संदेश नहीं भेजा गया।',

    'settingsTitle': 'सेटिंग्स',
    'profileSection': 'प्रोफ़ाइल',
    'editProfile': 'प्रोफ़ाइल बदलें',
    'editProfileHint': 'नाम, आपातकालीन नंबर, चिकित्सा जानकारी',
    'language': 'भाषा',
    'sosSection': 'SOS',
    'countdown': 'भेजने से पहले उलटी गिनती',
    'updateInterval': 'SMS से लोकेशन अपडेट',
    'autoCall': 'SOS के बाद कॉल',
    'autoCallOff': 'कॉल न करें',
    'autoCallPrimary': 'मुख्य संपर्क को कॉल',
    'autoCallEmergency': '{number} पर कॉल',
    'shakeToSos': 'हिलाकर SOS',
    'shakeToSosHelp': 'गार्जियन खुला होने पर फ़ोन ज़ोर से हिलाएं',
    'sirenOnSos': 'SOS पर सायरन',
    'sirenOnSosHelp': 'SOS भेजने पर तेज़ सायरन बजाएं',
    'journeySection': 'यात्रा चेक-इन',
    'notifyJourneyStart': 'यात्रा शुरू होने पर संपर्कों को बताएं',
    'notifyArrival': 'पहुंचने पर संपर्कों को बताएं',
    'liveMapSection': 'लाइव मैप',
    'trackingServer': 'लाइव-मैप सर्वर',
    'trackingServerOff': 'सेट नहीं — लाइव शेयर SMS अपडेट से होगा',
    'trackingServerHelp':
        'वैकल्पिक। संपर्कों को रियल-टाइम मैप लिंक भेजने के लिए अपने गार्जियन ट्रैकिंग सर्वर का पता डालें।',
    'serverUrl': 'सर्वर का पता',
    'invalidUrl': 'सही http(s) पता डालें',
    'testConnection': 'जांचें',
    'serverOk': 'जुड़ गया',
    'serverUnreachable': 'सर्वर तक नहीं पहुंच सके',
    'moreSection': 'और',
    'deleteAllData': 'सारा डेटा हटाएं',
    'deleteAllDataHelp': 'इस फ़ोन से प्रोफ़ाइल, संपर्क और इतिहास हटाता है',
    'deleteAllDataConfirm':
        'यह इस फ़ोन से आपकी प्रोफ़ाइल, संपर्क और इतिहास हमेशा के लिए हटा देगा और चालू SOS या शेयरिंग बंद कर देगा।',
    'aboutLine': 'गार्जियन 2.0 · आपका डेटा इसी फ़ोन पर रहता है',

    'notifSosTitle': 'SOS भेजा गया',
    'notifSosBody':
        '{total} में से {sent} संपर्क(ों) को अलर्ट भेजा गया। SOS बंद करने तक लोकेशन अपडेट जारी रहेंगे।',
    'notifTrackingTitle': 'गार्जियन आपकी लोकेशन शेयर कर रहा है',
    'notifTrackingSos': 'SOS चालू — संपर्कों को लोकेशन अपडेट मिल रहे हैं',
    'notifTrackingJourney': 'यात्रा चेक-इन चल रहा है',
    'notifTrackingLive': 'लाइव लोकेशन शेयरिंग चालू है',
    'notifJourneyReminderTitle': 'क्या आप सुरक्षित हैं?',
    'notifJourneyReminderBody':
        'आपका चेक-इन {min} मिनट में समाप्त होगा। चेक-इन करने या समय बढ़ाने के लिए गार्जियन खोलें, वरना संपर्कों को अलर्ट जाएगा।',
    'notifJourneyEscalatedTitle': 'चेक-इन छूटा — संपर्कों को अलर्ट भेजा गया',
    'notifJourneyEscalatedBody':
        '{total} में से {sent} संपर्क(ों) को अलर्ट भेजा गया। सुरक्षित होने पर SOS बंद करने के लिए गार्जियन खोलें।',
    'sosHintLite':
        '{sec} सेकंड की उलटी गिनती के बाद आपका SMS ऐप {n} संपर्क(ों) के लिए अलर्ट और लोकेशन के साथ खुलेगा — भेजें दबाएं।',
    'countdownBodyLite':
        'आपका SMS ऐप {n} संपर्क(ों) के लिए अलर्ट और लोकेशन के साथ खुलेगा। भेजें दबाएं।',
    'sosUpdatesInfoLite':
        'यह संस्करण बैकग्राउंड में SMS नहीं भेज सकता। ताज़ा लोकेशन भेजने के लिए “अलर्ट फिर से भेजें” दबाएं। लाइव-मैप सर्वर से संपर्क आपको लगातार देख सकते हैं।',
    'sendAlertAgain': 'अलर्ट फिर से भेजें',
    'liveShareViaSmsLite':
        'संपर्कों को आपकी वर्तमान लोकेशन SMS से मिलेगी (आप भेजें दबाएं)। लगातार ट्रैकिंग के लिए सेटिंग्स में लाइव-मैप सर्वर जोड़ें।',
    'viaSmsOnce': 'लोकेशन एक बार SMS से भेजी गई',
    'journeyExplainerLite':
        'समय खत्म होने से 2 मिनट पहले रिमाइंडर मिलेगा। चेक-इन न करने पर गार्जियन आपको सूचित करेगा और संपर्कों के लिए SMS खोलेगा — यह संस्करण इसे अपने-आप नहीं भेज सकता।',
    'journeyAutoAlertLite':
        'चेक-इन न करने पर गार्जियन आपसे संपर्कों को अलर्ट करने को कहेगा।',
    'notifJourneyMissedTitle': 'चेक-इन छूट गया',
    'notifJourneyMissedBody':
        'संपर्कों को अलर्ट भेजने के लिए अभी गार्जियन खोलें।',
    'aboutLineLite': 'गार्जियन 2.0 लाइट · आपका डेटा इसी फ़ोन पर रहता है',
    'editionLiteNote':
        'यह संस्करण अलर्ट के लिए आपका SMS ऐप खोलता है — आप भेजें दबाएं। पूरी तरह स्वचालित SMS अलर्ट के लिए USB से पूर्ण संस्करण इंस्टॉल करें।',
    'notifSosComposerTitle': 'SOS तैयार - भेजें दबाएं',
    'notifSosComposerBody':
        'आपका SMS ऐप अलर्ट और लोकेशन के साथ खुला है। संपर्कों को अलर्ट करने के लिए भेजें दबाएं।',
    'sosActiveCardBodyComposer':
        'अलर्ट आपके SMS ऐप में खुला - पक्का करें कि आपने भेजें दबाया।',
    'sosComposerSummary': 'अलर्ट आपके SMS ऐप में खुला - भेजें दबाएं',

    // SMS permission blocked (full edition)
    'smsOffTitle': 'अपने-आप SMS बंद है',
    'smsOffBody':
        'SMS की अनुमति दें ताकि अलर्ट अपने-आप जाएं। तब तक SOS आपका SMS ऐप अलर्ट के साथ खोलेगा और आप भेजें दबाएंगे।',
    'smsOffRestrictedBody':
        'गार्जियन फ़ाइल से इंस्टॉल हुआ है, इसलिए Android इसके लिए SMS रोक रहा है। अनुमति देने तक SOS आपका SMS ऐप अलर्ट के साथ खोलेगा और आप भेजें दबाएंगे।',
    'allowSms': 'SMS की अनुमति दें',
    'howToAllow': 'कैसे चालू करें',
    'openAppSettings': 'ऐप सेटिंग्स खोलें',
    'done': 'हो गया',
    'smsRestrictedTitle': 'गार्जियन को SMS की अनुमति दें',
    'smsRestrictedIntro':
        'Android 15 और नए वर्ज़न फ़ाइल से इंस्टॉल किए गए ऐप (WhatsApp, Drive, ब्राउज़र) के लिए SMS रोकते हैं। “App was denied access to SMS” संदेश इसी वजह से आता है। इसे सिर्फ़ एक बार चालू करना है:',
    'smsRestrictedStep1': 'नीचे “ऐप सेटिंग्स खोलें” दबाएं।',
    'smsRestrictedStep2':
        'ऊपर दाईं ओर ⋮ दबाएं, फिर “Allow restricted settings” (प्रतिबंधित सेटिंग की अनुमति दें) चुनें और PIN या फ़िंगरप्रिंट से पुष्टि करें।',
    'smsRestrictedStep3':
        'अनुमतियां (Permissions) → SMS → अनुमति दें खोलें, फिर गार्जियन में वापस आएं।',
    'smsRestrictedNoMenu':
        '⋮ मेन्यू में “Allow restricted settings” नहीं दिख रहा? एक बार अनुमतियां → SMS खोलें, “Restricted setting” संदेश बंद करें, वापस जाएं और ⋮ फिर से दबाएं।',
    'smsRestrictedMeanwhile':
        'तब तक भी SOS काम करता है: आपका SMS ऐप अलर्ट और लोकेशन के साथ खुलेगा और आप भेजें दबाएंगे।',
    'smsAllowedNow': 'SMS की अनुमति मिल गई। अब अलर्ट अपने-आप भेजे जाएंगे।',
  };
}

class _AppStringsDelegate extends LocalizationsDelegate<AppStrings> {
  const _AppStringsDelegate();

  @override
  bool isSupported(Locale locale) =>
      AppStrings._maps.containsKey(locale.languageCode);

  @override
  Future<AppStrings> load(Locale locale) async =>
      AppStrings(locale.languageCode);

  @override
  bool shouldReload(_AppStringsDelegate old) => false;
}
