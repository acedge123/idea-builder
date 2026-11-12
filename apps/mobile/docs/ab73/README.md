# AB-73 — build 13 uninterrupted interview

MusicDNA 0.1.1+13 follows six server-owned choices without a halfway Continue
screen or four-answer reading prompt. Alan explicitly superseded those earlier
milestone requirements. The API can still report those optional milestones;
Flutter retains the DTO/history but never replaces the active songs with them.
Server skip/catalog completion remains authoritative.

A pick saves once through the existing repository and atomic backend path. On
acknowledgement, the next pairing paints before optional history/narration. V1
requests defer_read; old servers safely return inline narration as before. The
Critic response is fetched separately, bound to the committed pairing and the
server's answered count. New choices are allowed while it is pending. A newer
choice, skip, reload or final report invalidates older replies; closed Cubits do
not emit. Uncertain narration is not automatically retried and cannot undo a
vote. Scoring, writing models/policy, evidence and consent remain on the backend.

UI: no new prose is painted over the selected old pairing. A music-bar thinking
indicator and pairing placeholders paint during save/load. Next songs stay
above the asynchronous Critic response so text arrival cannot displace a tap;
a reserved response area/history control prevents scroll clamping on a short
reply. Existing compact reactions are optional below choices. The final reading
has an indeterminate writing state, honest saved-choices copy, reduced-motion
support and no invented progress percentage. The old 1.4-second onboarding pause
is removed. The submitted third-song state stays coherent during navigation.

AB67 free-text pushback is still separate work and must be inline after Q3;
this PR keeps existing compact reactions, not a new free-text feature. AB68
Refine/library is also separate. This PR does not complete all mobile parity.

Backend dependency: MusicDNA codex/musicdna-uninterrupted-flow. Apply only
20261112183759_musicdna_deferred_read_cursor.sql once via the approved workflow,
then deploy the reviewed backend. It adds one service-only atomic compare/save
function on the backend. No private credential goes into mobile. See that PR's
docs/musicdna/ab73-deployment-handoff.md. No migration or deployment was performed
while preparing either PR. Production API origin remains www.musicdna.fm.

Verification: 231 Flutter tests passed; one optional deployed-contract capture
skipped. Analyzer clean. iOS Simulator debug compilation with the existing
production config passed. New tests cover acknowledgement/next atomic paint,
late/out-of-order replies, choosing while narration is pending, independent
history/model failures, six uninterrupted votes / one final report, double tap,
close, permission guard and response identity, stable card positions, and large
text/reduced motion. These are isolated fixtures; no new live listener reading,
accuracy rating or model call was submitted in this implementation pass.

Release: build12 is consumed; build13 is prepared in source only. Alan must merge,
verify the one backend migration/deployment, and approve a new TestFlight upload.
Physical-device timing/visual acceptance and Apple's replacement recording are
still required. No Apple submission or production promotion is included.
