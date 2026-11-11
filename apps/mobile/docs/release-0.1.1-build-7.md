# MusicDNA 0.1.1 (7)

## One production backend

The native candidate uses `https://www.musicdna.fm` for both API and sharing,
with `MUSICDNA_EXPERIENCE_V1=true` in public client build configuration. Supabase
remains `udycgnhvaanemhrchbuj`; use its existing public client key, never a service
or model key. `config/prod.example.json` is the shipping template.

Alan approved production V1 activation on November 10, 2026. Merged backend PR42
is commit `36415e91cd6c6694ac5d7ce6074b66f83a3ce78a`; production deployment is
`dpl_GULDoxRJbiBo6EMxz5V1pPwWPSsS`. The installed build6's compatibility address
`musicdna-beta-alan-edgetts-projects.vercel.app` now aliases that SAME production
deployment, rather than a separately configured backend snapshot. Both public
version endpoints report the same commit; ordinary V1 requests with Flutter's
experience header reach normal 401 authentication, rather than the old 503 gate.
No protection, credential, learning-scope, reviewer or pilot changes were made.
Keep the compatibility address until older binaries are retired; it is pinned,
so check/repoint it when production advances until direct-origin builds replace
those binaries. Do not silently turn it into a second release environment again.

The separate custom-environment build `dpl_DRCqxsC1QVnQSd1rH5BNbsFZs8KA` completed
before Alan requested production consolidation. No shipped app alias points to it.
It is a retained deployment, not another required backend or release dependency.

## Native behavior

- The server supplies halftime guidance after three answers and the optional
  initial-reading milestone after four; continuing doesn't submit a song vote.
- Early reveal sends `finish_early:true`. An uncertain reply retains that intent
  for retry, so it cannot accidentally become a different completion operation.
- The final narrative, twist and challenge are shown together. Frozen evidence
  remains under The receipts; older saved results keep their supported layout.
- The collapsed React to the Critic control from merged PR19 remains below songs.
- Compact reads mirror web's omission of numeric audit parentheticals; complete
  saved wording remains available in interview history. No new prose is composed
  on the phone.
- Best-effort preparation calls the shared authenticated server implementation
  once per visible offered exposure. It does not run while a milestone hides the
  pairing, block choices, retry unknown generations or submit an accuracy rating.
- Critic choice, reveal, preparation and chat requests allow the same bounded
  45-second wait as web. Other API operations retain their existing timeouts.

Writer/reviewer code defaults are `gpt-6.1-sol` / `gpt-6.1-terra`. Production has
the approved OpenAI key and no role model overrides. This establishes configured
parity; actual returned models and generation quality require a fresh signed-in
run. Previously saved/replayed readings are immutable and will not acquire a
new voice just because the backend is updated.

## Build and acceptance

Version `0.1.1+7`, bundle `fm.musicdna.app`, EK Enterprises team `SK2W4373LK`, iOS15.
Build6 is consumed; build7 is the next candidate. Analysis, existing and new
regressions, and unsigned normal-entry production-origin compilation are checked
before PR review. Offline widget renders are implementation previews, not device
screenshots, live model success or TestFlight acceptance.

After Alan merges the native PR, archive/export that clean merged source using
the existing EK Enterprises distribution signing. Record the exact source and
archive/export receipt. Preparation does not imply Apple upload, processing,
TestFlight installation or App Store release. Alan owns final release promotion.

TestFlight review: opening songs, choices/skip, halftime, continue, four-answer
Read me now, six-answer completion, reactions/retry, full reveal, history/resume,
conversation, sharing/revoke, login and optional exact-version accuracy feedback.
Use a fresh owner-QA run to inspect actual writer/reviewer metadata; no automatic
rating, preference inference or product-improvement claim.

The [App Store draft](app-store/0.1.1-en-US.json) and
[screenshot capture plan](app-store/screenshots-0.1.1.md) prepare the public listing.
Capture final screenshots after build7's TestFlight review, then submit only with
Alan's release approval.
