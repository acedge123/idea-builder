# MusicDNA Mobile QA And Release Gate

Use this checklist before every TestFlight or App Store build.

## Source And Build Provenance

- Read the [0.1.1 build 3 baseline](release_baseline_0_1_1_build_3.md).
- Use the active `acedge123/idea-builder/apps/mobile` source, not the historical
  mobile copy in the Lovable web repository.
- Record source SHA, branch, API origin, contract capability and catalog/policy
  versions. Verify the deployed API with an authorized test identity; source
  inspection or an unauthenticated 401 is not contract acceptance.
- Build 3 has already been uploaded. The next upload needs a higher number.
- Record archive creation, validation and upload dates with the exact source
  SHA. Do not infer a previous archive's SHA from the current branch.
- Preserve the original release branch until reconciliation is reviewed.

## Preconditions

- Work from a clean branch or detached checkout of the intended merge target.
- Confirm `config/prod.local.json` has the correct production:
  - `API_BASE_URL`
  - `SUPABASE_URL`
  - `SUPABASE_ANON_KEY`
- Bump `version:` in [`/Users/rastakit/tga-workspace/idea-builder/apps/mobile/pubspec.yaml`](/Users/rastakit/tga-workspace/idea-builder/apps/mobile/pubspec.yaml).

## Verification Commands

From [`/Users/rastakit/tga-workspace/idea-builder/apps/mobile`](/Users/rastakit/tga-workspace/idea-builder/apps/mobile):

```bash
flutter pub get
flutter analyze
flutter test
flutter build ios --release --dart-define-from-file=config/prod.local.json
```

Archive from `ios/Runner.xcworkspace`.

## Core QA Pass

### Auth

- Sign up creates an account and routes into onboarding.
- Sign in restores a valid session.
- Sign out returns the app to an unauthenticated state.

### Onboarding

- Three valid songs submit successfully.
- Invalid opener input stays blocked by form validation.
- Offline or unreachable backend shows retry-oriented messaging.
- Expired auth shows `Sign in again`.

### Session Pairing Flow

- First pairing loads from a started session.
- Choosing song A advances the round.
- Choosing song B advances the round.
- Choice feedback appears between rounds.
- Offline failure shows retry messaging.
- Expired auth shows `Sign in again`.

### Reveal And Share

- Completed session can generate a reveal.
- Reveal shows archetype/interpre­tation and claim cards.
- Public share payload loads and defining choices render.
- `Copy share link` places a URL on the clipboard.

## Release Gate

Do not upload if any of these fail:

- `flutter analyze`
- `flutter test`
- sign in / sign up
- onboarding submit
- first pairing round
- at least one choice advancement
- reveal generation
- share link copy

## Observability Expectations

The app should emit structured logs for:

- auth initialize / sign in / sign up / sign out
- onboarding submit request, success, failure
- session initialize / next pairing / choice / reveal
- failure transitions and auth-expiry recovery
