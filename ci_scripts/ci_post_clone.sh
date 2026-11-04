#!/bin/sh

# run the complete dependency-free engine suite in the selected cloud toolchain.
# keep its exit status intact: a failing test must fail the cloud action.
set -eu

: "${CI_PRIMARY_REPOSITORY_PATH:?Xcode Cloud must provide the cloned repository path}"
: "${CI_DERIVED_DATA_PATH:?Xcode Cloud must provide the derived-data path}"

task_engine_package="$CI_PRIMARY_REPOSITORY_PATH/ConversionEngine"
task_engine_scratch="$CI_DERIVED_DATA_PATH/ConversionEngineCloudTests"

if [ ! -f "$task_engine_package/Package.swift" ]; then
    printf '%s\n' 'error: ConversionEngine/Package.swift is missing from the cloud checkout.' >&2
    exit 1
fi

printf '%s\n' 'Running every ConversionEngine SwiftPM test with code coverage.'
xcrun swift test \
    --package-path "$task_engine_package" \
    --scratch-path "$task_engine_scratch" \
    --enable-code-coverage

task_engine_coverage=$(xcrun swift test \
    --package-path "$task_engine_package" \
    --scratch-path "$task_engine_scratch" \
    --enable-code-coverage \
    --show-codecov-path)

if [ ! -s "$task_engine_coverage" ]; then
    printf '%s\n' 'error: SwiftPM did not generate the engine coverage report.' >&2
    exit 1
fi

printf '%s\n' 'Every ConversionEngine SwiftPM test passed.'
printf 'Engine coverage JSON in this temporary build environment: %s\n' "$task_engine_coverage"
