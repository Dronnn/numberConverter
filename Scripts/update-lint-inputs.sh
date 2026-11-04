#!/bin/sh
set -eu

cd "$(dirname "$0")/.."
{
    printf '%s\n' '$(SRCROOT)/.swiftformat' '$(SRCROOT)/.swiftlint.yml'
    find numberConverter numberConverterTests numberConverterUITests -type f -name '*.swift' -print |
        LC_ALL=C sort |
        while IFS= read -r task_lint_source; do
            printf '$(SRCROOT)/%s\n' "$task_lint_source"
        done
} > Scripts/LintInputs.xcfilelist
