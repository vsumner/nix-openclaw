#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fixture_root="$(mktemp -d)"
trap 'rm -rf "$fixture_root"' EXIT

mkdir -p "$fixture_root/a directory"
printf '%s\n' '{"z":1,"checkedAt":99,"nested":{"checkedAt":42,"a":2}}' > "$fixture_root/a directory/valid.json"
printf '%s\n' '{"exports":{"node":{"import":"./node.js"},"default":{"import":"./default.js"}},"checkedAt":1}' > "$fixture_root/a directory/package.json"
printf '%s\n' '// JSON5 fixture' '{answer: 42}' > "$fixture_root/a directory/fixture.json"

"$script_dir/normalize-pnpm-json-files.sh" "$fixture_root"

test "$(jq -c . "$fixture_root/a directory/valid.json")" = '{"z":1,"nested":{"a":2}}'
test "$(jq -c . "$fixture_root/a directory/package.json")" = '{"exports":{"node":{"import":"./node.js"},"default":{"import":"./default.js"}}}'
test "$(sed -n '1p' "$fixture_root/a directory/fixture.json")" = '// JSON5 fixture'
test "$(sed -n '2p' "$fixture_root/a directory/fixture.json")" = '{answer: 42}'
