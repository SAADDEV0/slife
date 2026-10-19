import 'package:flutter/material.dart';

enum Mood {
  rough('😣', 'Rough', Color(0xFF6E7FA8)),
  low('😕', 'Low', Color(0xFF9B87D6)),
  okay('😐', 'Okay', Color(0xFFE9B949)),
  good('🙂', 'Good', Color(0xFF3FBF86)),
  amazing('🤩', 'Amazing', Color(0xFFFF7A59));

  const Mood(this.emoji, this.label, this.color);

  final String emoji;
  final String label;
  final Color color;

  static Mood? fromIndex(int? index) {
    if (index == null || index < 0 || index >= values.length) return null;
    return values[index];
  }
}
