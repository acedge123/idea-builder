# TGA-328 verified beta client target

October 20, 2026: TGA-328 is complete. Normal authenticated beta access and the automated API/Flutter contract matrix passed. This establishes a usable internal beta target; ACE owns hands-on QA and acceptance after TestFlight installation.

## Configuration

- API and share origin: `https://musicdna-beta-alan-edgetts-projects.vercel.app`.
- Backend: `music-dna@19c1e73ab61c59fa4fbbf09f4134f482d7a4967a`, Vercel deployment `dpl_E9Tboa3WPdKWXku7Cni9iLPRmdu8`.
- Vercel custom environment `musicdna-beta`: V1 enabled, Persistence V2 enabled, private acceptance disabled, routing `shadow`. Harness key excluded.
- Exact beta alias bypasses Vercel SSO; normal application bearer and ownership checks remain mandatory. No bypass token belongs in Flutter.
- Flutter base: `idea-builder@5ab06b707dfa3f070125f73f99aefd6db93389a7`.
- `config/beta.example.json` records the actual target. Ignored `config/beta.local.json` supplies only the existing public client key, `APP_ENV=beta`, and `MUSICDNA_EXPERIENCE_V1=true`.
- Existing Supabase project `udycgnhvaanemhrchbuj`: accounts/database are shared with production. API configuration is separate. Production variable values/targets and public V1 gate were preserved.

The user explicitly approved the server-credential reuse and beta alias access before configuration was applied. Server keys remain in Vercel. No OpenAI, service-role, harness or Vercel bypass key belongs in the client configuration or binary.

## Compatibility correction

Current backend feedback persistence stores immutable operations, so multiple feedback saves can belong to one result version. The earlier Flutter reader treated multiple rows as invalid and ignored the now-present mutation ID. It now selects the newest timestamped operation within the exact version/target, retains its mutation ID, rejects ambiguous ties/duplicate IDs and validates mutation identity after an acknowledged save. Older versions are untouched; legacy single-row responses remain readable.

This supports existing TGA-313 scope and does not certify the live write/retry UI. No backend scoring, result inference or policy moves into Dart.

## Automated evidence

- Existing Flutter suite: 125 passed with the optional deployed capture configured; analysis clean; normal-entry unsigned iOS release compilation passed.
- Beta owner snapshot/next/chat/feedback return contract 1; foreign reads deny 403/404, including the previously failing foreign-next case. Anonymous protected reads return 401. Legacy no-header snapshot retains its original shape. Beta harness unavailable; production public V1 remains 503-gated.
- A new approved synthetic-owned session ran start, next, reaction, six real choices, server completion and reveal. Feedback replay/conflict, chat replay/conflict/changed revision, frozen original, version-specific feedback, paged transcript, pinned anonymous share, revocation and cross-user chat/feedback/share write denial passed. Temporary synthetic shares were revoked.
- Real beta GET payloads passed through the actual Flutter session/history/continuation/feedback repositories. Real replayed mutation captures also passed Flutter choice/reaction/reveal/continuation submit/feedback submit/publication/shared/revocation repository parsing.
- Raw captures contain synthetic reading data and remain local, mode 0600. Never commit them or credentials. Sanitized deployment/configuration evidence is attached to TGA-328.
- The earlier compiled beta app embeds this now-live API origin and contains no server/provider/harness secret markers. It was unsigned build 3 and is not an upload candidate.

## Delivery and rollback

TGA-330 owns a unique build increment, exact-source signed archive/export/upload, Apple processing and actual internal installability. ACE performs all hands-on functional/recovery and visual/device/accessibility QA in TGA-329/TGA-321 afterward. Automated technical checks still run before upload.

Rollback only the beta alias exception/alias or beta V1 flag. Preserve production domains/flags and shared listener data. No production release, schema/catalog migration or device/user acceptance is implied.
