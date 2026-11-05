#!/bin/sh

# Install the tools used by the app's read-only Lint & Format build phase.
# Engine tests run in their native Xcode Cloud Test action, not in this hook.
set -eu

if [ "${CI:-}" != "TRUE" ]; then
    printf '%s\n' 'error: This setup hook is intended for Xcode Cloud (CI=TRUE).' >&2
    exit 1
fi

export PATH="${PATH:-/usr/bin:/bin}:/opt/homebrew/bin:/usr/local/bin"

set --
for task_tool in swiftformat swiftlint; do
    if ! command -v "$task_tool" >/dev/null 2>&1; then
        set -- "$@" "$task_tool"
    fi
done

if [ "$#" -gt 0 ]; then
    if ! command -v brew >/dev/null 2>&1; then
        printf '%s\n' 'error: Homebrew is required to install the Cloud lint tools.' >&2
        exit 1
    fi

    export HOMEBREW_NO_ANALYTICS=1
    export HOMEBREW_NO_AUTO_UPDATE=1
    export HOMEBREW_NO_INSTALL_CLEANUP=1
    brew install --formula "$@"
fi

for task_tool in swiftformat swiftlint; do
    if ! command -v "$task_tool" >/dev/null 2>&1; then
        printf 'error: %s is still unavailable after Cloud setup.\n' "$task_tool" >&2
        exit 1
    fi
    "$task_tool" --version
done
