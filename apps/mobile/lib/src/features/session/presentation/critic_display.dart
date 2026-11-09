/// Presentation only. Stored claims, qualifications and history stay intact.
/// Avoid first-sentence slicing: song titles can contain punctuation and a
/// qualification can be in the next sentence.
String criticDisplayLine(String text) => text
    .replaceAll(RegExp(r'\s*\(\d+ supporting(?: choices)?, \d+ against\)'), '')
    .trim();

/// Acknowledgment copy derives only from a successful server effect. It never
/// claims a new matchup was selected when the effect is unknown.
String reactionDisplayMessage(String effect) => switch (effect) {
  'harder_pairing' => 'Fine. Try these.',
  'retest_pairing' => "Fair. Let's try another.",
  'no_alternative' =>
    'No other matchup available right now. Your call on these two stands.',
  _ => "Heard you. Let's keep going.",
};
