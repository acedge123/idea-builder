# MusicDNA0.1.1(8) release candidate

Release parent: AB-58. Native implementation: AB-59, AB-60, AB-62. Backend correctness and live acceptance: AB-61. Device/release acceptance: AB-63.

## Behavior

- Direct production origin remains https://www.musicdna.fm; no beta hostname dependency.
- Home, My readings and Account navigation is available throughout the main flow. Signed-in Home has Start/Continue and recent readings. Reading history identifies original and decade sessions, groups loaded children under their original and supports older pages via the existing owner-scoped API.
- Explicit /session/:id opens private saved reads and restores server history. Opening a saved reading reads its frozen original pairing result through owner-scoped GET chat history before considering generation. It never implies public sharing.
- Resume storage is keyed by authenticated owner and never adopts the old unowned local key. Library responses from a previous owner are suppressed; continuation caches close on owner changes.
- Final reveal uses the shared web backend. A null result_version becomes a pending state, never an invented saved version. Network uncertainty triggers one saved-result readback before offering an explicit retry. Early-finish intent survives that retry. The async network boundary now awaits requests so typed timeout handling works.
- After a durable read, optional Explore your DNA loads server-ready decades and previous runs. A child starts without repeating opening-song onboarding. Operation IDs persist across uncertain starts and use the accepted operation_id REST field. Child views restore server mode/decade/parent metadata; comparisons render server eligibility/directions without local scoring. Explore skips speculative client preparation.
- Existing feedback, conversation and explicit publication/revoke keep their owner/version boundaries. No model key, service-role key, engine scoring or new database is placed in Flutter.

## Backend prerequisites

Music DNA PR44 adds summary mode/decade/parent metadata and stable started_at/id paging. It merged as478a9602f069a18aec9d6fffc5a0329e5cc94360; public production version independently reports that SHA.

Lovable source19a198e includes the Decades replay start operation_id, shared playable coverage, parent-delete CASCADE correction and preparation mode guard. Read-only metadata confirms sessions.explore_start_key, its replay index and the cascading parent FK exist. This does not establish listener-behavior acceptance or successful destructive testing. No production data was deleted.

## Validation / acceptance status

- Flutter analysis clean; final rerun recorded in the PR validation.
- Full baseline plus recovery regressions159 passed; one optional deployed-contract capture skipped.
- Four additional widget/contract checks pass (including above-fold sign-in and persistent signed-out home actions): large-text private child navigation, saved Decades visibility when no era is ready, and stable operation_id payloads. Final aggregate validation is recorded in the PR.
- Native simulator and unsigned production iOS release builds succeed. A local development-signed phone build also succeeds with existing Xcode signing. Actual signed-in device/simulator walkthrough, fresh reveal latency and screenshots are pending owner login.
- No TestFlight upload or App Store submission has occurred for build8. Build7 is consumed; confirm8 remains unused before upload. Alan merges native PR and authorizes a concrete signed candidate for upload.

## Store package

Draft copy, six-screen storyboard and exact target sizes are in docs/app-store/0.1.1-build8/. Actual accepted native captures remain pending. Required target sets: iPhone1206×2622; iPad2064×2752 because the current binary supports device families1,2. Existing app icon is1024×1024.

Never substitute rendered test fixtures or scaled Mac/Mirroring screenshots for full-resolution native App Store images. Final listing/review access/privacy/support checks and public-distribution approval remain separate from internal TestFlight delivery.

Owner UI correction: signed-out Home now keeps Sign in and Start reading visible in a fixed gradient-backed action overlay. The auth logo/header is compact, with password-field above-fold regression at390×844. Signed-in Account hides sign-in/sign-up form controls.
