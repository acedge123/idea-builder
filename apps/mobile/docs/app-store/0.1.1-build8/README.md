# MusicDNA build8 store package

Marketing copy is in metadata-en-US.json. It is a draft until build8 device acceptance; no public listing was changed. The release version is0.1.1, native build8.

Screenshot order and exact target sizes are in screenshot-manifest.json. Use actual native captures from the accepted candidate. The existing phone-Mirroring screenshots are QA evidence, not full-resolution App Store assets. Apple specification checked November11,2026 Pacific: https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/ .

Target iPhone Dynamic Island medium:1206×2622 portrait. If the binary continues supporting iPad, also capture iPad13-inch2064×2752 portrait. Do not resize phone UI into an iPad screenshot. Save PNG without the Simulator/Mac frame and inspect each export at its final resolution. Headline ideas in the manifest are optional captions; native UI must remain accurate.

Before submission: verify public privacy/support destinations and actual privacy/age-rating answers; provide review access through App Store Connect if required; complete Alan's TestFlight visual acceptance and final listing/public-release approval. Never commit credentials. No App Store submission was performed by preparing this package.

Native Home/sign-in captures are included for iPhone and iPad; the six authenticated storyboard scenes remain pending. The two `qa-*-mirroring.png` files in the local delivery folder are QA evidence only, excluded from store submission assets.

The local archive succeeded for fm.musicdna.app0.1.1(8), minimum iOS15, families1/2. The first export failed with Xcode “No Accounts” / no distribution certificate. After Alan signed into Xcode, the retry succeeded and exported /tmp/musicdna-build8-export/MusicDNA.ipa; hash is in build-receipt.json. Nothing was uploaded. Local archive: /tmp/musicdna-build8-release.xcarchive.
