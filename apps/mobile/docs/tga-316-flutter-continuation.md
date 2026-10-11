# TGA-316: Native continuation foundation

Current integration supersedes this foundation checkpoint: see
[first-session checklist](first-session-integration-status.md). Continuation,
versioned results, and feedback are now consolidated into PR #11.

## Scope and rollout

Flutter only. `MUSICDNA_EXPERIENCE_V1` remains false by default. No release
version, backend, migration, deployment or Agent Brain routing changes.
Push back pushes a native route above the saved result instead of regenerating
or replacing it. The original reveal and its existing evidence travel together.
Result version is nullable: the current Flutter reveal transport does not expose
one, so the production screen does not fabricate a version number.

The screen supports stored user/assistant messages, a 2000-character composer,
short turns, loading and authentication states, and explicit reload. History is
authoritative: no speculative reply or synthetic evidence is added to it.
Repositories must preserve server order, including repeated text/equal timestamps.
No chat content is logged or persisted to disk by this implementation.

## REST transport update

Reviewed Lovable main `62fdbe0`. The stable route now exists:
`GET/POST /api/v1/session/:id/chat`. Opted-in Flutter uses
`RestContinuationRepository`; the default-off experience still has no chat
requests. Both requests send `X-MusicDNA-Experience: 1` and use the existing
access-token provider. No generated web server-function URLs are used.

POST sends a random 128-bit `mutation_id` retained for the pending text. Definite
rejection/auth retry reuses it; successful completion clears it. A successful
reply is followed by GET, so the UI renders stored history rather than appending
synthetic user/assistant rows. Empty replies, invalid acknowledgments and failed
history refreshes leave the draft and quarantine sending.

GET restores transcript order and immutable result-version metadata. The screen
labels pairing versus conversation self-report and its base version. This DTO
does not include revision content, original/new claim text, triggering evidence,
stable message IDs or pagination; do not infer any of those from reply text.

Read-only production check: the chat GET route returns HTTP 401 with the typed
UNAUTHORIZED envelope without a bearer token. This confirms reachability, not
authenticated persistence, ownership, index deployment or safe replay.

## Remaining backend correctness gaps

In `src/lib/musicdna.functions.ts` at the reviewed SHA:

- Replay finds the first assistant row after the user's timestamp, not a reply
  bound to that mutation. Another concurrent turn's reply can be returned.
- An unfinished turn returns an empty reply with `replayed: true`. A user-row
  commit alone is not a completed reply acknowledgment or recovery protocol.
- User and assistant inserts do not check their returned errors. Concurrent
  attempts can both generate replies/self-report versions even when the unique
  index rejects one user insert, or acknowledge a reply that was not stored.
- GET orders ascending then limits to 200, returning the earliest messages, not
  the latest window once a conversation exceeds that limit.

Lovable owns these fixes. Needed: exact mutation-to-reply association, explicit
pending/failed/completed status, checked writes and safe concurrent recovery,
plus revision content and transcript pagination. Flutter does not automatically
retry an ambiguous write merely because the new endpoint accepts mutation IDs.

## Failure and draft semantics

Only one send can be in flight. The submitted draft cannot change until it settles.
Success replaces history with server history and clears the acknowledged draft.
Definite rejection/auth failure keeps the draft. Unknown write failures or a
cross-session write response quarantine sending; history reload alone cannot
prove a turn was rejected and therefore cannot enable another send.

Drafts and continuation state survive back/reopen for the same original reveal
object in this app process. They are held in memory, scoped to the authenticated
owner, and discarded when a different owner opens continuation. They do not
survive app termination, restored deep links, or re-fetched reveal objects.
Authentication redirects do not make another owner's cached conversation visible.
A direct route without the saved result context shows an unavailable state.

## Verification and outstanding acceptance

Unit tests cover ordering, short/invalid submissions, duplicate taps, rejection,
auth expiry, uncertain delivery, cross-session responses and snapshot preservation.
Widget coverage checks 375x667 layout at 2x text scale with keyboard insets,
back navigation and in-process draft restoration.

Local validation: `flutter analyze --no-pub` clean, `flutter test --no-pub`
76 tests passed, `flutter build ios --simulator --debug --no-pub` succeeded.
Coverage includes HTTP mocks for GET/POST, contract/auth/identity validation,
completed/empty replay and a failed GET after successful POST. These are client
tests, not authenticated live chat verification.

TGA-316 remains implementation-in-progress, not accepted. The REST adapter and
version metadata presentation are implemented. Outstanding: integration with
TGA-276's original result-version model (PR #12), full revision/provenance
restoration, server request-ID reconciliation, approved F21/F16/F22 integration
fixtures, authenticated persistence/concurrency tests, physical iPhone
keyboard/scroll/VoiceOver testing, and signed-build acceptance. Apple 0.1.1 build 3
does not include this work. Automated widget layout checks are not device QA.
