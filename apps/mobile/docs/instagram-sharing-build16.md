# AB-81 — Instagram card sharing (build16)

Reviewed 13 November 2026 against web main `1b4c906` and the Share card section
of `docs/musicdna/experience-contract-v1.md`. Build15 (0.1.2) was submitted to
Apple by Alan; this work stays in the next, unuploaded build16 alongside PR34.

## Mobile behavior

A completed report exposes **Share to Instagram Story** and **Square post image**
only after its existing publication control returns a verified public token tied
to that exact result version. Creating an image never publishes a private report.
Older links without a verified result-version binding keep existing link controls
but do not expose image export until a version-bound publication is available.

On an explicit tap:

1. Fetch the published card with no bearer credential from the configured API
   origin: `/api/v1/share/:token/card?format=story|square`.
2. Require successful SVG content, bounded size, exact dimensions and a
   self-contained geometry/text document. Reject external resources and scripts.
3. Use `flutter_svg` to rasterize the server's SVG into a 1080×1920 Story or
   1080×1080 square PNG. Do not regenerate/rewrite the reading or match archetypes.
4. Recheck public availability and the unchanged SVG after conversion. Fresh
   requests bypass the route's existing five-minute cache; owner, session,
   version and token changes abort preparation.
5. Hand an image-only PNG file to the native share sheet, with a button anchor
   for iPad. Recheck the local publication/owner guard immediately before opening.

The listener chooses the destination. Instagram availability and Story routing
are controlled by Instagram/the OS; this is not a direct Meta Stories SDK
integration. No Meta app ID, app-specific credential, auto-posting or automatic
Photos-library write is introduced. A completed share-sheet callback is not
proof that Instagram published a Story. Cancellation stays quiet; unknown
outcomes and errors use controlled copy, and retry requires another tap.

Public PNG files are written only to the app's dedicated temporary share folder.
Files older than 24 hours are removed on a subsequent share; OS cache cleanup
may remove them earlier. Current files remain available long enough for receiving
apps to read them. No token, bearer, raw SVG/report or provider error is logged.
Revoking a link cannot recall images already handed to another application.

Architecture: passive actions → ShareCardCubit → public-card repository /
renderer / native sender, registered through existing app DI. Existing
publish/verify/revoke controls and their consent behavior remain authoritative.
Pinned dependencies use the installed SDK/Android toolchain; no Flutter or AGP
upgrade. The iOS pod lock includes only the new sharing plugin addition.

## Verification

Automated tests exercise the actual SVG-to-PNG renderer (including non-background
text pixels), exact dimensions, public-only requests with no bearer, fresh
revalidation, refusal/error handling, malformed/external SVGs, source and remote
revocation races, image-only native parameters, iPad anchors, cancellation,
publication/version gating and small-screen large-text controls.

The native iOS Simulator app compiled successfully. This is not a signed archive
or an Apple upload. A deployed GET for an intentionally unpublished token
returned 404 NOT_FOUND; no live listener reading was exported or published.

Still verify in TestFlight on physical devices:

- Publish a disposable reading explicitly; inspect Story and square previews.
- Open the share sheet with Instagram installed and absent; verify the actual
  available Instagram actions and that choosing one receives the image.
- Verify cancellation, network failure/retry, Stop sharing, and re-opening a
  saved report. Confirm exported text is the published version.
- Verify iPhone/iPad font fallback, text layout and share-sheet placement. Test
  render artifacts use a locally supplied diagnostic font, not a design signoff.

## Lovable follow-up prompt

Please fix the web share-card implementation, preserving the existing endpoint,
publication consent and frozen reading content. Do not add automatic publishing.

1. **Bound all card content.** `src/musicdna/engine/share-card.ts` places a
   five-line square headline's third choice at baseline y=983, while the footer
   is at y=970. The long fixture in Flutter's `test/fixtures/share-card` reproduces
   the overlap. Reserve the footer area and wrap/fit long headline words,
   Archetype names and chosen/rejected song names inside the 90–990 content area.
   Keep up to three choices and do not invent or strengthen claims. Add boundary
   tests for both formats, missing archetype and long text.
2. **Honor revocation on asset reads.** The card route currently returns
   `Cache-Control: public, max-age=300`. A cached card can outlive revocation even
   though a fresh database lookup refuses the token. Use non-storing cache
   headers (including any provider/CDN policy), then verify a warm card URL after
   revoke returns 404. Flutter uses fresh per-operation URLs, but the shared
   endpoint's normal-URL behavior still needs correction.
3. **Make browser failures visible.** In `share-to-instagram.tsx`, check
   response.ok/content-type before decoding. Catch fetch/decode/share/download
   failures with an inline retryable message; treat AbortError as cancellation
   without hiding genuine failures. Dispose object URLs after use, including
   errors. Do not present a chooser callback as proof of an Instagram post.

Return source/test/deployment evidence separately from live phone acceptance.
No user account, grant, key, migration, learning flag or saved report changes
are required for these fixes. Mobile consumes the corrected SVG automatically.
