# TGA-313: Native Result Feedback Foundation

Current integration supersedes this foundation checkpoint: see
[first-session checklist](first-session-integration-status.md). The actual REST
adapter now exists for experience-v1 testing; production flag defaults stay off.

Baseline: Flutter main `0aa6e16` (merged PR #12). Backend reviewed:
`acedge123/music-dna@877d7b0`.

## Implemented

- Native accurate / partly accurate / missed controls and optional useful
  sentence, inaccurate sentence, and comment. Limits match the existing web
  input limits (1000 for sentences, 2000 for comments).
- Separate feedback repository and Cubit bound to owner, session, and exact
  result version. No scored-choice, reaction, vector, routing, or public-link
  mutation. No feedback content or credentials in logs.
- Authoritative saved-feedback restoration, serialized submissions, preserved
  drafts, authentication handling, and conservative uncertain-write recovery.
  A lost or invalid acknowledgment never triggers an automatic second write;
  only a read proving the exact mutation and content clears uncertainty.
- Auth-state changes immediately clear feedback and drafts; late responses from
  the prior owner are ignored. The invalidated editor cannot be reused by another
  account.
- Result-page integration is capability gated. Production DI uses an unavailable
  repository: controls stay hidden even with experience v1 enabled. Existing
  clients, feature-flag defaults, and Apple 0.1.1 (3) remain unchanged.

## Lovable-Owned Contract Needed

The reviewed backend has `submitFeedback` and `getMyFeedback` web server
functions, but no feedback REST route in `src/routes/api/v1`, and no feedback
section in `docs/musicdna/experience-contract-v1.md`. The submit validator does
not accept a result version or mutation ID. Its lookup-then-insert behavior is
not proof of atomic retry safety. On first insert it also nudges critic profile
state immediately; review that behavior against the approved gradual/batched
learning policy and the ticket's prohibition on automatic vector/policy updates.

Before enabling Flutter, Lovable needs to document and implement:

1. Authenticated read and write transports shared with web, checking server-side
   session ownership and existence of the requested result version.
2. Accuracy vocabulary, optional fields, clear/update semantics, limits, and typed
   errors. Explicitly map `partly`/`mixed` and `missed`/`not_accurate`; do not infer
   a new public wire vocabulary from these Dart enum names.
3. Atomic one-feedback-per-owner/session/version storage and durable mutation-key
   replay; conflicting key reuse must reject without another side effect.
4. Reads and acknowledgments returning the exact result identity, saved content,
   and mutation identity so an uncertain write can be reconciled safely. Define
   recovery for pending/failed mutations; absence alone is not proof of rejection.
5. Separation from pairing evidence, interview reactions, and immediate policy
   updates. No publication or consent change through feedback.

No speculative HTTP route, direct database access, or TanStack internal server
function call is shipped here. Add the REST adapter only after that contract is
accepted and deployed; then replace the unavailable DI implementation.

## Local Verification

- `flutter test --no-pub --reporter expanded`: 87 tests pass, including 16 new
  feedback tests. Covers restore, limits, parallel taps, auth failure, owner and
  version mismatch, account changes, late completions, uncertain-write
  reconciliation, and 375x667 layout at 2x text scaling.
- `flutter analyze --no-pub`: no issues.
- `flutter build ios --simulator --debug --no-codesign --no-pub`: succeeds.
- `git diff --check`: clean.

These are local unit/widget/compiler checks, not real-device or deployed REST
acceptance. No database, Lovable backend, feature-flag, release-version, or routing
changes were made.

## Acceptance Still Pending

- Actual REST transport, persistence, concurrency, and authenticated deployment
  tests (including logout during a pending request and owner/version isolation).
- Web-equivalent fixture responses and actual iPhone keyboard/scroll/large-text QA.
- Product approval of any feedback-driven critic adjustments.

The native foundation is not end-to-end ticket acceptance. Drafts survive state
rebuilds and failed requests within the mounted reading, not process death or
navigation away. Reopening relies on the authoritative read once implemented.
