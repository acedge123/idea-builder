# TGA-316: Native continuation foundation

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

## Backend dependency: not yet live

Reviewed Lovable main `68bd6e77d464e74f8c0b643798e9b0ab9fd1928f`.
`src/lib/musicdna.functions.ts` provides authenticated `listChat` and `chatTurn`
TanStack server functions. The `src/routes/api/v1` tree has no stable chat REST
route. Flutter deliberately does not call generated web server-function URLs.
Production uses `UnavailableContinuationRepository`; send stays disabled and
the screen explicitly says conversation is unavailable. Tests inject a repository;
those tests are not evidence of deployed web/mobile chat parity.

Lovable must supply an accepted, authenticated mobile contract for:

- Loading an owned session's ordered recent messages, with stable message IDs,
  pagination and explicit session/result identity.
- Submitting a turn to that same session, with a persisted client request ID and
  replay/reconciliation semantics. The current server function saves the user
  message before generating the reply; timeouts can leave partially stored turns.
- Returning authoritative history and separately versioned revisions, including
  original claim, triggering evidence, evidence source and new interpretation.
- Access errors and server-verified ownership; no automatic replacement session.

The existing functions return role/content/created_at history and reply/sessionId,
not a replay-safe transaction or revision DTO. Do not invent endpoint paths or
interpret a chat reply as a result revision. Wire the real adapter only after that
contract is agreed and tested against the web fixtures.

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
68 tests passed, `flutter build ios --simulator --debug --no-pub` succeeded.
These checks run against the injected test repository, not a live chat service.

TGA-316 remains implementation-in-progress, not accepted. Outstanding: real REST
adapter, result-version restoration, revision/provenance rendering, request-ID
reconciliation, approved F21/F16/F22 integration fixtures, physical iPhone
keyboard/scroll/VoiceOver testing, and signed-build acceptance. Apple 0.1.1 build 3
does not include this work. Automated widget layout checks are not device QA.
