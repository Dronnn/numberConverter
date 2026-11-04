#!/usr/bin/env python3
"""Check a dated, saved App Store price snapshot against its storefront policy."""

import argparse
import csv
import json
import re
from collections import Counter
from decimal import Decimal
from pathlib import Path


def validate(csv_path: Path, policy_path: Path) -> dict:
    policy = json.loads(policy_path.read_text(encoding="utf-8"))
    expected = policy["storefronts"]
    if len(expected) != 175 or len({s["storefront"] for s in expected}) != 175:
        raise ValueError("Policy must contain 175 unique storefront codes")
    by_code = {s["storefront"]: s for s in expected}
    aliases = policy["countryAliases"]
    tiers = ("small", "medium", "large", "extraLarge", "patron")
    with csv_path.open(encoding="utf-8", newline="") as source:
        reader = csv.DictReader(source)
        if reader.fieldnames != [
            "country", "storefront", "band", "currency", *tiers, "management"
        ]:
            raise ValueError("Unexpected price snapshot columns")
        rows = list(reader)
        if any(None in row or any(value is None for value in row.values()) for row in rows):
            raise ValueError("Snapshot row has missing or extra columns")
    if len(rows) != 175 or len({r["storefront"] for r in rows}) != 175:
        raise ValueError("Snapshot must contain 175 unique storefront codes")
    if {r["storefront"] for r in rows} != set(by_code):
        raise ValueError("Snapshot storefront membership differs from policy")
    if len({r["country"] for r in rows}) != 175:
        raise ValueError("Duplicate country labels")
    for row in rows:
        code = row["storefront"]
        rule = by_code[code]
        label = re.fullmatch(r"(.+) \(([A-Z]{3})\)", row["country"])
        if not label or label[2] != row["currency"]:
            raise ValueError(f"{code}: country label/currency mismatch")
        name = aliases.get(label[1], label[1])
        if name != rule["country"]:
            raise ValueError(f"{code}: country differs from policy")
        for field in ("band", "management"):
            if row[field] != rule[field]:
                raise ValueError(f"{code}: {field} differs from policy")
        manual = rule["band"] in {"reduced", "low", "lowest"}
        if (rule["management"] == "manual") != manual:
            raise ValueError(f"{code}: inconsistent policy management")
        amounts = []
        for tier in tiers:
            # ASC's saved English UI uses a currency prefix and grouped decimal.
            match = re.fullmatch(
                r"[^0-9+\-−﹣－()]*((?:[0-9]{1,3}(?:,[0-9]{3})+|[0-9]+)\.[0-9]{2})",
                row[tier],
            )
            if not match:
                raise ValueError(f"{code}: malformed {tier} price")
            amounts.append(Decimal(match[1].replace(",", "")))
        if any(amount <= 0 for amount in amounts) or any(
            right <= left for left, right in zip(amounts, amounts[1:])
        ):
            raise ValueError(f"{code}: prices must be positive and increase")
    return {
        "asOf": policy["asOf"],
        "storefronts": len(rows),
        "prices": len(rows) * len(tiers),
        "entryProductManagement": dict(Counter(r["management"] for r in rows)),
        "bands": dict(Counter(r["band"] for r in rows)),
    }


def main() -> None:
    root = Path(__file__).resolve().parent.parent
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--csv", type=Path,
        default=root / "AppStoreAssets/pricing/storefront-prices.csv",
    )
    parser.add_argument(
        "--policy", type=Path,
        default=root / "AppStoreAssets/pricing/storefront-policy.json",
    )
    args = parser.parse_args()
    try:
        result = validate(args.csv, args.policy)
    except (ValueError, KeyError, OSError) as error:
        parser.exit(1, f"Regional pricing validation failed: {error}\n")
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
