# MusicDNA 0.1.1 (7)

## One production backend

The native candidate uses `https://www.musicdna.fm` for both API and sharing,
with `MUSICDNA_EXPERIENCE_V1=true` in public client build configuration. Supabase
remains `udycgnhvaanemhrchbuj`; use its existing public client key, never a service
or model key. `config/prod.example.json` is the shipping template.

Alan approved production V1 activation on November 10, 2026. Merged backend PR42
is commit `36415e91cd6c6694ac5d7ce6074b66f83a3ce78a`; production deployment is
`dpl_GULDoxRJbiBo6EMxz5V1pPwWPSsS`. The installed build6's compatibility address
`musicdna-beta-alan-edgetts-projects.vercel.app` now aliases that SAME production
deployment, rather than a separately configured backend snapshot. Both public
version endpoints report the same commit; ordinary V1 requests with Flutter's
experience header reach normal 401 authentication, rather than the old 503 gate.
No protection, credential, learning-scope, reviewer or pilot changes were made.
Keep the compatibility address until older binaries are retired; it is pinned,
so check/repoint it when production advances until direct-origin builds replace
those binaries. Do not silently turn it into a second release environment again.

The separate custom-environment build `dpl_DRCqxsC1QVnQSd1rH5BNbsFZs8KA` completed
before Alan requested production consolidation. No shipped app alias points to it.
It is a retained deployment, not another required backend or release dependency.

## Native behavior

- The server supplies halftime guidance after three answers and the optional
  initial-reading milestone after four; continuing doesn't submit a song vote.
- Early reveal sends `finish_early:true`. An uncertain reply retains that intent
  for retry, so it cannot accidentally become a different completion operation.
- The final narrative, twist and challenge are shown together. Frozen evidence
  remains under The receipts; older saved results keep their supported layout.
- The collapsed React to the Critic control from merged PR19 remains below songs.
- Compact reads mirror web's omission of numeric audit parentheticals; complete
  saved wording remains available in interview history. No new prose is composed
  on the phone.
- Best-effort preparation calls the shared authenticated server implementation
  once per visible offered exposure. It does not run while a milestone hides the
  pairing, block choices, retry unknown generations or submit an accuracy rating.
- Critic choice, reveal, preparation and chat requests allow the same bounded
  45-second wait as web. Other API operations retain their existing timeouts.

Writer/reviewer code defaults are `gpt-6.1-sol` / `gpt-6.1-terra`. Production has
the approved OpenAI key and no role model overrides. A fresh build7 owner-QA run also confirmed these actual returned models.
This establishes shared-model operation, not improved reading quality. Previously saved/replayed readings are immutable and will not acquire a
new voice just because the backend is updated.

## Build and acceptance

Version `0.1.1+7`, bundle `fm.musicdna.app`, EK Enterprises team `SK2W4373LK`, iOS15.
Build7 is uploaded and consumed; future uploads need build8 or higher. Analysis, existing and new
regressions, and unsigned normal-entry production-origin compilation are checked
before PR review. Offline widget renders are implementation previews, not device
screenshots, live model success or TestFlight acceptance.

Alan merged native PR20; its mobile tree matches the signed archive source.
Archive, export, Apple validation, upload, processing and installation are now
verified below. Alan owns TestFlight acceptance and final release promotion.

TestFlight review: opening songs, choices/skip, halftime, continue, four-answer
Read me now, six-answer completion, reactions/retry, full reveal, history/resume,
conversation, sharing/revoke, login and optional exact-version accuracy feedback.
Use a fresh owner-QA run to inspect actual writer/reviewer metadata; no automatic
rating, preference inference or product-improvement claim.

The [App Store draft](app-store/0.1.1-en-US.json) and
[screenshot capture plan](app-store/screenshots-0.1.1.md) prepare the public listing.
Capture final screenshots after build7's TestFlight review, then submit only with
Alan's release approval.

## Actual build7 delivery receipt

Native PR20 merged as `3fd6753159d8523cbfa4f467c17075a2e5724ce9`; its mobile tree
matches archived candidate `e556a47938c234b79c79a998bc0d5722a1d752c5` exactly.
Archive and distribution export succeeded with existing EK Enterprises signing.
Apple validation reported `Validated Runner / EXPORT SUCCEEDED`. Alan approved
the TestFlight upload, which succeeded November10 at **8:51PM Pacific**
(`2026-11-11T04:51:38.873Z`); the upload then reported package processing.

The uploaded build is App Store eligible (`testFlightInternalTestingOnly=false`),
so an accepted TestFlight build can be selected for later App Review. No App Store
review submission or public release was performed. Apple's TestFlight email confirmed availability at `2026-11-11T04:57:02Z`. Build7
installation is verified by TestFlight Update/Open and wired-device metadata
(version0.1.1, bundleVersion7). Alan's visual acceptance remains pending.

The signed local IPA export is24,447,251 bytes, SHA256
`8105d52193ef09064192221f897fb71a74605491974c7291ca7fbf23e3ee00c3`.
This is the local export hash, not an independently retrieved Apple package hash.
See [the sanitized receipt](build7-release-receipt.json).

A fresh native owner-QA read through production on the already-installed build6
returned a successful `critic-expression-v2.4-moves2` response. Stored call
metadata confirms writer`gpt-6.1-sol` (3614ms) and reviewer`gpt-6.1-terra` (2998ms).
This establishes actual shared-model operation through mobile REST; it is not
build7 UI acceptance or evidence of improved accuracy. The reading is agent-assisted
QA authorized by Alan, not an independent listener preference measurement.


## Actual build7 phone walkthrough — November10 Pacific / November11 UTC

Authorized agent-assisted owner QA used a fresh session
`c5e57d0d-944d-48e3-b80e-0d3c6deef8c0` through production. It is not an
independent listener measurement or Alan's personal taste/accuracy assessment.

Verified on the installed TestFlight binary:
- Three opening songs and six answered choices saved successfully.
- The halfway message after three answers and four-answer initial-reading offer
  displayed; Continue and Give me two more resumed without submitting a vote.
  Actual four-answer early completion was not exercised in this walkthrough.
- React to the Critic is a muted single-line collapsed disclosure below songs.
  Expanding exposes That's me / Not quite / Prove it; it was collapsed without
  submitting a reaction. The previous large headline/subtitle is absent.
- Saved call metadata confirms successful `critic-expression-v2.4-moves2` reads
  using `gpt-6.1-sol` writer and `gpt-6.1-terra` reviewer.
- Six-choice final reveal initially exceeded the client's45-second timeout.
  The server nevertheless completed the session and saved one result. One
  explicit Try reveal again recovered version1 and displayed the full narrative
  and challenge. This is recovery evidence, NOT a clean first-attempt pass.
- Partly accurate (stored `mixed`) feedback saved for result version1, with a
  mutation ID and an explicit agent-assisted QA comment. Its outbox observation
  was captured; downstream delivery/review was not verified in this walkthrough.
- Sharing, conversation, active skips, revoke and post-restart resume were not
  exercised in this run. Do not claim full release acceptance from these checks.

Open findings before public distribution:
1. Final reveal timeout/recovery: avoid displaying raw `TimeoutException` and
   recover an already-saved result without forcing the listener to retry.
   Inspect reveal generation/wait/reconciliation before merely raising timeouts.
2. Home lacks an obvious saved-reading/resume entry point after restart, despite
   underlying resume storage. Build6's one-answer QA run was left unfinished;
   build7 testing started a new session rather than claiming resume worked.
3. Owner-reported web skip label confirmed in source: `Round {round} /6` uses
   shown rounds while progress dots use answered entries. Display answered-choice
   progress consistently; one or repeated skips must never produce7/6. Keep
   server selection/completion semantics unchanged and verify mobile labels too.
4. General catalog coverage, onboarding language and Alan's visual acceptance
   remain within AB-56. No claim that those broader issues are resolved.

Local phone QA evidence (not App Store resolution assets):
`/tmp/musicdna-build7-quiet-reactions.png`,
`/tmp/musicdna-build7-reveal-timeout.png`, and
`/tmp/musicdna-build7-feedback-saved.png`.
No App Store review submission, catalog mutation, learning configuration change
or new credential was performed during this walkthrough.
