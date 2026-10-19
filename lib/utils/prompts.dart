/// Gentle daily writing prompts. One is picked per day.
class Prompts {
  Prompts._();

  static const _all = [
    'What made you smile today?',
    'Describe a moment you want to remember forever.',
    'What are you grateful for right now?',
    'What did you learn today?',
    'Who made your day better, and how?',
    'What challenged you today, and how did you handle it?',
    'What would make tomorrow great?',
    'What surprised you today?',
    'Where did you feel most like yourself today?',
    'What is something small that brought you joy?',
    'What are you looking forward to?',
    'If today had a soundtrack, what would it be?',
    'What did you let go of today?',
    'Describe today in three words — then tell the story.',
  ];

  static String forDay(DateTime day) {
    final dayOfYear = day.difference(DateTime(day.year)).inDays;
    return _all[(dayOfYear + day.year) % _all.length];
  }
}
