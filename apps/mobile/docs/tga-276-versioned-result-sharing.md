# TGA-276: Versioned Flutter results and explicit sharing

## Scope

Flutter-only follow-up to TGA-276 and the mobile portion of TGA-311. Based on
Flutter main `d35a2c4`; reviewed Lovable API/spec at `7d0aeca` with the accepted
experience implementation `f058f49`. Lovable reported authenticated production
verification of create/choice replay/reveal/publish/revoke/resume. This change
does not independently claim an authenticated production Flutter test.

`MUSICDNA_EXPERIENCE_V1` remains false by default. Apple 0.1.1 build 3 is unchanged.
No backend, database, deployment, Railway, routing-policy or catalog edits.

## Result contract

- Opted-in reveal sends `X-MusicDNA-Experience: 1`.
- Parse `contract`, `result_version`, `outcome`, `headline`,
  `supporting_choices`, `tension` and the nested legacy `full` separately.
- Unsupported contract/version/outcome or malformed required fields fail
  recoverably instead of producing a blank reading.
- Display the server headline, up to two evidence groups, counts and tension.
  Full reading is expandable; new presentation does not turn fit into probability.
- Authoritative completion automatically requests the saved reveal; Dart does
  not decide claim eligibility or regenerate critic copy.
- Keep the original result object unchanged through publication and failures.
- Legacy clients keep the original reveal DTO, header and presentation behavior.

## Publication contract

Reveal's token (including any unexpected non-null v1 token) is not consent.
No automatic publication or public lookup occurs on a new private result.

The owner explicitly taps Publish this read to POST
`/api/v1/session/:id/share` with `{ "publish": true }`. Before a link can be
copied, GET `/api/v1/share/:token` must succeed and match the session and token.
Prefer a valid HTTPS `share_url` if supplied. The currently accepted endpoint
returns only `is_public`/`share_token`, so fall back to the configured public
origin plus `/s/:token` with the token encoded as one path segment.

Stop sharing sends `{ "publish": false }`. Hide the old link as soon as the
operation starts, including on a failed or uncertain acknowledgment. Keep an
explicit revoke retry available when publication might remain active. A
successful revoke relies on the server's revocation acknowledgment; this client
does not independently re-fetch every historical link to prove a 404.

Public lookup failures do not discard the private reading. Verify link retries
only the GET, not another publication. Serialized operations ignore duplicate
taps. Resume restores publication metadata without publishing or inferring
consent from a token. Structured new sharing events omit tokens and content.

## Remaining acceptance

- Physical iPhone text, scroll, VoiceOver and signed-build testing.
- Authenticated Flutter integration against the production/staging API.
- TGA-311's server-returned canonical URL and published result-version metadata
  remain absent from the accepted endpoint; this change does not complete those
  backend acceptance items or certify frozen public projections.
- TGA-316 remains separately gated pending the mobile chat API. Its draft PR is
  not included in this independent branch; integrate Push back after review.
- No release upload or feature-flag promotion is performed by this PR.

Automated coverage uses HTTP mocks plus Cubit and small-phone/large-text widget
tests. It proves client behavior, not deployed auth, persistence or device QA.

Local verification: `flutter analyze --no-pub` clean; `flutter test --no-pub`
71 passed (12 new result/sharing tests); iOS simulator debug build succeeded.
