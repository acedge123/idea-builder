# MusicDNA Mobile Release Baseline

TGA-300 | reviewed October 10, 2026 | reconciliation, not release acceptance

## Repository Ownership

- Active Flutter source: `acedge123/idea-builder`, `apps/mobile`.
- Web and shared backend: `acedge123/music-dna`; Lovable owns these changes.
- Routing reference: `The-Gig-Agency/agent-brain`.
- GitHub resolves `The-Gig-Agency/idea-builder` to `acedge123/idea-builder`
  with the same repository node ID. This is a rename/redirect, not a second fork.
- The mobile directory in music-dna is historical comparison material. Do not
  overwrite the active app with that copy or duplicate backend work here.
- Product authority: [PRD v1.1](../../../docs/musicdna/product-requirements.md)
  and [parity guide v1.1](../../../docs/musicdna/codex-parity-guide.md), added
  to idea-builder main in `6c2b9b6f94fc902a1587007495bb009e86ef0c35`.

## Preserved Source And Integration

Original release branch: `codex/tga-281-mobile-web-parity`,
`9d533b37b7cf66c2aa95e9fd9b1fcb7ec8261368`.

Its three commits, based on `f37ae2e`, remain intact on the original branch:

| Original commit | Scope | Replayed commit |
| --- | --- | --- |
| `95a10a9` | Visible startup configuration failures | `fb357b7` |
| `6a032e8` | Build number 3 | `31b8c2e` |
| `9d533b3` | Mobile release flow, branding, auth, opener and recovery | `18ffd10` |

Reconciliation branch: `codex/tga-300-mobile-reconciliation`, based on
idea-builder main `6c2b9b6`. The three commits were replayed in order without
conflicts. Before this documentation change, its entire tracked `apps/mobile`
tree was identical to the original release SHA (`git diff --exit-code`).
The existing user checkout and release branch were not switched or rewritten.
The reconciliation is reviewable; it has not been merged to main.

The release branch is three commits ahead and four behind that main snapshot.
Those four main-only commits add documentation, not mobile runtime changes.
Replaying the release work changes 57 tracked mobile files relative to main.

Music-dna web/backend snapshot: `1c380fe` (October 10). None of its intervening
changes modified `apps/mobile`. Its mobile copy differs from the release in:

- `lib/bootstrap.dart`
- `lib/bootstrap_error_app.dart` (release-only)
- `lib/main.dart`
- `lib/src/features/session/presentation/cubit/session_cubit.dart`
- `lib/src/features/session/presentation/pages/session_stub_page.dart`
- `pubspec.yaml`
- `test/session_cubit_test.dart`

Keep these release changes; the known client round cutoff belongs to TGA-278,
not an unreviewed correction in this baseline ticket. No new web/backend,
router, schema, or Flutter experience implementation is introduced here.

## Apple Evidence

- ACE confirmed Apple version **0.1.1 (3)**.
- Matching local archive: `Runner 7-20-26, 10.09 AM.xcarchive` (July 20).
- Archive created: `2026-07-20T17:09:12Z`.
- Apple validation succeeded: `2026-07-20T17:11:09Z`.
- Apple upload succeeded: `2026-07-20T17:20:14Z`.
- Bundle ID: `fm.musicdna.app`; team: `SK2W4373LK`; signing is unchanged.
- Archive metadata identifies version `0.1.1`, build `3`, and arm64.
- Exact archive source SHA is unknown. The final release-flow commit was made
  after the upload; do not assert that all of `9d533b3` shipped in build 3.
- Current TestFlight/App Store availability and device acceptance were not
  independently checked. Validation/upload do not prove product correctness.
- Build 3 is consumed. The next upload must use a higher build number; do not
  bump it merely to reconcile branches. Source remains `0.1.1+3` here.

## Configuration And Deployment Evidence

Existing user checkout has ignored `dev.local.json` and `prod.local.json`.
Required API/Supabase/client-key fields are populated. Production also has
`SHARE_BASE_URL`; development uses the existing API-origin fallback.
Neither local config nor credentials were copied into the reconciliation repo.
Configured API and public share origin: `https://www.musicdna.fm`.
Both local configs point at the same production origin, so neither is an
isolated staging environment. Do not create production test users/sessions.

Read-only, unauthenticated observations at that origin on October 10:

| Probe | Legacy and experience-v1 header results | What it proves |
| --- | --- | --- |
| `GET /api/v1/session/<zero UUID>/next` | JSON 401, `UNAUTHORIZED`, missing bearer token | API route/auth boundary exists |
| `GET /api/v1/session` | HTML 200 | Not a usable JSON session-list probe |
| `GET /api/v1/share/tga300-invalid-token` | HTML 500 | Public error behavior needs backend investigation |

These probes do **not** establish authenticated response shapes, deployed SHA,
migration readiness, replay semantics, persisted result versions, or routing
environment. Source defaults to shadow; deployed routing mode is unverified.
No Railway/Agent Brain call, deployment, environment change, or data mutation
was performed. The v1 source contract is in music-dna at
`docs/musicdna/experience-contract-v1.md`; do not infer it is deployed from a
header or from an auth rejection.

## Verification And Remaining Gates

- Replayed mobile tree matches `9d533b3`: passed before documentation edits.
- `flutter pub get`: passed; tracked dependency lockfile unchanged.
- `flutter analyze --no-pub`: passed, no issues.
- `flutter test --no-pub`: passed, all 19 tests.
- `git diff --check`: passed.
- iOS build/archive/upload: not run; this is source reconciliation only.
- Authenticated legacy/v1 contract checks: pending an authorized staging
  origin and test identity/session. Missing access is an explicit gate.
- Device acceptance, sharing, automatic result, authoritative completion and
  web-approved visual parity remain with their existing tickets.

TGA-300 must not be marked Done until the reconciled source is reviewed and
the actual deployed compatibility evidence is supplied. A green unit suite
does not replace that evidence. Do not merge, upload, or delete old release
work automatically.
