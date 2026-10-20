# TGA-315 approved-reference alignment

Review candidate, October 20, 2026 (America/Los_Angeles). Continues the previously merged TGA-315 foundation; not a rewrite of the session transport.

## Source and scope

- Flutter base: `idea-builder` main `d477c9f` (merged PR #11).
- Branch: `codex/tga-315-approved-reference`.
- ACE-approved web reference: `music-dna` review head `5308623213f2208c7a29d750baa77cdc8a3ffb1e`, merged at `b127bf5b40632c75bbbef5b3c7c0cd109f501c3c`; approval recorded on TGA-314 on October 20.
- Native widgets remain passive. Repository mapping carries the actual server-selected next prompt and answered limit; the Cubit owns selection/reaction state; presentation grouping preserves server exchange order without computing eligibility, scoring, revisions or critic copy in Dart.

Latest feedback and the evolving read stay visible once, with older choice/read/skip/reaction groups expandable in chronological order. Explicit server direction/tier determines the editorial label. Revisions show the prior claim, changed choice and saved thesis without repeating the new interpretation. Stored reactions restore their label without another active submit row.

Choices use stacked, neutral, serif cards with year metadata, a gold selected border and a dimmed alternative; lane labels, extra icon controls and the selected glow are removed. Selected/disabled semantics are explicit. A pending selected choice blocks the other card and Skip after recovery; acknowledged feedback remains available when fetching the next step fails. This is in-memory state protection, not restart-safe mutation acceptance.

The session scrolls to the latest exchange when the server advances and to the result when it arrives. Reduced-motion requests remove the scroll/card animation. A server-completed reaction automatically opens the saved result, matching completion after a normal choice.

## Evidence

- `flutter analyze --no-pub`: clean.
- `flutter test --no-pub`: 120 tests passed. Added coverage includes full-page active-exchange scrolling, history expansion/deduplication, stored reaction restoration, revision provenance, authoritative reaction completion, acknowledged feedback after failure, prompt mapping, selected semantics, and a 320px/200% text case.
- `flutter build ios --simulator --debug --no-pub`: passed for the normal application entry point.
- A separate debug-only reference entry also built and ran on iPhone 17e / iOS 26.4, with real app fonts and frozen output from the approved web fixture engine.
- No production API requests, migration, public V1 enablement, release configuration, Apple version/build change or upload.

## Equal-viewport comparison

All comparison canvases use **390 × 844 logical pixels**. Flutter renderer PNGs are saved at 3× (1170 × 2532); web browser captures are 1×. These are synthetic fixture presentations, not authenticated persistence, device screenshots or end-to-end production evidence. The PNGs are exported directly from a RepaintBoundary in the debug tool running on the iPhone simulator. Native system chrome/safe areas are outside this canvas.

| State | Approved web | Flutter renderer |
| --- | --- | --- |
| Selected long title | [Web](tga-315-captures/web-selected.jpg) | [Flutter](tga-315-captures/tga315-selected.png) |
| Working theory | [Web](tga-315-captures/web-theory.jpg) | [Flutter](tga-315-captures/tga315-theory.png) |
| Genuine revision | [Web](tga-315-captures/web-revision.jpg) | [Flutter](tga-315-captures/tga315-revision.png) |

The reference book is local-only and not imported by the production entry point:

```sh
flutter run -t tool/tga315_reference.dart
flutter run -t tool/tga315_reference.dart --dart-define=CAPTURE_REFERENCE=true
```

Capture mode prints each PNG location in the simulator app's temporary directory. `tool/tga315_reference_data.dart` contains frozen output from the approved TypeScript engine and shared catalog fixture; Dart does not recalculate a theory or revision. The existing test-font golden is layout evidence only.

## Acceptance still required

- ACE review of the Flutter comparison captures. Web approval does not automatically approve native output.
- Hands-on physical iPhone/VoiceOver, real keyboard/safe-area behavior, and reduced-motion verification remain for TGA-321. Simulator UI control was unavailable in this session; no hands-on interaction is claimed.
- Authenticated client history/reaction persistence and restart/retry acceptance remain unverified for this changed Flutter UI. Backend persistence acceptance is separate evidence.
- Authoritative, session-bound opener recovery remains TGA-277; the existing local opener cache remains in use. The current REST opener reads mutable profile data, so it is not treated here as a frozen historical session opener.
- Durable pending mutations, auth recovery and crash-safe reconciliation remain TGA-278/305. This change does not claim exactly-once delivery across app restarts.
- `MUSICDNA_EXPERIENCE_V1` remains off by default. Release/production activation remains gated on acceptance. TGA-312 same-choice challenges remain separate.

Review the code and captures now; do not mark full TGA-315/device/release acceptance complete based solely on these tests.
