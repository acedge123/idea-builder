# AB-80 — Guest reading save and recovery (0.1.2 build16)

Reviewed 13 November 2026 against web main `f2642c4` and
`docs/musicdna/flutter-guest-save-contract.md`. This is a source implementation;
hosted email confirmation and physical-device acceptance are still pending.

## Behavior

A completed, versioned guest report offers a dismissible **Keep this reading**
sheet once per reading on this installation and a persistent save button. Tab
navigation and Back offer **Keep this reading** / **Leave for now**. Dismissal
never signs out, deletes, publishes, regenerates or rewrites the reading.
Home has **Continue your reading** and **Keep this reading**. Guests can reopen
all their readings through the normal owner-scoped My readings API. A guest
upgrading from build15 can recover a completed reading from those same read APIs.

The implementation extends the existing widgets → Cubit → repository →
Supabase/REST architecture. Local state stores only the source UID, session ID,
exact result version, prompt dismissal and pending email-request marker. State
is owner-scoped; it contains no email, password, tokens, choices or report prose.
It survives navigation, app restart and starting another interview. It cannot
recover access if Auth storage is cleared or another identity replaces the guest.

Saving follows these steps:

1. Validate the source using Auth `getUser`, then owner-read the completed session
   and its exact saved report version.
2. Persist pending source metadata and call `updateUser(email: ...)`, with no
   password and no `signUp` call.
3. Wait for confirmation; the listener explicitly checks it. A fresh server
   `getUser` must return the same UID, non-anonymous and a confirmed email.
4. Only then accept/set the password with a separate `updateUser` call. Never
   store it in recovery state.
5. Revalidate the confirmed identity and owner-read the same completed session
   and exact report version. Only then show **Saved to your account** and clear
   the pending marker. Return to `/session/:id?version=N`.

Duplicate email, a different owner, missing original local state, unfinished
reading, missing version or unavailable readback cannot produce a Saved claim.
Failures retain the source and allow retry without a new identity or result.
Account navigation uses the pending-save flow instead of silently replacing the
source through ordinary existing-account sign-in. The separate “Sign in without
saving” action warns that it replaces guest access, requires confirmation and
opens a sign-in-only form; it never claims a transfer. Other ordinary account flows
retain the existing Auth implementation; this does not redesign general signup.

## Hosted prerequisite (not changed by this PR)

The registered native callback is:

```
fm.musicdna.app://auth/save-reading
```

Before live confirmation acceptance, add that **exact URL** to Music DNA's
Supabase Auth redirect allowlist (project `udycgnhvaanemhrchbuj`). No keys or
service-role access belong in Flutter. iOS registers `fm.musicdna.app`; Android
registers the exact host/path. Flutter's default router deep linking is disabled
so Supabase Flutter's existing Auth link listener handles confirmation. The link
contains no source UID or session ID; it is never used as ownership evidence.
On a cold start, Home/Account recover the original device-local pending source.
Confirming on a different installation without that source must fail closed.

No hosted Auth configuration, migration, endpoint, flag, key, publication,
learning setting, signing or TestFlight upload was changed by this implementation.

## Existing-account transfer is unavailable

There is no shared atomic guest → existing-account transfer API. The UI explains
this and does not offer ordinary login as a save operation. A later separately
approved endpoint must verify both identities, consent, replay keys, the full
session family and dependent private rows, lifecycle locks and destination
owner/version readback. Signing in by email is not a transfer.

## Verification / TestFlight acceptance

Automated checks use SDK/HTTP stand-ins, not live Auth or customer records. They
cover email-only versus password requests, stable UID/confirmation gates,
owner/version readback, unavailable/incomplete/mismatched reports, duplicate
emails, source loss, retry, owner isolation, persistent recovery, dismissal,
Home reopening, the completed-reading leave guard and small-screen large text.
Normal saved-reading APIs remain read-only; no reveal/model call is made.

Still verify with a disposable guest on build16 after Alan merges and authorizes
an upload:

- Complete a report, dismiss, change tabs, restart and reopen the same version.
- Start another interview; the prior report remains in My readings.
- Request a new email. Nothing claims Saved; leave/reopen pending confirmation.
- Receive/open the confirmation on the original phone (warm and cold launch),
  check confirmation, set password, and see the identical reading again.
- Sign in on a second device with that new account and reopen the same report.
- Duplicate existing email and missing source do not claim success or transfer.
- Keep existing-account transfer unavailable until the shared contract is approved.

Web follow-up: its current save form verifies session ID/completion through
`resumeLatestSession`; the handoff additionally requires exact report/version
readback. Flutter performs that check; web should confirm the same acceptance
before calling the cross-client flow fully verified.
