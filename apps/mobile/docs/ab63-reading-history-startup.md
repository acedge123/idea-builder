# AB-63: saved-reading startup recovery

Alan's TestFlight 0.1.1(8) screenshot shows the intended signed-in Home with a
failed history load. The generic error alone does not establish the failed HTTP
status or its cause. On the unchanged TestFlight build8, returning from Account to Home at09:45 Pacific November11 reloaded recent readings successfully; My readings also loaded originals and the1980s child. No original failing HTTP status was captured, so the specific failure remains unattributed.

## Confirmed code defect

Supabase Flutter v2 restores the stored session before its asynchronous refresh
finishes. Our API token callback returned that session's access token immediately,
including an expired one. Home starts its history request as soon as a stored
user exists. A later token-refreshed event preserves the same library Cubit, so
an initial failed load could remain on screen until a manual retry.

This matches [Supabase's documented startup behavior](https://supabase.com/docs/reference/dart/upgrade-guide#initialization-does-not-await-for-session-refresh)
and the installed supabase_flutter 2.15.3 / gotrue 2.24.0 source. No SDK upgrade
or database change is required. This is a confirmed startup race; attributing the
specific screenshot to it still requires the actual device/request evidence.

## Fix

- The auth data layer supplies the existing REST client's access token. It waits
  for a fresh token when the restored session is expired, with a 20-second bound.
  The SDK shares refresh work with concurrent requests/startup recovery.
- After refresh, read the SDK's current session and verify the owner is unchanged.
  Sign-out or account switch stops the pending operation. No protected API write
  is retried or replayed; backend authentication and ownership checks are unchanged.
- Auth-stream errors are sanitized and handled without becoming uncaught observer
  errors or falsely representing a temporary network problem as sign-out.
- Library reloads retain already-loaded rows during a connection failure. A 401
  directs the user to Account to sign in again; connection errors retain Retry.
  Successful refresh replaces rows from the first page, avoiding stale entries.
- Diagnostics emit only fixed event names, error kind/type and HTTP status. They
  do not log tokens, exception messages, reading content or customer identifiers.

## Verification and remaining acceptance

Nine regressions exercise the real installed auth SDK with an in-memory HTTP
transport: shared expired-token refresh before API calls; valid-token denial
without replay; invalid refresh preventing writes; sign-out and account switching
during refresh; bounded timeout and later recovery; SDK stream-error handling;
retaining library rows across network failure; and actionable 401 errors without
logging exception contents. Existing owner-isolation tests remain in the suite.

Production public version was 478a9602f069a18aec9d6fffc5a0329e5cc94360,
Persistence V2 enabled, and signed-out GET /api/v1/sessions returned 401. Those
checks establish serving revision and anonymous denial, not authenticated health.

The next native candidate is 0.1.1(9); build 8 is already consumed. Current main
also includes PR25's exempt-encryption declaration. No upload or production
promotion is authorized by this code change. Alan merges and approves that step.

Before closing the failure: reproduce/retry build8 if possible; verify a cold
launch with an expired stored login on the candidate, Home/My readings readback,
relaunch, sign-out/account switch, and offline/reconnect. Record native and backend
revisions and sanitized failure categories. AB-63's other acceptance checks and
Alan's TestFlight visual acceptance remain open.

Validation: Flutter analysis clean;172 tests passed,1 optional live-contract capture skipped. Production-configured iOS compile and development-signing build succeeded. The compiled plist reports0.1.1(9), minimum iOS15 and ITSAppUsesNonExemptEncryption=false. No dependencies/lockfiles changed. The local development-signed release-mode build9 was installed successfully on the connected iPhone14. The retained login loaded Home and opened the saved1980s reading at version1 with its unchanged text. Further cold-expiry/offline acceptance remains pending; no build9 TestFlight upload.

## November 11 follow-up: completed-reading controls

Alan subsequently approved the internal build9 upload; Apple accepted it at
17:58:21 UTC. Upload acceptance is not confirmation of processing or tester access.
The signed archive remains unchanged by this follow-up.

A separate screenshot walkthrough with a dedicated normal reviewer account found
a debug Flutter assertion when opening a completed original reading. The feedback
and Decades `BlocProvider` siblings both used `(sessionId, resultVersion)` as their
key. With both factories enabled, the parent Column rejected the duplicate keys.
This is a confirmed widget identity defect; a debug assertion is not evidence of
a production crash. The earlier standalone panel tests did not mount both panels
on the signed-in result page together.

Each key now additionally includes its panel purpose, retaining session/version
identity while keeping the siblings distinct. A full-page signed-in widget
regression reproduced the assertion on merged source and passes after the fix;
it also scrolls to both controls. Analysis is clean and the full suite passes
173 tests, with one optional live-contract capture skipped. No dependency,
backend, data, auth policy, learning consent or build-number changes are included.
This fix needs its own merge and a later native build; it is not in uploaded build9.
