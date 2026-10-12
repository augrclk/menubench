#!/bin/zsh
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Arif Uğur Çelik

# Help and invalid options must exit before touching the build or signing tools.
set -euo pipefail
cd "$(dirname "$0")/.."
TEST_TMP="$(mktemp -d)"
trap 'rm -rf "$TEST_TMP"' EXIT
mkdir "$TEST_TMP/bin"
export MENUBENCH_TEST_TOOL_LOG="$TEST_TMP/tools.log"
for tool in security xcrun swiftc codesign; do
    cat > "$TEST_TMP/bin/$tool" <<'STUB'
#!/bin/sh
echo "$0" >> "$MENUBENCH_TEST_TOOL_LOG"
exit 99
STUB
    chmod +x "$TEST_TMP/bin/$tool"
done
export PATH="$TEST_TMP/bin:$PATH"

for option in --help -h; do
    ./build.sh "$option" > "$TEST_TMP/stdout" 2> "$TEST_TMP/stderr"
    grep -q '^Usage: ./build.sh' "$TEST_TMP/stdout"
    [[ ! -s "$TEST_TMP/stderr" ]]
done

for option in --dve --unknown; do
    status_code=0
    ./build.sh "$option" > "$TEST_TMP/stdout" 2> "$TEST_TMP/stderr" || status_code=$?
    [[ "$status_code" == 2 ]]
    grep -Fq -- "Unknown option: $option" "$TEST_TMP/stderr"
    [[ ! -s "$TEST_TMP/stdout" ]]
done

[[ ! -e "$MENUBENCH_TEST_TOOL_LOG" ]]
print 'PASS: help and invalid options exit without building or signing.'
