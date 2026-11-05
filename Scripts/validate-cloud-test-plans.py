#!/usr/bin/env python3
"""Check Cloud plan membership against Xcode's native AllTests discovery JSON.

This checks test *definitions*, including parameterized Swift Testing methods.
It does not execute tests or prove that individual parameter cases passed.
"""

import argparse
import collections
import hashlib
import json
import sys
from pathlib import Path
import xml.etree.ElementTree as ET


LOCALES = ("en", "ru", "es", "de", "fr", "pt-BR")
PLAN_NAMES = (
    "CloudCore",
    "CloudSnapshots",
    "CloudSharedUI",
    *(f"CloudUI-{locale}" for locale in LOCALES),
    *(f"CloudAX-{locale}" for locale in LOCALES),
)
REFERENCE_KEYS = ("containerPath", "identifier", "name")


class ValidationError(Exception):
    """A plan cannot be proven to preserve the native test inventory."""


def require(condition, message):
    if not condition:
        raise ValidationError(message)


def read_json(path):
    with path.open() as source:
        return json.load(source)


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def native_inventory(path):
    data = read_json(path)
    require(not data.get("errors"), f"Native discovery reported errors: {data.get('errors')}")
    values = data.get("values", [])
    names = [value.get("testPlan") for value in values]
    require(len(names) == len(set(names)), "Native inventory has repeated plan configurations")
    require(set(names) <= {"AllTests", *PLAN_NAMES}, "Native inventory has unexpected test plans")
    baseline = [value for value in values if value.get("testPlan") == "AllTests"]
    require(len(baseline) == 1, "Expected one unfiltered AllTests discovery configuration")
    value = baseline[0]
    require(not value.get("disabledTests"), "AllTests discovery contains disabled tests")
    identifiers = [item["identifier"] for item in value.get("enabledTests", [])]
    require(identifiers, "Native discovery returned zero enabled tests")
    require(len(identifiers) == len(set(identifiers)), "Native discovery contains duplicate identifiers")
    require(all(len(item.split("/")) >= 3 for item in identifiers), "Unexpected native identifier format")
    return set(identifiers), [value for value in values if value.get("testPlan") != "AllTests"]


def targets(plan, label):
    entries = plan.get("testTargets", [])
    require(entries, f"{label}: no test targets")
    result = {}
    for entry in entries:
        reference = entry.get("target", {})
        require(all(reference.get(key) for key in REFERENCE_KEYS), f"{label}: incomplete target reference")
        name = reference["name"]
        require(name not in result, f"{label}: duplicate target {name}")
        require(
            set(entry) <= {"parallelizable", "target", "selectedTests", "skippedTests"},
            f"{label}/{name}: unsupported test filter or target option",
        )
        result[name] = entry
    return result


def selector_matches(selector, relative_ids, label):
    require(isinstance(selector, str) and selector, f"{label}: empty or non-string selector")
    matches = {item for item in relative_ids if item == selector or item.startswith(selector + "/")}
    require(matches, f"{label}: selector matches no native test: {selector}")
    return matches


def selected_ids(entry, inventory, label):
    name = entry["target"]["name"]
    relative = {item.split("/", 1)[1] for item in inventory if item.startswith(name + "/")}
    require(relative, f"{label}: native discovery has no tests for target {name}")
    selected = set(relative)
    if "selectedTests" in entry:
        selectors = entry["selectedTests"]
        require(isinstance(selectors, list) and selectors, f"{label}: empty selectedTests")
        require(len(selectors) == len(set(selectors)), f"{label}: duplicate selectedTests")
        selected = set()
        for selector in selectors:
            selected |= selector_matches(selector, relative, label)
    selectors = entry.get("skippedTests", [])
    require(isinstance(selectors, list), f"{label}: skippedTests is not an array")
    require(len(selectors) == len(set(selectors)), f"{label}: duplicate skippedTests")
    for selector in selectors:
        selected -= selector_matches(selector, relative, label)
    require(selected, f"{label}: target selection is empty")
    return {name + "/" + item for item in selected}


def validate(repository, inventory_path, plan_inventory_paths=()):
    inventory, embedded_plan_values = native_inventory(inventory_path)
    basis_path = repository / "AllTests.xctestplan"
    basis = read_json(basis_path)
    require(basis.get("version") == 1, "Unsupported AllTests format")
    require(
        set(basis.get("defaultOptions", {})) == {
            "codeCoverage", "codeCoverageTargets", "targetForVariableExpansion",
            "commandLineArgumentEntries",
        },
        "AllTests has unexpected default options; review discovery filters before changing the validator",
    )
    require(basis["defaultOptions"]["codeCoverage"] is True, "AllTests coverage must remain enabled")
    require(len(basis.get("configurations", [])) == 1, "AllTests must have one configuration")
    require(not basis["configurations"][0].get("options"), "AllTests has configuration overrides")
    basis_targets = targets(basis, "AllTests")
    require(
        set(basis_targets) == {item.split("/", 1)[0] for item in inventory},
        "Native discovery targets differ from AllTests; enumerate all three targets without filters",
    )
    for name, entry in basis_targets.items():
        require(not entry.get("selectedTests") and not entry.get("skippedTests"), f"AllTests/{name} is filtered")

    actual_paths = sorted((repository / "TestPlans").glob("Cloud*.xctestplan"))
    require({path.stem for path in actual_paths} == set(PLAN_NAMES), "Expected exactly the 15 documented Cloud plans")
    scheme = ET.parse(repository / "numberConverter.xcodeproj/xcshareddata/xcschemes/numberConverter.xcscheme")
    references = scheme.findall("./TestAction/TestPlans/TestPlanReference")
    defaults = [item.get("reference") for item in references if item.get("default") == "YES"]
    require(defaults == ["container:AllTests.xctestplan"], "AllTests must remain the sole default plan")
    reference_paths = [item.get("reference") for item in references]
    require(len(reference_paths) == len(set(reference_paths)), "Scheme has duplicate test plan references")

    owners = collections.defaultdict(list)
    plans = {}
    extra_default_keys = {
        "testTimeoutsEnabled", "defaultTestExecutionTimeAllowance", "maximumTestExecutionTimeAllowance"
    }
    for path in actual_paths:
        label = path.stem
        require(f"container:TestPlans/{path.name}" in reference_paths, f"{label} is missing from shared scheme")
        plan = read_json(path)
        require(plan.get("version") == basis["version"], f"{label}: unsupported format")
        configurations = plan.get("configurations", [])
        require(len(configurations) == 1 and not configurations[0].get("options"), f"{label}: expected one configuration without overrides")
        options = plan.get("defaultOptions", {})
        require(set(options) == set(basis["defaultOptions"]) | extra_default_keys, f"{label}: unexpected default option keys")
        for key, value in basis["defaultOptions"].items():
            require(options.get(key) == value, f"{label}: differs from AllTests setting {key}")
        require(options.get("testTimeoutsEnabled") is True, f"{label}: test timeouts must be enabled")
        require(options.get("defaultTestExecutionTimeAllowance") == 600, f"{label}: short tests must retain the 600-second default")
        expected_maximum = 3600 if label.startswith("CloudAX-") or label == "CloudSharedUI" else 2700 if label.startswith("CloudUI-") else 600
        require(options.get("maximumTestExecutionTimeAllowance") == expected_maximum, f"{label}: unexpected maximum test allowance")
        members = set()
        for name, entry in targets(plan, label).items():
            require(name in basis_targets, f"{label}: unknown target {name}")
            require(entry["target"] == basis_targets[name]["target"], f"{label}/{name}: target/container identity differs from AllTests")
            require(entry.get("parallelizable") is False, f"{label}/{name}: native stateful tests must run serially")
            members |= selected_ids(entry, inventory, f"{label}/{name}")
        for identifier in members:
            owners[identifier].append(label)
        plans[label] = {
            "path": str(path.relative_to(repository)),
            "sha256": digest(path),
            "testDefinitionCount": len(members),
            "maximumTestExecutionTimeAllowance": expected_maximum,
            "identifiers": sorted(members),
        }
    missing = sorted(inventory - set(owners))
    extra = sorted(set(owners) - inventory)
    duplicates = {item: names for item, names in owners.items() if len(names) != 1}
    require(not missing, f"Tests omitted from Cloud partition: {missing}")
    require(not extra, f"Tests absent from native inventory: {extra}")
    require(not duplicates, f"Tests assigned to multiple shards: {duplicates}")
    native_selections = []
    selection_inputs = [(inventory_path, value) for value in embedded_plan_values]
    for path in plan_inventory_paths:
        data = read_json(path)
        require(not data.get("errors"), f"{path}: native plan discovery reported errors")
        values = data.get("values", [])
        require(len(values) == 1, f"{path}: expected one native plan configuration")
        selection_inputs.append((path, values[0]))
    verified_names = set()
    for path, value in selection_inputs:
        name = value.get("testPlan")
        require(name in plans, f"{path}: unexpected native plan name {name}")
        require(name not in verified_names, f"{path}: repeated native selection proof for {name}")
        verified_names.add(name)
        identifiers = [item["identifier"] for item in value.get("enabledTests", [])]
        require(len(identifiers) == len(set(identifiers)), f"{path}: duplicate native selected identifiers")
        require(
            set(identifiers) == set(plans[name]["identifiers"]),
            f"{path}: native selected tests differ from the validated {name} plan",
        )
        native_selections.append({
            "plan": name, "inventoryPath": str(path.resolve()),
            "inventorySHA256": digest(path), "testDefinitionCount": len(identifiers),
            "disabledTestDefinitionCount": len(value.get("disabledTests", [])),
        })
    return {
        "inventoryPath": str(inventory_path.resolve()),
        "inventorySHA256": digest(inventory_path),
        "allTestsSHA256": digest(basis_path),
        "testDefinitionCount": len(inventory),
        "countsByTarget": dict(sorted(collections.Counter(item.split("/", 1)[0] for item in inventory).items())),
        "pairwiseDisjoint": True,
        "unionEqualsAllTests": True,
        "nativePlanSelectionsValidated": native_selections,
        "plans": plans,
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--inventory", type=Path, required=True, help="Native flat JSON enumeration of unfiltered AllTests")
    parser.add_argument("--repository", type=Path, default=Path(__file__).resolve().parent.parent)
    parser.add_argument("--output", type=Path, help="Write provenance, hashes and exact plan membership JSON")
    parser.add_argument("--plan-inventory", type=Path, action="append", default=[], help="Also verify a native enumeration of a built Cloud plan; repeat for multiple plans")
    arguments = parser.parse_args()
    try:
        report = validate(arguments.repository.resolve(), arguments.inventory, arguments.plan_inventory)
    except (ValidationError, OSError, ValueError, KeyError, TypeError, ET.ParseError) as error:
        print(f"error: {error}", file=sys.stderr)
        return 1
    if arguments.output:
        arguments.output.write_text(json.dumps(report, indent=2) + "\n")
    print(f"PASS: {report['testDefinitionCount']} native test definitions in {len(report['plans'])} disjoint Cloud plans; complete AllTests union")
    for name, plan in sorted(report["plans"].items()):
        print(f"  {name}: {plan['testDefinitionCount']}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
