import 'package:flutter/material.dart';

/// Shared faction accent colors (based on `profiles.faction` values).
///
/// - Uses the exact faction names stored in Supabase.
/// - Returns a neutral gray for Wanderer, missing, or unknown values.
class FactionAccent {
  static const Map<String, Color> _factionAccent = {
    // Slightly muted variants of the original faction identity colors.
    'Renaissance Rebels': Color(0xFFC95962),
    'Madthletes': Color(0xFF25AFCB),
    'Blueprint Builders': Color(0xFFF08176),
    'Vital Intelligence': Color(0xFF2C7EF0),
    'Catalysts': Color(0xFF50C664),
    'Byte Force': Color(0xFFE36FB4),
    'Curators': Color(0xFFE4814B),
    'Luminaries': Color(0xFF6263DF),
    'The Ensemble': Color(0xFF9147D4),
    'Playmakers': Color(0xFFCEB54E),
    'All-Stars': Color(0xFFABBC57),
  };

  static const String wandererValue = 'Wanderer';
  static const Color neutralAccent = Color(0xFF9CA3AF);

  static bool isWanderer(String? faction) =>
      (faction ?? '').trim() == wandererValue;

  static Color accentForFaction(String? faction) {
    final key = (faction ?? '').trim();
    if (key.isEmpty || key == wandererValue) return neutralAccent;
    return _factionAccent[key] ?? neutralAccent;
  }

  static Color accentForFactionName(String factionName) =>
      _factionAccent[factionName.trim()] ?? neutralAccent;
}
