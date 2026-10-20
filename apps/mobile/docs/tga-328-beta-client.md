# TGA-328 beta client preparation

October 20, 2026. Mobile base `4b7597c6e808eb9eaf0582781715435dc668199d`; proposed backend base `31adee7753eb6a54a3ea8c2a5ed3baf2e65620d7` plus the session-access correction. Beta environment creation/access changes await explicit approval; TGA-328 remains in progress.

`config/beta.example.json` defines the proposed client origin, share origin, existing MusicDNA Supabase project and V1 opt-in. Copy it to ignored `config/beta.local.json` and supply the existing public anon/publishable client key. No OpenAI, service-role, harness or Vercel bypass key belongs in this file or binary. The prepared local configuration was checked to contain an anon/public key only. Proposed beta hostname is not live yet.

The beta uses the existing accounts/database. Backend release flags will be separate from www.musicdna.fm. Production V1 remains disabled. Do not upload an app pointing to a disabled or SSO-intercepted API.

## Compatibility correction

Current backend feedback persistence stores immutable operations, so multiple feedback saves can belong to one result version. The earlier Flutter reader treated multiple rows as invalid and ignored the now-present mutation ID. It now selects the newest timestamped operation within the exact version/target, retains its mutation ID, rejects ambiguous ties/duplicate IDs and validates mutation identity after an acknowledged save. Older versions are untouched; legacy single-row responses remain readable.

This supports existing TGA-313 scope and does not certify the live write/retry UI. No backend scoring, result inference or policy moves into Dart.

## Automated evidence

- `flutter analyze --no-pub`: clean.
- `MUSICDNA_CONTRACT_CAPTURE=<local probe file> flutter test --no-pub`: **125 passed**, including the captured-response compatibility test and four new feedback-operation regressions.
- `test/live_contract_snapshot_test.dart` decodes real private-production GET responses through the application's current session, history, continuation and feedback repositories. With no capture file it skips explicitly. Captures contain synthetic reading data and remain local; never commit credentials or captures.
- `flutter build ios --release --no-codesign --no-pub --dart-define-from-file=config/beta.local.json`: passed for the normal application entry. Artifact: `build/ios/iphoneos/Runner.app`. Build is unsigned, still version 0.1.1 (3), and must not be uploaded. TGA-330 will query Apple and choose an unused higher build before signing/upload.
- The captured owner DTOs decoded. Current production foreign-session snapshot/chat/feedback denial passed, but foreign `next` returned 200. A backend guard correction is prepared separately; it must be deployed and verified before beta readiness is accepted.

## Remaining order

1. TGA-328: approve/create the separate beta environment, deploy reviewed fixes, prove ordinary bearer access and the complete technical route matrix, then finalize this configuration's actual origin/SHA.
2. TGA-330: merge/review intended source, choose a unique build above consumed build 3, sign/archive/upload and verify installability.
3. ACE performs all hands-on QA and acceptance in TestFlight (TGA-329 functional/recovery; TGA-321 visual/device/accessibility). Codex fixes reported defects and supplies another build.

No Apple upload, production flag change, database migration or manual acceptance occurred during this preparation. The automatic approval review rejected copying production credentials and enabling beta V1 without explicit authorization; the environment creation command did not execute.
