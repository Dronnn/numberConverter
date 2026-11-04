# Regional optional-tip pricing

All five saved schedules were reloaded and verified at **2026-11-04 22:01 UTC** (5 November in Yerevan). The [CSV](storefront-prices.csv) records exact customer-facing currency strings for all five tips in all 175 storefronts: **875 positive prices and 175 strictly ascending price ladders**. Its `management` column applies to the first two tips: **142 manual and 33 automatic** storefronts each. The three larger tips remain automatic everywhere. This is a dated snapshot, not a promise that automatic prices will remain unchanged.

The independent [storefront policy](storefront-policy.json) records the expected 175 country codes, canonical names, affordability bands and entry-tier management. Five explicit country-name aliases account for App Store Connect spelling differences. Exact membership was checked, rather than relying on matching country totals; Canada is automatic and Namibia is in the manually discounted low band. [Asset provenance](../manifest.json) records hashes of the policy, CSV and verified source proof. The CSV uses UTF-8 with LF line endings.

All app features remain free. Tips are optional, one-time App Store purchases. The reference US tiers are **$2.99, $8.99, $19.99, $49.99 and $99.99**. The three larger tips retain Apple's automatic comparable prices in every storefront. The application displays StoreKit's current localized `Product.displayPrice`; it does not determine prices from app language or track a user's income/location.

| Affordability band | Latest usable Atlas GNI per person, current USD | First/second reference targets, USD equivalent |
| --- | --- | --- |
| Standard | At least 40,000 | Keep automatic baseline 2.99 / 8.99 |
| Reduced | 10,000 to less than 40,000 | 0.99 / 3.99 |
| Low | 3,000 to less than 10,000 | 0.49 / 1.99 |
| Lowest | Below 3,000 | 0.29 / 0.99 |

These are the developer's **affordability hypotheses**, not World Bank income classes or validated conversion-rate optima. Country averages do not measure an individual's income, disposable income or purchasing power. Actual available local-currency price points may differ from the USD-equivalent targets; the CSV contains the saved amounts.

The data snapshot used 2025 observations for 160 storefronts and 2024 observations for 10. Yemen's numeric observation was stale, so its current **Low income** classification was used as an explicit fallback into the lowest discount band; its saved entry tips are $0.29 / $0.99. Four storefronts without a usable numeric value retain automatic baseline pricing. Missing data is not replaced with an invented parent-country value.

Examples from the saved snapshot: Germany €2.99 / €9.99; Lithuania €0.99 / €3.99; Armenia $0.49 / $1.99; India ₹29.00 / ₹99.00. Storefront availability and Apple's tax, exchange-rate and local price-point choices govern the actual purchase price.

Manual overrides stop Apple's future automatic FX/tax adjustments for those product/storefront pairs. **Review manual prices quarterly and after Apple repricing notices; refresh income data and band membership annually.** Keep the first two tips below the three larger options, and verify saved customer prices after changes.

Run `python3 Scripts/validate-regional-pricing.py` from the repository root after refreshing the snapshot. It checks exact storefront policy membership and entry-tip management, label/currency consistency, and all five positive, ascending local amounts. It validates the dated files; it does not fetch or change live App Store prices.

## Sources and attribution

Adapted from **World Bank, World Development Indicators**, indicator [GNI per capita, Atlas method (current US$), NY.GNP.PCAP.CD](https://data.worldbank.org/indicator/NY.GNP.PCAP.CD), under [Creative Commons Attribution 4.0](https://creativecommons.org/licenses/by/4.0/). The developer adapted the observations into the pricing bands above. World Bank has not endorsed this pricing policy. See the [dataset and license](https://datacatalog.worldbank.org/search/dataset/0037712/world-development-indicators), [Atlas method](https://datahelpdesk.worldbank.org/knowledgebase/articles/77933-what-is-the-world-bank-atlas-method), and [current income classification](https://datahelpdesk.worldbank.org/knowledgebase/articles/906519-world-bank-country-and-lending-groups).

Apple: [IAP pricing](https://developer.apple.com/help/app-store-connect/manage-in-app-purchases/set-a-price-for-an-in-app-purchase) and [custom price changes](https://developer.apple.com/help/app-store-connect/manage-in-app-purchases/schedule-price-changes-for-in-app-purchases).
