# AB-68: Flutter Refine and library compatibility

Implementation branch: `codex/ab68-refine-library`.
Mobile baseline: `5d9fabeeb0f70bded48de0a9196a488155a4a460` (PR #37).
Backend contract reviewed against music-dna main `cf9dd839cedc4c5a7dfc8b63f023b09d1d4a7852`.

## Behavior

- Library, route hints, persisted resume references, session state and saved reports distinguish discover, explore and refine. Refinements group under their original with a distinct label. Historical absent modes remain originals; unsupported future modes are labeled and disabled without discarding other history.
- A completed reading offers registered owners a secondary **Refine My DNA — six more** action. A completed child resolves its original through normal owner-scoped session reads. Guests retain the existing save/account flow.
- Start uses the existing `POST /api/v1/session/:root/refine` with an `operation_id`. The operation is persisted under account + original before the POST. Interrupted or unclear responses, restarts and explicit retries reuse that operation. Double taps are disabled. A successful response is checked against an owner-scoped child lookup before navigation.
- The child reference is durably saved and read back before the operation is settled. Account changes or disposal prevent the old controller from opening or settling the run for another owner. No credentials or reading prose are stored by the operation store.
- The child enters the existing interview directly, without the opening-song form. Existing server flow lookup remains authoritative; Flutter does not assign checkpoint flow or infer it from the current feature flag. The backend currently treats an unassigned refinement flow as legacy `per_pick`.
- New-run progress counts only the child's answered choices. Cumulative dimensions use the server's report count and explicitly identify original + this refinement evidence. Flutter does no scoring or evidence pooling.
- Only explore runs request decade comparison. Mixed/refinement children cannot pollute decade history; previously started decades remain visible when new decades are unavailable.
- Saved reports reopen through the existing read-only report path. This implementation does not alter original text, versions, scores, optional learning consent, experiment enrollment, or model/provider settings.

## Verification

- Flutter analysis: no issues.
- Full Flutter suite: 358 passed, one existing skip.
- Unsigned iOS Simulator compile passed using the existing production client configuration.
- New regression coverage includes mixed/historical/future modes, decade filtering, owner/root binding, inaccessible-root denial without POST, normal bearer requests, child verification, double taps, interrupted-response replay across restart, account switching, failed resume persistence, direct interview navigation, guest action visibility, saved-report GET-only recovery, cumulative-count labels, skips and four-/six-answer interview boundaries.
- HTTP/model responses in these tests are fixtures. They do not establish live backend authorization, cumulative scoring quality, or physical-device acceptance.

## Remaining acceptance (AB-86)

On the next approved TestFlight candidate, with an owned completed original:

1. Open a library containing original, decade and web-created refine rows; confirm labels, grouping, parent links and saved reports.
2. Start Refine once; verify no opening-song onboarding, correct original root and authoritative interview flow. Interrupt/restart during start and confirm the same child resumes.
3. Exercise supported four-answer finish and six-answer completion, including skips; verify child progress versus cumulative report counts and unchanged original/version. Four-answer checkpoint availability must come from the backend's assigned flow, not a Flutter override.
4. Reopen the saved child; verify no new generation. Confirm discover/refine show no decade comparison and existing decade history remains accessible.
5. Sign out/switch accounts during an unresolved start; confirm no cross-account navigation/data. Confirm the existing AI permission and guest-save paths still apply.

Source version stays `0.1.2+17`. This change was not archived, signed, exported, uploaded, deployed or exercised against a real listener. Newer web quip pacing/report recovery and other parity tickets remain separate work. Alan merges and separately approves release actions.
