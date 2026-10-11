# First-Session Journey: Integration Checklist

October 10, 2026. Backend reference `music-dna@17ef912`; mobile changes are
consolidated in idea-builder PR #11, including feedback foundation PR #13.
Agent Brain work is deferred. This is the current checklist; earlier foundation
notes in the ticket-specific documents describe their dated checkpoints.

## Native Journey

- [x] Existing three-song onboarding and server-driven choices preserved.
- [x] Versioned result, explicit publication, and full reading from merged PR #12.
- [x] Push back reachable from the versioned result, retaining original identity.
- [x] Chat REST maps message IDs/mutation IDs and saved version content. Pending
      409 is uncertain delivery. Reading the exact mutation and its `:reply`
      reconciles delivery without POST or invented local messages.
- [x] Native feedback uses actual GET/POST, result version and accuracy aliases;
      checks saved content after acknowledgment, retains drafts, serializes taps.
- [x] Canonical share URL retained and published version modeled. Mismatched
      versions cannot become verified copyable links.
- [x] PRD v1.2 trace mirrored byte-for-byte (79 IDs); exact ID-set and duplicate
      checks in Flutter. Mapping does not accept catalog requirements.
- [ ] Authenticated deployed persistence/replay/ownership acceptance.
- [ ] Real iPhone keyboard, scroll, large text, navigation and recovery.
- [ ] Native share-sheet behavior (current sharing remains clipboard-based).
- [ ] Approved release build and controlled experience-v1 rollout.

`MUSICDNA_EXPERIENCE_V1` remains false by default. Opt-in testing uses REST for
chat and feedback. No Apple version bump, backend deploy, or Agent Brain call.

## Remaining Backend Acceptance Issues

Concrete source findings, not another architecture pass:

1. Feedback GET omits `mutation_id`. Flutter cannot reconcile a lost POST
   acknowledgment to the exact mutation, so uncertain delivery stays blocked.
   Restored records use a read-only marker, not fabricated mutation evidence.
2. Feedback update lookup uses owner/session/target, not result version. Another
   version with the same target can replace earlier feedback. Validate result
   existence, isolate versions, and prove atomic replay/changed-key rejection.
3. Chat returns latest 200 messages without pagination. Older omitted messages
   cannot be restored. A turn without a saved reply can remain pending forever;
   interrupted-turn recovery still needs proof.
4. Self-report versions now expose content, but still copy the base synthesis.
   Native displays stored content/provenance, not an invented revised reading.
5. Share metadata reports latest result version while public lookup uses session
   reveal data. Prove that reported version matches the public snapshot after
   chat. Flutter rejects a reported version different from the original result.

Immediate critic-profile adjustments remain Lovable-owned. Flutter does not
implement batching, change diagnostic scores, or publish through feedback.

## Evidence

Web at `17ef912`: 219 tests passed, 3 skipped (authenticated harness not run);
`tsc --noEmit` clean. Existing dependency runtime reused; no web changes committed.

Production read-only feedback probe: typed 401 and CORS headers on
`www.musicdna.fm`; GitHub reports successful Vercel deployment of `17ef912`.
This does not verify authenticated writes, migrations, or physical devices.

Flutter: 112 tests pass, analyzer clean, iOS Simulator debug build succeeds.
Both trace readers compare full PRD criteria and priorities; CAT05/CAT07/CAT08
text was corrected in the coordinated trace-only web change and mirrored here.
`cmp` confirms byte-identical JSON. No acceptance status was promoted.
Shared trace acceptance remains pending. Modern catalog delivery is separate
from trace synchronization; unchanged fixtures are not deployed behavior proof.
