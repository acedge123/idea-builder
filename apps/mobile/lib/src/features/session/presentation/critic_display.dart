/// Mirrors web ReadMoment formatting. Frozen prose remains available in history.
String compactCriticRead(String text) => text
    .replaceAll(RegExp(r'\s*\(\d+ supporting(?: choices)?, \d+ against\)'), '')
    .trim()
    .replaceFirst(
      RegExp(r'^.*?\. (?=One choice |A tentative lean |The evidence for )'),
      '',
    );
