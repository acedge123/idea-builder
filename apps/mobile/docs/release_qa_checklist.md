# MusicDNA Mobile QA And Release Gate

Use this checklist before every TestFlight or App Store build.

## Source And Build Provenance

- Read the [current AB-56 candidate notes](ab56-build6/README.md). Build6 is
  uploaded for internal testing; Apple processing and device acceptance are pending.
  Build5 is the last confirmed installed baseline.
  The [build3 record](release_baseline_0_1_1_build_3.md) is historical.
- Use the active `acedge123/idea-builder/apps/mobile` source, not the historical
  mobile copy in the Lovable web repository.
- Record source SHA, branch, API origin, contract capability and catalog/policy
  versions. Verify the deployed API with an authorized test identity; source
  inspection or an unauthenticated 401 is not contract acceptance.
- Build6 has been accepted by Apple upload validation. Never reuse6 for another
  archive intended for upload; the next new candidate needs7 or higher.
- Record archive creation, validation and upload dates with the exact source
  SHA. Do not infer a previous archive's SHA from the current branch.
- Preserve the original release branch until reconciliation is reviewed.

## Preconditions

- Work from a clean branch or detached checkout of the intended merge target.
- Choose the intended config: `config/beta.local.json` for the isolated internal
  TestFlight candidate, or `config/prod.local.json` only for an approved production
  release. Confirm:
  - `API_BASE_URL`
  - `SUPABASE_URL`
  - `SUPABASE_ANON_KEY`
- Bump `version:` in [`/Users/rastakit/tga-workspace/idea-builder/apps/mobile/pubspec.yaml`](/Users/rastakit/tga-workspace/idea-builder/apps/mobile/pubspec.yaml).

## Verification Commands

### Encryption declaration

`ios/Runner/Info.plist` declares `ITSAppUsesNonExemptEncryption` as Boolean
`false`. MusicDNA uses transport encryption for its backend connections and
authentication hashing/signature verification; it does not offer general-purpose
encryption, encrypted storage, a VPN, or custom cryptographic protocols. The
declaration covers exempt encryption, not an absence of HTTPS.

Apple reads this from the uploaded binary, so it must be present before archiving;
adding it during export cannot update a build already uploaded. Check the archived
app's effective plist before every export (substitute the actual archive path):

```bash
plutil -extract ITSAppUsesNonExemptEncryption raw -o - \
  /path/to/MusicDNA.xcarchive/Products/Applications/Runner.app/Info.plist
```

The output must be `false`. Reassess this declaration if encryption-related
features or dependencies change. Do not add an invented
`ITSEncryptionExportComplianceCode` or use this key to change App Store territory
availability; there is no separate France-distribution plist switch here.

References: [Apple's declaration guidance](https://developer.apple.com/documentation/security/complying-with-encryption-export-regulations)
and [the Info.plist key](https://developer.apple.com/documentation/bundleresources/information-property-list/itsappusesnonexemptencryption).

From [`/Users/rastakit/tga-workspace/idea-builder/apps/mobile`](/Users/rastakit/tga-workspace/idea-builder/apps/mobile):

```bash
flutter pub get
flutter analyze
flutter test
flutter build ios --release --dart-define-from-file=config/beta.local.json
```

These commands target the current internal beta release. Use `config/prod.local.json`
only after an explicit production API release decision. Archive from
`ios/Runner.xcworkspace` in the same clean checkout; do not archive an older copy.

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

### TestFlight handoff

- After processing and export compliance, verify the uploaded build explicitly
  lists the existing internal group **Friends of Music**. Upload success alone is
  not proof that the group received the build; add it if necessary.
- On November 11, 2026, that group's setting was **Automatic for Xcode Builds**.
  Build 8 listed the group in its build details. The group had one tester;
  never infer membership or invite another person without Alan's instruction.
- Save concise **What to Test** notes and confirm group access before reporting
  a build ready. Internal testing does not require submitting a public release.
- [Apple's internal-testing guidance](https://developer.apple.com/help/app-store-connect/test-a-beta-version/add-internal-testers)
  explains automatic distribution and manual assignment, including the separate
  behavior of Xcode Cloud builds.

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
