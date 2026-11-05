#!/usr/bin/env python3
"""Run the complete test inventory, with every UI definition on seven devices.

Read-only validation (no build, enumeration, simulator boot or test execution):
  python3 Scripts/run-local-test-matrix.py --validate-only --inventory native.json
  python3 Scripts/run-local-test-matrix.py --dry-run --inventory native.json

After the runtime owner releases the devices, execute the entire matrix:
  python3 Scripts/run-local-test-matrix.py --execute --output /absolute/new/run
Resume a prepared interrupted run without retrying failed/interrupted actions:
  python3 Scripts/run-local-test-matrix.py --resume /absolute/existing/run

Execution builds once, exports all scheme plans, obtains fresh native discovery,
then runs Core and Snapshots on the reviewed 3x Pro and every UI shard on EACH
requested device. It never creates/substitutes devices, records snapshots,
retries failures, deletes artifacts or changes Xcode/Simulator defaults.
Missing devices fail preflight; create them separately in Xcode Device Hub.
Use --destination KEY=UDID for an existing dedicated device/ambiguous clone.

Test plans specify test selection/configuration; native -destination chooses
hardware. MCP metadata tools are useful interactively, but are not an executable
checked-in runner. This portable runner uses Apple's xcodebuild/simctl tools:
https://developer.apple.com/documentation/xcode/organizing-tests-to-improve-feedback
https://developer.apple.com/documentation/xcode/running-tests-and-interpreting-results
"""

import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import plistlib
import signal
import shutil
import subprocess
import sys
import tempfile
from urllib.parse import unquote, urlparse


sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parent.parent
DEVICE_MODELS = {
    "iphone17e": ("iPhone 17e", "iPhone-17e"),
    "iphone16": ("iPhone 16", "iPhone-16"),
    "iphone17": ("iPhone 17", "iPhone-17"),
    "iphone18pro": ("iPhone 18 Pro", "iPhone-18-Pro"),
    "iphone18promax": ("iPhone 18 Pro Max", "iPhone-18-Pro-Max"),
    "iphoneduo": ("iPhone Duo", "iPhone-Duo"),
    "ipadmini": ("iPad mini (A20 Pro)", "iPad-mini-A20-Pro"),
}
DEVICE_KEYS = set(DEVICE_MODELS)


def require(condition, message):
    if not condition:
        raise ValueError(message)


def read_json(path):
    return json.loads(Path(path).read_text())


def write_json(path, value):
    path = Path(path)
    # Preserve the last complete report if the owner interrupts a long run.
    descriptor, temporary = tempfile.mkstemp(prefix="." + path.name, dir=path.parent)
    try:
        with os.fdopen(descriptor, "w") as stream:
            stream.write(json.dumps(value, indent=2, sort_keys=True) + "\n")
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def validator(repository):
    spec = importlib.util.spec_from_file_location("matrix_plan_validator", repository / "Scripts/validate-cloud-test-plans.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def configuration(path, repository):
    config = read_json(path)
    require(config["schemaVersion"] == 1, "Unknown matrix schema")
    require({d["key"] for d in config["devices"]} == DEVICE_KEYS and len(config["devices"]) == 7, "All seven device models must remain in the matrix")
    for device in config["devices"]:
        model, suffix = DEVICE_MODELS[device["key"]]
        require(device["model"] == model and device["deviceType"] == "com.apple.CoreSimulator.SimDeviceType." + suffix, f"Wrong device type for {device['key']}")
    require(config["sharedPlans"] == ["CloudCore", "CloudSnapshots"], "Core and Snapshots must each run once")
    expected = {"CloudSharedUI", *(f"CloudUI-{x}" for x in ("en", "ru", "es", "de", "fr", "pt-BR")), *(f"CloudAX-{x}" for x in ("en", "ru", "es", "de", "fr", "pt-BR"))}
    require(set(config["uiPlans"]) == expected and len(config["uiPlans"]) == 13, "Every exhaustive UI shard is required")
    require(config["snapshotHost"] == "iphone18pro" and config["snapshotHostDisplayScale"] == 3, "Snapshot references require the validated 3x Pro host")
    host = next(d for d in config["devices"] if d["key"] == config["snapshotHost"])
    require(host["deviceType"] == "com.apple.CoreSimulator.SimDeviceType.iPhone-18-Pro", "Snapshot device type changed")
    profiles = read_json(repository / "numberConverterTests/Resources/SnapshotReferences.json")["runtimes"]
    require(profiles.get(host["runtimeVersion"], {}).get("reviewState") == "reviewed", "Snapshot host runtime has no reviewed reference profile")
    require(config["minimumFreeGiB"] >= 15, "Keep the 15 GiB free-space guard")
    minimums = {"build": 60, "discovery": 60, "resultRead": 10, "core": 600, "snapshots": 600, "sharedUI": 3600, "normalUI": 2700, "largestTextUI": 3600}
    require(set(config["timeoutsSeconds"]) == set(minimums), "Every subprocess phase needs a wall-time bound")
    require(all(isinstance(config["timeoutsSeconds"][key], int) and config["timeoutsSeconds"][key] >= value for key, value in minimums.items()), "Wall-time bounds must retain the configured individual test allowances")
    require((repository / config["workspace"]).is_dir(), "Workspace is missing")
    return config


def plan_proof(repository, inventory, config):
    module = validator(repository)
    try:
        proof = module.validate(repository, inventory)
    except module.ValidationError as error:
        raise ValueError(str(error)) from error
    names = set(config["sharedPlans"] + config["uiPlans"])
    require({p["plan"] for p in proof["nativePlanSelectionsValidated"]} == names, "Supply native discovery of AllTests AND all 15 plans")
    ui_ids = {x for x in module.native_inventory(inventory)[0] if x.startswith("numberConverterUITests/")}
    selected = [x for p in config["uiPlans"] for x in proof["plans"][p]["identifiers"]]
    require(set(selected) == ui_ids and len(selected) == len(ui_ids), "UI shards must cover every UI definition exactly once per device")
    return proof


def resolve_devices(config, metadata, overrides):
    runtimes = {r["identifier"]: r for r in metadata["runtimes"]}
    resolved, errors = {}, []
    for spec in config["devices"]:
        runtime = runtimes.get(spec["runtime"], {})
        choices = [d for d in metadata["devices"].get(spec["runtime"], []) if d.get("isAvailable") and d.get("deviceTypeIdentifier") == spec["deviceType"]]
        if spec["key"] in overrides:
            choices = [d for d in choices if d["udid"] == overrides[spec["key"]]]
        elif len(choices) > 1:
            canonical = [d for d in choices if d["name"] == spec["model"]]
            if len(canonical) == 1:
                choices = canonical
        if not runtime.get("isAvailable") or runtime.get("version") != spec["runtimeVersion"] or len(choices) != 1:
            errors.append(f"{spec['key']}: need exactly one available {spec['model']} on {spec['runtime']} (found {len(choices)}); no device is substituted")
            continue
        resolved[spec["key"]] = dict(spec, udid=choices[0]["udid"], simulatorName=choices[0]["name"], initialState=choices[0]["state"], runtimeBuildVersion=runtime.get("buildversion"))
    require(len({d["udid"] for d in resolved.values()}) == len(resolved), "Two matrix slots resolve to the same device")
    return resolved, errors


def actions(config, proof, devices):
    selections = [(config["snapshotHost"], p) for p in config["sharedPlans"]]
    selections += [(d["key"], p) for d in config["devices"] for p in config["uiPlans"]]
    return [{"key": f"{index:03d}-{device}-{plan}", "deviceKey": device, "destination": devices.get(device), "plan": plan, "expectedIdentifiers": proof["plans"][plan]["identifiers"]} for index, (device, plan) in enumerate(selections)]


def source_hashes(repository):
    files = set()
    for folder in ["numberConverter", "numberConverterTests", "numberConverterUITests", "ConversionEngine", "TestPlans", "numberConverter.xcodeproj", "numberConverter.xcworkspace"]:
        for p in (repository / folder).rglob("*"):
            if p.is_file() and not any(part in {".build", ".swiftpm", "xcuserdata", ".git"} for part in p.relative_to(repository).parts):
                files.add(p)
    files.add(repository / "AllTests.xctestplan")
    files.update(p for p in (repository / "Scripts").glob("*") if p.is_file())
    return {str(p.relative_to(repository)): digest(p) for p in sorted(files)}


def product_hashes(products):
    return {str(p.relative_to(products)): {"sha256": digest(p) if p.is_file() else None, "symlink": os.readlink(p) if p.is_symlink() else None} for p in sorted(products.rglob("*")) if p.is_file() or p.is_symlink()}


def device_identity(devices):
    fields = {"key", "model", "deviceType", "runtime", "runtimeVersion", "runtimeBuildVersion", "udid"}
    return {key: {k: value[k] for k in fields} for key, value in devices.items()}


def action_identity(action):
    return {k: action[k] for k in ["key", "deviceKey", "plan", "expectedIdentifiers"]}


def command_json(arguments, timeout=180):
    return json.loads(subprocess.check_output(arguments, text=True, timeout=timeout))


def stop_owned_process(process):
    """Stop only the new process group created by this runner, never a simulator."""
    for termination, grace in [(signal.SIGINT, 30), (signal.SIGTERM, 10), (signal.SIGKILL, 10)]:
        if process.poll() is not None:
            return
        try:
            os.killpg(process.pid, termination)
        except ProcessLookupError:
            return
        try:
            process.wait(timeout=grace)
            return
        except subprocess.TimeoutExpired:
            continue
    require(process.poll() is not None, "Owned subprocess did not exit after bounded termination; stopping the matrix")


def logged(arguments, logfile, timeout, environment=None):
    print("Running:", " ".join(arguments), flush=True)
    with logfile.open("w") as stream:
        process = subprocess.Popen(arguments, stdout=stream, stderr=subprocess.STDOUT, env=environment, start_new_session=True)
        try:
            code = process.wait(timeout=timeout)
            return {"exitCode": code, "timedOut": False, "timeoutSeconds": timeout}
        except subprocess.TimeoutExpired:
            stream.write(f"\nRunner wall-time limit reached: {timeout} seconds. Retaining this action as failed.\n")
            stream.flush()
            stop_owned_process(process)
            return {"exitCode": process.returncode, "timedOut": True, "timeoutSeconds": timeout}
        except KeyboardInterrupt:
            stop_owned_process(process)
            raise


def action_timeout(config, plan):
    kind = {"CloudCore": "core", "CloudSnapshots": "snapshots", "CloudSharedUI": "sharedUI"}.get(plan)
    return config["timeoutsSeconds"][kind or ("largestTextUI" if plan.startswith("CloudAX-") else "normalUI")]


def result_validation(summary, tree, action, universe):
    expected_list = action["expectedIdentifiers"]
    require(expected_list and len(expected_list) == len(set(expected_list)), "Expected definitions are empty or duplicated")
    require(summary.get("result") == "Passed", "Native result did not pass")
    require(summary.get("passedTests", 0) > 0 and summary.get("totalTestCount", 0) > 0, "Zero tests is not success")
    require(not any(summary.get(k, 0) for k in ["failedTests", "skippedTests", "expectedFailures"]), "Failures, skips or expected failures are not acceptance")
    destination = action["destination"]
    actual = [v["device"] for v in summary["devicesAndConfigurations"]]
    require(actual and all(d["deviceId"] == destination["udid"] and d["osVersion"] == destination["runtimeVersion"] and d["modelName"] == destination["model"] for d in actual), "Actual destination/runtime differs from the matrix")
    canonical = lambda x: x[:-2] if x.endswith("()") else x
    known = {canonical(x): x for x in universe}
    require(len(known) == len(universe), "Native definition aliases are ambiguous")
    targets = {x.split("/", 1)[0] for x in universe}
    observed = {}

    def visit(node, target=None):
        if isinstance(node, list):
            for item in node:
                visit(item, target)
        elif isinstance(node, dict):
            if node.get("name") in targets:
                target = node["name"]
            identifier = node.get("nodeIdentifier", "")
            candidates = [identifier, f"{target}/{identifier}"] if target else [identifier]
            url = unquote(urlparse(node.get("nodeIdentifierURL", "")).path).split("/")
            if target in url:
                candidates.append("/".join(url[url.index(target):]))
            # Swift Testing Arguments nodes reuse their parent's URL with ?args=.
            # They are parameter cases, not repeated executions of the definition.
            arguments = node.get("nodeType") == "Arguments"
            if arguments:
                require(node.get("result") == "Passed", "A parameterized argument case did not pass")
            matches = set() if arguments else {known[canonical(candidate)] for candidate in candidates if canonical(candidate) in known}
            require(len(matches) <= 1, "A native result node resolves to multiple definitions")
            executable = node.get("nodeType") in {"Test Case", "Test Case Run", "Function", "Test Function"}
            containers = {"Test Plan", "Unit test bundle", "UI test bundle", "Test Suite", "Device", "Test Plan Configuration", "Repetition"}
            metadata = {"Arguments", "Failure Message", "Source Code Reference", "Attachment", "Expression", "Test Value", "Runtime Warning", "Skip Message", "Expected Failure"}
            require(executable or node.get("nodeType") in containers | metadata or not node.get("result"), "Unknown result-bearing native node type")
            if executable:
                require(matches, f"Executed definition is absent from fresh inventory: {identifier or node.get('name')}")
                require(node.get("result"), "Executed definition has no terminal result")
                identifier = next(iter(matches))
                require(identifier not in observed, f"Repeated native definition result: {identifier}")
                observed[identifier] = node["result"]
            visit(node.get("children", []), target)

    visit(tree["testNodes"])
    expected = set(expected_list)
    require(set(observed) == expected, f"Executed definitions differ: missing={sorted(expected - set(observed))}; extra={sorted(set(observed) - expected)}")
    require(all(v == "Passed" for v in observed.values()), "A selected definition did not pass")
    return {"executedDefinitionCount": len(observed), "actualDevices": actual, "allSelectedDefinitionsPassed": True}


def execute(args, config, devices, repository):
    require(args.resume is not None or args.output is not None, "--execute requires --output with a new run directory")
    output = (args.resume or args.output).resolve()
    require(not any(output.is_relative_to(repository / folder) for folder in ["numberConverter", "numberConverterTests", "numberConverterUITests", "ConversionEngine", "TestPlans", "Scripts", "numberConverter.xcodeproj", "numberConverter.xcworkspace"]), "Place artifacts outside the source input folders")
    freeze = source_hashes(repository)
    if args.resume:
        report = read_json(output / "report.json")
        require(report["sourceHashes"] == freeze and report["matrix"] == config, "Resume source/matrix differs; start a new run")
        require(device_identity(report["devices"]) == device_identity(devices), "Resume destination/runtime identity differs")
        require(report.get("productHashes"), "Run did not finish preparation; start a new output directory")
        require(product_hashes(output / "AllPlans.xctestproducts") == report["productHashes"], "Prepared products changed")
        require(digest(output / "native-inventory.json") == report["inventorySHA256"], "Prepared native inventory changed")
        proof = plan_proof(repository, output / "native-inventory.json", config)
        require(digest(output / "partition-proof.json") == report["partitionProofSHA256"], "Prepared partition proof changed")
        require([action_identity(a) for a in report["actions"]] == [action_identity(a) for a in actions(config, proof, devices)], "Resume action graph differs")
        require(all(a["status"] in {"not-run", "passed", "failed", "interrupted"} for a in report["actions"]), "Previous process is still running or has an invalid status")
        checkpoint = output / "resume-checkpoint-001.json"
        while checkpoint.exists():
            checkpoint = checkpoint.with_name(f"resume-checkpoint-{int(checkpoint.stem.rsplit('-', 1)[1]) + 1:03d}.json")
        write_json(checkpoint, report)
        report.update(complete=False, passed=False)
    else:
        require(not output.exists(), "Output already exists; results must never be overwritten")
        output.mkdir(parents=True)
        report = {"complete": False, "passed": False, "sourceHashes": freeze, "matrix": config, "devices": devices, "actions": []}
    write_json(output / "report.json", report)

    def space():
        require(shutil.disk_usage(output).free >= config["minimumFreeGiB"] * 1024 ** 3, "Free-space guard reached; remaining actions are NOT RUN")

    try:
        space()
        limits = config["timeoutsSeconds"]
        version = subprocess.check_output(["xcodebuild", "-version"], text=True, timeout=limits["resultRead"])
        require(not args.resume or version == report["xcodeVersion"], "Resume Xcode version differs")
        report["xcodeVersion"] = version
        products = output / "AllPlans.xctestproducts"
        host = devices[config["snapshotHost"]]
        build = ["xcodebuild", "-workspace", str(repository / config["workspace"]), "-scheme", config["scheme"], "-configuration", "Debug", "-destination", f"platform=iOS Simulator,id={host['udid']}", "-derivedDataPath", str(output / "DerivedData"), "-testProductsPath", str(products), "-disableAutomaticPackageResolution", "-parallel-testing-enabled", "NO", "-hideShellScriptEnvironment", "build-for-testing"]
        if not args.resume:
            report["build"] = logged(build, output / "build.log", limits["build"])
            require(report["build"]["exitCode"] == 0 and not report["build"]["timedOut"], "Build failed/timed out; no tests accepted")
            metadata = plistlib.loads((products / "Info.plist").read_bytes())
            require({x["Test Plan"] for x in metadata["Tests"]} == {"AllTests", *config["sharedPlans"], *config["uiPlans"]}, "Export must contain AllTests and all15 shards")
        inventory = output / "native-inventory.json"
        discovery = ["xcodebuild", "-testProductsPath", str(products), "-destination", f"platform=iOS Simulator,id={host['udid']}", "-enumerate-tests", "-test-enumeration-style", "flat", "-test-enumeration-format", "json", "-test-enumeration-output-path", str(inventory), "test-without-building"]
        if not args.resume:
            report["discovery"] = logged(discovery, output / "discovery.log", limits["discovery"])
            require(report["discovery"]["exitCode"] == 0 and not report["discovery"]["timedOut"], "Fresh native discovery failed/timed out")
            proof = plan_proof(repository, inventory, config)
            write_json(output / "partition-proof.json", proof)
            report["actions"] = [dict(a, status="not-run") for a in actions(config, proof, devices)]
            report.update(testProducts=str(products), productHashes=product_hashes(products), inventorySHA256=digest(inventory), partitionProofSHA256=digest(output / "partition-proof.json"))
            report["definitionDeviceExecutions"] = sum(len(a["expectedIdentifiers"]) for a in report["actions"])
        universe = {x for p in proof["plans"].values() for x in p["identifiers"]}
        if args.resume:
            for action in report["actions"]:
                if action["status"] == "passed":
                    require(action["exitCode"] == 0 and not action["timedOut"], "Previously accepted action had a failed process")
                    result = output / (action["key"] + ".xcresult")
                    summary = command_json(["xcrun", "xcresulttool", "get", "test-results", "summary", "--path", str(result), "--compact"], limits["resultRead"])
                    tree = command_json(["xcrun", "xcresulttool", "get", "test-results", "tests", "--path", str(result), "--compact"], limits["resultRead"])
                    result_validation(summary, tree, action, universe)
        for action in report["actions"]:
            if action["status"] != "not-run":
                continue
            space()
            require(source_hashes(repository) == freeze, "Source/resources changed during the run; remaining actions are NOT RUN")
            result = output / (action["key"] + ".xcresult")
            require(not any((output / (action["key"] + suffix)).exists() for suffix in [".xcresult", ".log", "-summary.json", "-tests.json"]), "Unrecorded action artifacts exist; refusing to overwrite them")
            command = ["xcodebuild", "-testProductsPath", str(products), "-testPlan", action["plan"], "-destination", f"platform=iOS Simulator,id={action['destination']['udid']}", "-parallel-testing-enabled", "NO", "-maximum-concurrent-test-simulator-destinations", "1", "-resultBundlePath", str(result), "test-without-building"]
            environment = os.environ.copy()
            if action["plan"] == "CloudSnapshots":
                environment["TEST_RUNNER_SNAPSHOT_REFERENCE_MODE"] = "bundled"
            action.update(status="running", command=command, resultBundle=str(result))
            write_json(output / "report.json", report)
            outcome = logged(command, output / (action["key"] + ".log"), action_timeout(config, action["plan"]), environment)
            action.update(**outcome, status="failed")
            try:
                summary = command_json(["xcrun", "xcresulttool", "get", "test-results", "summary", "--path", str(result), "--compact"], limits["resultRead"])
                tree = command_json(["xcrun", "xcresulttool", "get", "test-results", "tests", "--path", str(result), "--compact"], limits["resultRead"])
                write_json(output / (action["key"] + "-summary.json"), summary)
                write_json(output / (action["key"] + "-tests.json"), tree)
                require(outcome["exitCode"] == 0 and not outcome["timedOut"], "xcodebuild failed/timed out")
                action["validation"] = result_validation(summary, tree, action, universe)
                action["status"] = "passed"
            except (ValueError, KeyError, OSError, subprocess.SubprocessError) as error:
                action["failure"] = str(error)
            write_json(output / "report.json", report)
        require(source_hashes(repository) == freeze, "Source/resources changed during execution")
        report["complete"] = all(a["status"] not in {"not-run", "running", "interrupted"} for a in report["actions"])
        report["passed"] = all(a["status"] == "passed" for a in report["actions"])
    except (ValueError, KeyError, OSError, subprocess.SubprocessError, KeyboardInterrupt) as error:
        report["interruption"] = str(error) or type(error).__name__
        for action in report["actions"]:
            if action["status"] == "running":
                action["status"] = "interrupted"
    finally:
        write_json(output / "report.json", report)
    print(json.dumps({"complete": report["complete"], "passed": report["passed"], "report": str(output / "report.json")}, indent=2))
    return 0 if report["complete"] and report["passed"] else 1


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--execute", action="store_true", help="Build/enumerate/run ALL actions; only after all seven runtime leases are released")
    mode.add_argument("--resume", type=Path, metavar="OUTPUT", help="Revalidate a prepared run and execute only not-run actions; failed/interrupted actions stay failed")
    mode.add_argument("--dry-run", action="store_true", help="Read-only destination/partition validation; default mode")
    mode.add_argument("--validate-only", action="store_true", help="Read-only saved-native-inventory/configuration validation; no simulator access")
    parser.add_argument("--inventory", type=Path, help="Saved native flat AllTests+all15-plan JSON, required in read-only modes")
    parser.add_argument("--matrix", type=Path, default=ROOT / "TestPlans/local-device-matrix.json")
    parser.add_argument("--repository", type=Path, default=ROOT)
    parser.add_argument("--simulators-json", type=Path, help="Read a saved raw simctl list --json instead of contacting CoreSimulator (dry-run only)")
    parser.add_argument("--destination", action="append", default=[], metavar="KEY=UDID", help="Select an existing typed/runtime-matching simulator; never creates one")
    parser.add_argument("--output", type=Path, help="New artifact directory, required for --execute")
    args = parser.parse_args()
    try:
        require(not (args.resume and args.output), "--resume uses its existing output; do not also pass --output")
        repository = args.repository.resolve()
        config = configuration(args.matrix, repository)
        overrides = dict(x.split("=", 1) for x in args.destination)
        require(set(overrides) <= DEVICE_KEYS, "Unknown --destination device key")
        require(len(overrides) == len(args.destination), "Duplicate destination override")
        require(not any(os.environ.get(k) for k in ["SNAPSHOT_LAYER_CLOCK", "TEST_RUNNER_SNAPSHOT_LAYER_CLOCK"]), "Remove diagnostic snapshot clock overrides")
        running = args.execute or args.resume is not None
        if not running:
            require(args.inventory is not None, "Read-only modes require --inventory; they never discover tests")
            proof = plan_proof(repository, args.inventory, config)
            if args.validate_only:
                print(json.dumps({"mode": "validate-only", "nativeDefinitions": proof["testDefinitionCount"], "uiDefinitionsPerDevice": proof["countsByTarget"]["numberConverterUITests"], "devices": len(config["devices"]), "readOnly": True}, indent=2))
                return 0
        require(not running or args.simulators_json is None, "Execution must read actual native simulator metadata")
        metadata = read_json(args.simulators_json) if args.simulators_json else command_json(["xcrun", "simctl", "list", "--json"])
        devices, errors = resolve_devices(config, metadata, overrides)
        if running:
            require(not errors, "\n".join(errors))
            return execute(args, config, devices, repository)
        planned = actions(config, proof, devices)
        print(json.dumps({"mode": "dry-run", "readOnly": True, "ready": not errors, "errors": errors, "nativeDefinitions": proof["testDefinitionCount"], "uiDefinitionsPerDevice": proof["countsByTarget"]["numberConverterUITests"], "actionCount": len(planned), "definitionDeviceExecutions": sum(len(a["expectedIdentifiers"]) for a in planned), "actions": planned}, indent=2))
        return 0 if not errors else 2
    except (ValueError, KeyError, OSError, subprocess.SubprocessError) as error:
        print(f"Matrix validation failed: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
