# AB-84 final-wait and report-recovery parity

This follow-up supersedes the selection/recovery details in `ab84-six-pick-pacing.md`. Web reference: `acedge123/music-dna` commit `3fa9a4273fd4b954312af2ad677e0d2df8252b9a`. Mobile base: `263cebffd6a96eaba0da15c913b8ea0aef21c12b` (merged AB-68). Candidate remains 0.1.2 (17); local feature-branch QA is separate from TestFlight release approval.

## Final waiting copy

Use unused neutral/reaction lines and an unused compatible whole Person group. At answer six the Person group must be two lines. Preserve the actual painted setup and punchline, 2500 ms beat deadline and one-use owner/interview ledger. A slow final vote stays neutral until its saved hunch arrives; Overtime requires final writing and that hunch. Automatic report recovery does not restart the quip clock or replay the vote.

The generated fixture executes the unchanged web selector for 315 cases, including both flows, all six picks, hunches, eras, history fallback, partial groups, exhaustion and sequential interviews. It records source hashes. Regenerate with `node tool/generate_critic_wait_parity.mjs /path/to/music-dna`.

## Final report recovery

1. Read the saved report first; return it without generation when present.
2. After every failed or unsaved generation response, check the saved report again.
3. If no report exists, permit only one automatic second generation after explicit `invalid_generation`. Preserve early-four intent.
4. Do not automatically retry transport/provider/unknown outcomes or when saved readback is unavailable. The original write may still complete. Explicit user retry also reads the saved report first.
5. Navigation/closure supersedes outstanding operations before any further request or display.

The REST adapter preserves `narration_status` in the typed unsaved result. Rejected/failed drafts display plain retry guidance rather than claiming a report is still running or exposing final report actions. This mirrors web recovery; it does not fix or establish resolution of shared backend generation validation (AB-91).

## Automated validation

- 374 Flutter tests passed; one existing optional live-contract capture skipped.
- `flutter analyze --no-pub`: no issues.
- 315 generated web-oracle cases match Flutter.
- Recovery tests cover saved-first, concurrent completion, rejected drafts, bounded retry, early-four, transport/provider failures, unavailable readback and superseded owners/navigation.
- Widget tests cover final-save delay, no premature Overtime, original beat deadline through automatic retry and unsaved error UI.

## Physical QA and release

Physical candidate validation is pending. The local build uses production client configuration; no server code, migrations, model/provider settings, flags, consent or credentials change. No TestFlight upload or public promotion is included. Alan owns merge and release approval.
