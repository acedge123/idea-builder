# MusicDNA 0.1.1 (11): AI processing permission

## Release behavior

Before a new interview or conversation, show a disclosure naming OpenAI and the
song titles, choices, reactions, reading context and messages sent to generate and
check the Critic. Offer explicit **Allow OpenAI processing**, **Not now**, and the
public Privacy Policy link. No preselected acceptance or silent migration of
existing users. This is service-processing permission, not optional learning
consent or publication authorization.

Remember acceptance per authenticated/anonymous owner and disclosure version on
this device. Reinstalling, another device, a different account or a revised
policy requires permission again. Account → AI permission can turn it off for
future requests; it cannot recall previously transmitted data.

The UI gate runs before interview Cubit creation/initialization. The API client
also checks model-capable operations before credential resolution, then validates
owner and permission again synchronously before transport. Reading library,
account management, immutable saved-reading retrieval, feedback and explicit
publication do not require AI permission. Saved-only initialization never asks for
a new matchup or falls back to generation when a saved reading is missing.

Permission is a native local setting. This change does not add a server consent
receipt, change the web experience, enroll anyone in learning, or modify production
flags, keys, API contracts, models or database access. Requests already dispatched
before revocation may finish. No live model call is required by the tests.

## App Store privacy draft

Six data types are saved in App Store Connect, linked to the user and not used
for tracking as Apple defines advertising tracking/data-broker sharing:

| Data type | Purposes |
| --- | --- |
| Email Address | App Functionality |
| User ID | App Functionality, Analytics |
| Other User Content | App Functionality, Product Personalization, Analytics |
| Product Interaction | App Functionality, Product Personalization, Analytics |
| Performance Data | App Functionality, Analytics |
| Other Diagnostic Data | App Functionality, Analytics |

These describe actual account storage, choice/reading/chat content and linked
quality/performance diagnostics. No advertising or marketing purpose is asserted.
Publication requires Alan's confirmation of Apple's final accuracy agreement;
saving these answers is not public App Review submission.

The public privacy-policy correction is Music DNA PR #45. It must be merged and
served at https://www.musicdna.fm/privacy before public submission. Alan confirmed
artwork rights and entered review contacts/support/copyright in Apple's UI.

## Validation and delivery

- Flutter analysis: no issues.
- Full Flutter suite: 191 passed, one optional live capture skipped.
- 18 new cases cover explicit permission, deny/cancel, persistence, stale policy,
  owner isolation, storage failure, token-refresh races, revocation, ordered writes,
  saved-only access with no generation fallback and small-screen large-text layout.
- Production API configuration is reused; no credentials are added to this branch.
- `ITSAppUsesNonExemptEncryption=false` remains in the packaged Info.plist.
- Build 11 is preparation only until Alan merges this PR and approves its upload.
  Build 10 remains selected in the public draft; nothing has been submitted for
  public App Review.
