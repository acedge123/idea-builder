# AB-83 — Web archetype artwork parity, build16

Reviewed 13 November 2026 against web `bfd2a67` (`ArchetypeArt`, `DnaIdentity`
and profile/shared-report additions). Mobile base `276e7ff` includes merged PR35
sharing and PR34 guest saving. This PR remains 0.1.2+16: build16 has not been
uploaded, while build15 is already submitted to Apple.

The completed/reopened report's shared `ReadingIdentity` view now shows the same
ink illustration between the confirmed/leaning label and saved archetype name.
It keeps the web's 384 logical-pixel maximum width, small rounded border and
original image proportions; it never crops artwork to a forced ratio. Artwork
has an accessibility label and is optional decoration: a failed asset never
hides the saved name, Critic text or report.

Six byte-identical JPEGs are bundled from web `public/archetypes`, totaling
351,024 bytes: Anthemist, Atmospherist, Hedonist, Romantic, Transformer, Witness.
Bundling avoids a new image URL/API requirement and works without a network
request. Hashes and the exact web commit are in `archetype-art-build16.json`.

No archetype is calculated from an image or rematched. Reports without a frozen
archetype retain their emerging signature or absent-state text, without art.
The approved six-archetype parser gate remains unchanged. Web also has a Believer
asset; that does not by itself authorize enabling this draft archetype on mobile.
Web profile/shared pages remain web-rendered; this does not add a new private
report request to the native Account settings screen.

Verification: all 315 Flutter tests pass (one optional deployed-contract snapshot
skipped), analyzer clean, unsigned iOS Simulator build succeeds. All six JPEGs
were verified byte-identical to web and present in the built native asset bundle.
A 390×844 saved-report layout was rendered and inspected with diagnostic text
fonts; the complete illustration is visible above its saved name and read.
No permanent tests were added for this presentation-only change.

No backend/schema/flag/credential/signing or Apple upload changes. Alan owns merge
and the later build16 release approval. Physical TestFlight inspection is pending.
The server-rendered Instagram card design updates automatically through the
existing SVG endpoint; artwork on the report does not add art to the PNG card.
AB-82's card layout/caching/browser-error work remains a separate web follow-up.
