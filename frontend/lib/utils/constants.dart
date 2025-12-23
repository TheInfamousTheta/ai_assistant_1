import 'package:flutter/material.dart';

/// Defines the available voice profiles for the agent.
/// Keys are the display names, values are the backend IDs.
class AgentConstants {
  static const Map<String, String> voices = {
    "Zion (Male, Bilingual)": "en-US-zion",
    "Ken (Male, Deep)": "en-US-ken",
    "Aara (Female, Hindi)": "hi-IN-aara",
    "Falcon Default": "en-US-falcon",
  };

  static const String defaultVoice = "Zion (Male, Bilingual)";

  // App Theme Colors
  static const Color primaryColor = Colors.cyanAccent;
  static const Color secondaryColor = Colors.amber;
  static const Color scaffoldBackground = Color(0xFF111111);
  static const Color cardBackground = Color(0xFF222222);
}