# App Store assets

Verified upload files for Number Systems Lab. [manifest.json](manifest.json) records dimensions, PNG checks, SHA-256 hashes, capture provenance and pending sets.

| Asset | Location | Status |
| --- | --- | --- |
| iPhone screenshots, 1206 × 2622 | `screenshots/iphone/{en,ru,es,de,fr,pt-BR}/` | Five scenes per language, verified |
| iPad screenshots, 2064 × 2752 | `screenshots/ipad/{en,ru,es,de,fr,pt-BR}/` | Five scenes per language, verified |
| iPhone Duo screenshots, 1398 × 2034 | `screenshots/iphone-duo/{en,ru,es,de,fr,pt-BR}/` | Five scenes per language, genuine current pose only |
| Product-page header, 3840 × 1646 | [Header](creative/header-3840x1646.png) | Dedicated placement asset |
| Search artwork, 3840 × 2560 | [Search](creative/search-3840x2560.png) | Dedicated placement asset |
| IAP image, 1024 × 1024 | [Tip artwork](in-app-purchases/tip-promotional-1024.png) | Shared across the five optional consumables |
| IAP review screenshot, 1206 × 2622 | [Support screen](in-app-purchases/support-review-en-usd.png) | Current US reference prices |
| Saved regional prices | [175-storefront CSV](pricing/storefront-prices.csv), [membership](pricing/storefront-policy.json) and [policy](pricing/POLICY.md) | 875 verified prices; 142 manual and 33 automatic entry-tier storefronts |

Each screenshot set is ordered: **Converter, All Bases, Calculator, Quiz, Help**. The files are exact copies of actual simulator captures, with no invented UI, resizing or retouching. Screenshots use the production StoreKit service without purchasing. The separate IAP review image uses a safe display fixture matching the independently tested local USD catalog; it does not show a payment sheet or account details.

The package contains **90 screenshots and four creative/IAP files**. Russian Calculator images were refreshed on all three devices after the base labels were corrected to «Основание»; the original truncated Duo image is not included. Duo images preserve the genuine native 1398 × 2034 display. The capture API did not expose a hinge angle, so the pose is **unknown**. These captures establish the current display only, without a claim about folded, unfolded or every possible pose.

All upload PNGs are 8-bit RGB without alpha, with valid chunk CRCs. Artwork is exported at 72 dpi; native screenshots preserve their original pixel dimensions and metadata. Reviewed screenshot metadata contains only screenshot/orientation/dimension information. The image bytes and hashes are unchanged from their source files.

The creative assets are language-neutral mathematical illustrations with the labels **2, 8, 10, 16, 36**. They were generated with image_gen and resized to the exact delivery sizes from 1914 × 822 (header) and 1536 × 1024 (search). They are not claimed to be natively generated at 4K. Essential artwork fits the reviewed Apple template safe areas. Assign Header and Search separately and verify their actual device previews in App Store Connect before publishing.

The application icon is included in the signed app's asset catalog. Watch, native Mac and TV screenshots are not included because this project has no corresponding native app.

This package does not establish final release-build acceptance, exhaustive accessibility or Dynamic Type coverage, saved App Store assignments, App Review submission or approval. Those are verified separately.
