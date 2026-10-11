# TGA-315 Flutter Experience Foundation

Flutter-only implementation, stacked on TGA-301/302 client fixtures (PR #9).
Web/backend ownership remains Lovable. No backend, migration, routing, production
configuration or Apple build/version changes are included.

## Contract And Rollout

`MUSICDNA_EXPERIENCE_V1=true` explicitly opts session requests into
`X-MusicDNA-Experience: 1`. The flag defaults to false. Legacy requests keep their
existing shapes. Reference: Lovable web source `0025cf2`, not the unmerged backend
PRs #3/#4 and not proof of deployed behavior.

Flutter displays server thesis, question, counts when supplied, named revision,
feedback and reaction message. It does not calculate eligibility, confidence,
contrasts, routing knobs or steering. An unsupported contract or wrong session
returns a recoverable error instead of silently losing history.

Chronological history is fetched from the owned session route. Equal timestamps
retain server order. Historical rows marked unavailable are labeled rather than
treated as new evidence. The initial opener still uses the released local session
cache; authoritative opener restoration and account-scoped recovery remain with
TGA-277/278 and Lovable's accepted resume contract.

Selected song state belongs to the Cubit and survives transport failure. Repeated
submissions while busy/failing are blocked. Reaction retries keep the same random
mutation key and original pairing within this Cubit; pending reactions block new
votes. Successful reaction effects are rendered verbatim. Reactions never become
pairwise choices in Dart. Durable restart-safe mutation reconciliation remains
TGA-278/305; this change does not claim crash-safe exactly-once delivery.

V1 completion follows the server's completion flag, not a seventh displayed round.
The legacy release behavior is preserved when the flag is off.

## Verification And Remaining Work

Run `flutter analyze --no-pub` and `flutter test --no-pub`. Tests cover version
opt-in, legacy response compatibility, wrong-session/unsupported-schema errors,
ordered history, revisions, selection retention, reaction retry identity and a
320-logical-pixel layout with 200% text. Existing shared fixtures remain included;
cached fixture tests are not deployment acceptance.
The widget golden uses Flutter's test font (block glyphs) to catch layout drift;
it is not a real-font iPhone screenshot or an ACE visual acceptance capture.

Before TGA-315 is accepted: Lovable must settle/deploy the endpoint contract and
ACE must approve the phone reference (TGA-314). Capture equal-viewport web/iPhone
states and verify authenticated restoration, persisted reaction effects, active
exchange scrolling, opener history, full-screen long labels, reduced motion and
VoiceOver on representative iPhones. Do not enable this flag in release config
until those gates pass. TGA-316 continuation remains a separate next ticket.
