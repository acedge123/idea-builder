# AB-78: paired-choice Critic flow, mobile build 15

Target: `acedge123/idea-builder`, `apps/mobile`, version `0.1.2+15`.
Version 0.1.1 is already publicly released; a future App Store update requires a
new marketing version. This candidate can be tested in TestFlight before any
separately approved public submission.
Mobile baseline: `63bf6f0` (merged PR32 / build14 source).
Reviewed backend handoff: `acedge123/music-dna` `39932ab`:

- `docs/musicdna/flutter-critic-fillers-handoff.md`
- `docs/musicdna/experience-contract-v1.md`

## Behavior

The server owns each interview's `per_pick` or `checkpoints` assignment. Flutter
advertises `X-MusicDNA-Interview-Flow: checkpoints-v1` at normal session creation,
retains the returned `flow`, and looks up the **owned session's** saved assignment
with `GET /api/v1/interview-flow?session=<id>` on opening/resume. A successful
lookup must include contract 1, a known flow and `saved: true`. Authentication,
not-found, unavailable and unknown-contract failures show restore/retry; they do
not silently pick another flow. Only a missing legacy route can retain legacy
behavior; a previously known checkpoint session cannot use that fallback.

With checkpoints assigned:

1. Answer 1, 3 or 5: saved vote, shared static quip held for 2.5 seconds, then the
   next server pairing automatically. No running-read call for those answers.
2. Answer 2: POST `/read` with `after_pairing_id` and `answered`; show the Critic
   alone. The prefetched pairing remains hidden until **Next pairing**.
3. Answer 4: another Critic screen, **Get my reading now** (normal `/reveal` with
   `finish_early: true`) or **Keep going (final pair)**.
4. Answer 6: server completion and one final reading, with no extra running read.
5. Checkpoints include the compact optional self-report pushback. Its mutation
   key is stable across retries of the same reply and independent at each
   checkpoint. No separate Q3 prompt or duplicate reaction section appears in
   this flow. Per-pick sessions keep their existing controls.

Skip events do not increase answered-choice counts. Pre-drafting is requested
only for current pairings that could end at 2, 4 or 6 (and remains disabled for
Explore as before). The shared copy bundle and remote refresh are reused without
new Dart-authored quips. Model/scoring/evidence/consent rules are unchanged.

The 20-second narration deadline settles to the shared "still chewing" message.
The user can explicitly retry the exact POST `/read` position or continue; picks
are not resubmitted. Late reads are discarded after timeout, navigation or a
changed position. Prefetch failure has a separate retry and cannot hide an
already-arrived read. Decision timing runs only while actual song cards are
available, excluding checkpoint reading/wait time.

On resume after answered 2 or 4, history is loaded **before any upcoming cards
are painted**. The saved read for that position is restored; an absent read
shows retry/continue without automatically calling a model. History failure is a
restore error, never permission to skip the checkpoint. Continuing and reloading
before making another choice reopens the checkpoint, matching the documented
web behavior; the flow itself remains fixed.

## Verification

Automated tests cover four-choice and six-choice completion, held next cards,
2.5-second odd-pick transitions, repeated skips, exact read cursors, saved and
missing-read checkpoint resume, unavailable history, read-before-prefetch races,
timeout/late delivery, independent checkpoint pushbacks, HTTP ownership/outage
propagation, saved-flow binding, capability/flow storage and a 320px phone at
1.6x text. Existing per-pick regression tests remain in place.

These are local unit/integration/widget checks with test doubles. They are not
live authenticated backend, physical-device or TestFlight acceptance.

## Deployment / acceptance still required

- Lovable's backend changes must be deployed and verified independently; its
  reported flow assignment tests do not establish HTTP ownership or failed-save
  behavior. Keep `MUSICDNA_CRITIC_CHECKPOINTS` off until coordinated acceptance.
- Alan merges this PR. No automatic merge, archive, Apple upload, production
  promotion or flag change is performed here. Build 14 is consumed; the next
  prepared source version is build 15.
- With approved activation, test new four- and six-answer interviews on web and
  build15, a skip before each checkpoint, reopening at 2/4, and recovery from a
  slow/unavailable read. Confirm an old installed build still gets per-pick.
- Existing production interviews/readings are not rewritten, and the separate
  `MUSICDNA_ARCHETYPE_V2` switch is unchanged.
