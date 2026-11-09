# AB-56 build6 — shared voice and artwork

These PNGs are **offline presentation fixtures**, rendered from actual Flutter
widgets. They are not live readings, device screenshots, model-quality evidence
or TestFlight acceptance. Fixture repositories reject writes. Public font assets
were loaded for rendering; no application API calls or accuracy ratings were made.

- [Active matchup](pairing.png): choice cards remain primary, optional reactions
  stay collapsed below them; missing covers use the shared branded fallback.
- [Server reaction](reaction.png): the provided message is displayed verbatim.
- [Reading](reveal.png): one primary conversation action and secondary sharing,
  with full evidence available through disclosure.
- [Conversation](conversation.png): original reading remains secondary and saved
  messages remain verbatim. This fixture intentionally shows unavailable reply
  handling; it is not an example of a successful live model response.

## Implementation

- Optional `song_a.artwork`/`song_b.artwork` map into typed domain metadata.
  Null, malformed, non-HTTPS or credential-bearing URLs are ignored. Loading and
  image errors fall back without blocking song selection. Attribution is retained
  and accessible through the cover tooltip. No client-side release/rights lookup.
- Reaction acknowledgments use the shared response `message`; no fixed local
  reinterpretation of the effect. Existing retry mutation IDs remain unchanged.
- Running and final read prose is rendered verbatim, including qualifications and
  numeric parentheticals supplied by the server. Optional voice/audit/status fields
  survive mapping; process/version/status labels are not shown in the main flow.
  Separate audit text is available in interview history/full reading.
- No scoring, completion, routing, consent, learning or feedback-storage changes.

## Deployment map

Web source reviewed: music-dna85b3536 plus backend PR30's source-stamp and saved
resume metadata corrections, source40292b1c78a1df19811194eff1036770d00d1891.
The existing beta hostname now serves that candidate from custom environment
`musicdna-beta`; old19c1e73 deployment remains available for rollback. Normal
application auth remains required; no bypass secret is embedded in Flutter.

The new native candidate is **0.1.1(6)**, bundle`fm.musicdna.app`, minimum iOS15.
Its API/share origin remains
`https://musicdna-beta-alan-edgetts-projects.vercel.app`. Production V1 and all
learning/model-review gates remain unchanged. No schema or catalog writes occurred.

## Verification and acceptance

- Flutter analysis clean;136 mobile tests passed; optional deployed-DTO capture
  check skipped because no owner-authenticated capture was available.
- Normal-entry unsigned iOS release build succeeded. Archive/export/upload status
  must be recorded separately; compilation alone does not establish TestFlight
  availability or consume build6.
- Backend420 tests passed,99 environment-dependent checks skipped, TypeScript,
  changed-file lint, generated-source guard and Vercel-target build passed.
- Provider deployment/source/environment and beta version endpoint verified;
  unauthenticated chat returns ordinary`UNAUTHORIZED`. This is not positive
  authenticated contract acceptance.
- Read-only catalog aggregate:333 rows satisfy the backend's recorded artwork
  display criteria across333 songs. This is recorded approval metadata, not an
  independent copyright/release audit or proof every matchup has artwork.

Alan owns live TestFlight visual/functional acceptance. Review onboarding, two
art-covered/fallback choices, reactions, completed read, history/resume, conversation,
sharing and error recovery. Prior saved readings must remain unchanged. Existing
AB-52 invitations retain old source pins; no experimental assignment is inferred
from this QA release. AB-56 stays open until acceptance; catalog reachability,
editorial quality and occasional deterministic fallback remain separate product
limitations, not claimed solved by the native port.

## Actual release receipt

Build6 was archived, distribution-exported, validated by Apple and uploaded for
**internal TestFlight only** on November9 at **3:18PM Pacific**. Apple reported the
package processing; processing completion and installability are not yet verified.
The binary source is58f0d08d18705e97cb15f954eeed8e0231e8272a; later changes in this
PR record release documentation only. Build6 is consumed: future upload candidates
need7 or higher. See [the sanitized release receipt](release-receipt.json).

After installing0.1.1(6), Alan should verify actual artwork/fallbacks, exact shared
reaction wording, start/choose/skip/reveal, resume/history and full evidence, saved
conversation and sharing, plus error recovery. No public App Store release or
production V1 activation occurred. The code PRs remain open for normal review/merge.
