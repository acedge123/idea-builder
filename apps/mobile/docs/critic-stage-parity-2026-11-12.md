# MusicDNA build 13: web / Flutter Critic flow review

Tickets: AB-73, AB-67, AB-76. Candidate: `0.1.1+13`.

## Reference and scope

Reviewed Music DNA web `main` at `9da9a7137bf7c612b47ba5269fff948b22326e03`, including every changed file since PR #46's merge `8e2c084`. This covers the revised interview screen and hook, history/progress labels, server hunch, shared waiting-copy module/endpoint/tests, auth errors/recovery page, contract/handoff, and generated migration/types/route changes. Existing report, archetype and model paths are reused; this review introduces no new scoring or writing pipeline.

The production `/api/public/version` reported this same SHA during this review. An unauthenticated GET of `/api/v1/critic-fillers` matched the bundled JSON exactly. These public checks do not establish signed-in acceptance or database function access.

The bundled `assets/copy/critic-fillers.json` is the serialized `fillers-v1` exports of that web revision, not a Dart rewrite. SHA-256: `dc0a9cb8ed6a76a35e16345701d4866e4e2b98bb41f6e21a1526750037e756d8`.

## Flutter behavior

- The first matchup load uses the shared opening wait. After a pick, hide both song cards immediately and retain only `YOU PICKED · title`; the old matchup cannot flash behind the new read.
- Show the neutral quip immediately. Use only the server `hunch` (`against`, `with`, `early`; missing means `early`). Advance each line after 2.5 seconds, preserve setup/punchline order, freeze the sequence after its first change and hold the last line. Same-decade quips replace the person pair exactly as in `fillerLines`.
- The line occupies a top-aligned slot with the same short rise/fade treatment (700 ms); reduced-motion rendering is immediate. Large text can expand the slot without clipping.
- Save the vote with `defer_read: true`; fetch its exact-cursor read and the next pairing concurrently. Keep the next pairing hidden and untappable until the read arrives, fails or reaches 20 seconds. Then show the saved Critic text above the next pairing automatically, without a Next button.
- A slow/failed read shows the shared “I'll come back to that one.” fallback. It does not retry the model. A late read cannot replace a newer choice. Failed next-pairing retries fetch the pairing only, never repeat the vote or restart narration.
- Skips show only a shared skip quip with an artist from the skipped pair, including the current pre-2000/recent-song rules. They never display a stale picked-song receipt. Answered-choice progress/history exclude skips while server pairing/reaction keys are preserved.
- After choice three, “That's not me — push back” is an optional link below the song choices. Its 1–500-character reply uses `/pushback`, preserves its mutation ID for retries, verifies the saved response and restores self-report history. It is never a vote or a mandatory screen. Existing compact reaction controls remain below the choices.
- No Q3 checkpoint or Q4 early-reading interruption is restored. These follow Alan's explicit direction even though current web still contains the Q4 checkpoint (see below). Choice six goes directly to the final report without an extra running-read model request, preserving the previously accepted native completion path.
- Common authentication failures use controlled language by SDK code, including duplicate signup → Sign in instead with email retained and password cleared. The existing web auth page owns password recovery; native opens `https://www.musicdna.fm/auth?mode=forgot`, using the validated direct entry in the companion web PR (also available when a separate browser session is signed in). Deploy that web entry before shipping this link. No credentials or email are added to the URL. A failed account-deletion request now stays on Account and shows an error; this does not establish that backend deletion works.

The copy store refreshes once per app launch without auth headers or user data, validates the complete response, and retains the bundled fallback if unavailable/invalid. An interview pins a copy snapshot so an app-launch refresh cannot change its line ordering. Retired “OK boomer” / “Music is in your blood” copy is rejected. No package upgrades, keys, flags or production changes are included.

## Findings in reviewed web main and companion correction

1. **Q4 still interrupts the six-choice flow.** `src/hooks/use-interview.ts:650` sets `milestone` when `entries.length === 4`; `src/routes/onboarding.tsx` hides the pairing and displays the early-reading screen. Remove that automatic checkpoint to match Alan's instruction and native.
2. **The optional Q3 link is unreachable in the current flow.** `holdNext` starts false and is only ever set false. The only Q3 `HalftimePushback` is guarded by `holdNext && entries.length === 3`; the milestone is now Q4 only. Place the existing compact pushback component in the normal post-choice-three read/pairing view. Do not reintroduce a held screen or Next button.
3. **Two executable migrations create the same function.** `supabase/migrations/20261112183759_musicdna_deferred_read_cursor.sql` and `20261112192158_b34486e3-76fd-4d86-90fe-2550382ec0ea.sql` differ only by final newline and both use `CREATE FUNCTION public.save_musicdna_deferred_read(...)`. Clean replay will collide on the second file. Reconcile one canonical executable with the actual applied history/receipt; do not rerun it or rewrite live history as part of a UI fix. The generic handoff still names the older filename and is not a current deployment receipt. Live database history was not inspected in this review. Track with AB-75.
4. **One older contract paragraph is stale.** The appended section of `docs/musicdna/experience-contract-v1.md` still describes `FILLER_PERSON[wait*2]` / `[wait*2+1]`. Actual web code and the dedicated `flutter-critic-fillers-handoff.md` use `person[wait % person.length]` as a nested setup/punchline group. Flutter follows the executable code and dedicated current handoff.

Items 1, 2 and 4 are corrected on the separate web branch `codex/musicdna-critic-ux-parity`; the duplicate migration remains open under AB-75. No shared branch was changed. The web hook currently waits for the running read before requesting the next matchup; Flutter already overlaps these requests while retaining the same visible order.

## Verification and release boundary

- Full Flutter suite: 248 tests passed, one optional deployed-contract capture skipped without its external fixture. Analyzer: no issues.
- iOS Simulator compilation with existing production API configuration succeeded.
- Installed candidate in an iPhone 17 Pro Simulator: signed-out landing has Sign in / Start reading; the sign-in form, recovery link and submit control fit above the fold. No credentials were entered, reset emails sent, accounts deleted or model calls made during that visual check.
- Timing/ordering, hidden pairings, double taps, late reads, timeout recovery, retry without repeated votes/model calls, six-pick completion, shared-copy rules, pushback retry/history, auth recovery actions, large text and reduced motion are covered with controlled test doubles. These checks are not live listener/model acceptance.
- Signed-in physical-device walkthrough, actual recovery email flow and successful backend account deletion still require acceptance before public resubmission. Build 13 is not archived/uploaded by this PR. Alan retains merge and release approval.
