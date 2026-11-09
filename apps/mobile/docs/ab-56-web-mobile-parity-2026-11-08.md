# AB-56: Lovable review and mobile parity

November 8, 2026. [AB-56](https://youtrack.thegig.agency/issue/AB-56) remains open for Alan's TestFlight acceptance.

## Reviewed baseline

- Web: `acedge123/music-dna@2dfa9c0b8756188b3b9656b24cc52afce27d50ae`. Vercel confirms www.musicdna.fm READY on `dpl_AEgKfrqkY1hJCg7ck4n7gHfKxRwH`. Reviewed critic-first components, hook, display helper, presentation/coverage notes and the subsequent hidden-rationale update.
- Mobile: `The-Gig-Agency/idea-builder@83700acc452dab640589ed4be98a574fa1b5cf00`, `apps/mobile`. Installed baseline is TestFlight 0.1.1 (4); candidate is 0.1.1 (5).
- Earlier web PR #27 is not included. Lovable's main implementation supersedes that proposed presentation.

Lovable replaced the growing active transcript with one current response, a history drawer, illustrated song rows, inline reaction acknowledgments, expandable evidence and a conversation with the original read collapsed. The latest update hides selection rationale and test prompts. Saved readings and server-selected pairings remain intact.

Remaining review findings:

1. Lovable's documented phone walkthrough was a responsive local web preview, not physical native/TestFlight acceptance.
2. Its catalogue note reports eight Pop pairings covering 13 previously unpaired Pop songs. The remaining 71 unpaired songs tagged `general` need an editorial lane decision. This is not a complete inventory fix. No migration or live catalogue audit was performed in this task.
3. Web places reactions before song cards. Mobile deliberately makes them optional below the choices, following Alan's feedback.
4. Web's `readingLead` extracts a first sentence using punctuation. That can truncate abbreviations (`Mr. Brightside`) or omit a following qualification. Mobile retains complete saved wording, removing only the specific numeric supporting/against parenthetical. Full original wording stays available; no narrative is invented.

## Mobile implementation

Standard presentation work using the existing widget → Cubit → repository → API path; no new service or state-management layer.

| Stage | Candidate behavior |
| --- | --- |
| Opening | Latest song/reply and current input, 1–3 progress, expandable earlier entries, original capitalization. |
| Pairings | One current response, full-history sheet, decorative vinyl thumbnails, server-answered progress. Neutral invitations replace rationale; stored test prompts stay off-screen. |
| Reactions | Optional disclosure after cards and Skip. Opening it submits nothing; pending actions allow only the original retry. Acknowledged effects map to the short web copy. Unknown effects do not claim a new pairing. Prove it uses the existing harder action. |
| Reveal | Qualified saved headline, authorized examples and counter-read, primary Argue with me, explicit secondary sharing, full frozen content under details. Missing examples are described as missing without inferring eligibility. |
| Conversation | Original/version collapsed, transcript first, keyboard-safe composer. Saved fallback stays verbatim with plain-language explanation. Voice/context buttons fill a draft only, never send or overwrite existing/pending text. Draft edits do not scroll history. |
| Failure | One recoverable error. EXPERIENCE_DISABLED becomes understandable availability copy while retaining failed/503 behavior; the gate is not bypassed. |

Choice locks, reaction mutation IDs, server stop decisions, immutable feedback, result versions, share verification and conversation reconciliation remain in their existing layers. No scoring, eligibility or model requests were added to Flutter.

Podfile and all project configurations now target iOS 15, addressing Alan's earlier Apple warning. Devices on iOS 13/14 cannot install this update.

## Verification

- `flutter analyze --no-pub`: clean.
- `flutter test --no-pub --reporter expanded`: 131 passed; one optional live-contract capture test skipped because no capture was supplied. No new authenticated production or model test ran.
- Normal `lib/main.dart` unsigned release compilation: passed, 0.1.1 (5), bundle fm.musicdna.app, minimum iOS 15.0. See [build receipt](ab56-build-receipt.json). Local artifact: `build/ios/iphoneos/Runner.app`; not a signed distribution IPA.
- Checks cover card/reaction order, pending retries, full history, opener capitalization/history, qualified wording, hidden prompts, effect acknowledgments, one gate failure, draft-only fallback prompts, immutable versions/sharing, and small-screen/large-text/keyboard recovery.

Captures use production widgets and real app fonts on an iPhone 17e / iOS 26.4 simulator: 390 × 844 logical canvas, PNGs at 3×. They are visibly labeled offline UI fixtures, not real readings, physical device screenshots, persistence evidence or proof of improved readings.

| State | Capture |
| --- | --- |
| Choices before optional reactions | [Pairing](ab56-captures/ab56-pairing.png) |
| Inline acknowledgment | [Reaction](ab56-captures/ab56-reaction.png) |
| Evidence-limited result | [Reveal](ab56-captures/ab56-reveal.png) |
| Conversation and saved fallback | [Conversation](ab56-captures/ab56-conversation.png) |

Reproduce with `flutter run -t tool/ab56_mobile_preview.dart`; add `--dart-define=CAPTURE_REFERENCE=true` for captures. This debug-only offline entry must never ship. Widget-test goldens use test fonts for layout checks.

## Remaining release order

1. Review/merge the mobile PR. Check Apple's existing uploads before reserving build 5; increment again if consumed elsewhere.
2. Verify the actual beta deployment, normal authenticated V1 access and client origin before archiving. Build 4 uses `musicdna-beta-alan-edgetts-projects.vercel.app`; the last verified working target is isolated `dpl_E9Tboa3WPdKWXku7Cni9iLPRmdu8` / `music-dna@19c1e73ab61c59fa4fbbf09f4134f482d7a4967a`. This candidate preserves that hostname. Repointing it to production previously caused V1 parity acceptance pending and was rolled back. It must not silently follow www deployments. A beta matching current web backend needs compatibility checks before replacing the working target. UI parity alone does not establish backend/response parity.
3. Archive the normal entry from exact merged source and approved public beta config. Verify version/build/team/origins, sign/export/upload through EK Enterprises, then confirm Apple processing and internal installability. No archive, distribution export or upload is claimed here.
4. Alan reviews beside web: three openers, unfamiliar/skip path, server stop, history, reactions/retry, reveal, accuracy feedback, chat/fallback, back/resume, keyboard, VoiceOver and large text. Do not submit ratings on his behalf.
5. Keep AB-56 open until acceptance. Catalogue/editorial coverage and critic quality remain separate from presentation acceptance and AB-52's experiment.

No production migrations, aliases, flags, credentials, learning/export settings, schedules, enrollment, model tests or real-user ratings changed.
