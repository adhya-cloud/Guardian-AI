import 'package:flutter/material.dart';

/// A national helpline in India.  Titles and descriptions are string keys.
class Helpline {
  const Helpline(
    this.number,
    this.titleKey,
    this.descKey,
    this.icon,
    this.color,
  );

  final String number;
  final String titleKey;
  final String descKey;
  final IconData icon;
  final Color color;
}

/// Source: Government of India ERSS (https://112.gov.in/) and ministry
/// helpline listings.  Some numbers (108, 181) are run by state governments
/// and may differ locally; 112 works everywhere in India.
const indiaHelplines = <Helpline>[
  Helpline('112', 'hl112', 'hl112Desc', Icons.emergency, Color(0xFFD92D20)),
  Helpline('100', 'hl100', 'hl100Desc', Icons.local_police, Color(0xFF1D4ED8)),
  Helpline('1091', 'hl1091', 'hl1091Desc', Icons.woman, Color(0xFFC11574)),
  Helpline('181', 'hl181', 'hl181Desc', Icons.support_agent, Color(0xFFC11574)),
  Helpline(
    '108',
    'hl108',
    'hl108Desc',
    Icons.medical_services,
    Color(0xFFB42318),
  ),
  Helpline(
    '102',
    'hl102',
    'hl102Desc',
    Icons.pregnant_woman,
    Color(0xFFB42318),
  ),
  Helpline(
    '101',
    'hl101',
    'hl101Desc',
    Icons.local_fire_department,
    Color(0xFFDC6803),
  ),
  Helpline('1098', 'hl1098', 'hl1098Desc', Icons.child_care, Color(0xFF0E7C66)),
  Helpline('1930', 'hl1930', 'hl1930Desc', Icons.security, Color(0xFF6941C6)),
  Helpline('14567', 'hl14567', 'hl14567Desc', Icons.elderly, Color(0xFF0E7C66)),
];

const emergencySourceUrl = 'https://112.gov.in/';
