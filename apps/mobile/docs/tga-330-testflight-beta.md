# TGA-330 internal TestFlight candidate

October 20, 2026. Candidate version **0.1.1 (4)**, bundle `fm.musicdna.app`, team `SK2W4373LK`. App Store Connect app ID `6792135241` under EK Enterprises.

## Verified build reservation

The authenticated TestFlight page and expanded Build Uploads list showed only 0.1.1 (3), 0.1.1 (2), and 0.1.0 (1). Build 3 was complete/uploaded July 20 and is now expired. Build 4 is the next candidate; recheck Apple before upload if another developer uploads in parallel. A local archive does not consume the number.

## Source and configuration

Use this commit's normal `lib/main.dart` entry, `config/beta.local.json`, and the verified target in `tga-328-beta-client.md`. Preserve the original historical checkout. Record the actual source SHA and public configuration hash alongside the archive. Never use a reference/fixture entry point or carry server/bypass keys in the app.

The passing 125-test/analysis/release-compilation evidence and live beta GET/mutation decoding evidence apply to the unchanged application implementation. This candidate changes version metadata and documentation only. Regenerate generated iOS configuration for build 4 before archiving; verify bundle/team/version/build and compiled beta origins.

## Apple delivery status

Preparation only. No signed archive, export, upload or new processing success is claimed here. Apple currently displays an updated Developer Program License Agreement notice for the account holder to review. Acceptance of legal terms belongs to the user. Signing/export availability must still be verified with Xcode's available account or managed signing access.

Do not mark TGA-330 Done until Apple processing finishes and build 4 is actually installable for the intended existing internal reviewer. Do not invite new testers or enable external/public release. Record final upload/processing state in the ticket and release record.

## TestFlight review notes

Sign in with your MusicDNA account; begin/resume onboarding and the pairing flow; review the reading, discuss/challenge it in continuation, inspect saved interpretation versions, save accuracy feedback, and publish/revoke a share link. Screens now show chronological exchanges, expandable earlier rounds, server question prompts and revision provenance.

Beta uses the existing MusicDNA accounts/database. Evidence-limited results remain intentionally cautious; subjective reading quality, device interaction and accessibility belong to ACE's hands-on acceptance in TGA-329/TGA-321 after installation. Send defects back with the build number and screen/steps so Codex can prepare the next build.
