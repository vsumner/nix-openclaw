#!/bin/sh
set -eu

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
fixture_root="$(mktemp -d)"
trap 'rm -rf "$fixture_root"' EXIT

esbuild="$fixture_root/node_modules/.pnpm/pkg/node_modules/@esbuild/linux-x64/bin/esbuild"
tsgo="$fixture_root/node_modules/.pnpm/pkg/node_modules/@typescript/native-preview-linux-x64/lib/tsgo"
tsc="$fixture_root/node_modules/.pnpm/pkg/node_modules/@typescript/typescript-linux-x64/lib/tsc"
unrelated="$fixture_root/node_modules/.pnpm/pkg/node_modules/example/bin/example"
mkdir -p "$(dirname "$esbuild")" "$(dirname "$tsgo")" "$(dirname "$tsc")" "$(dirname "$unrelated")"
touch "$esbuild" "$tsgo" "$tsc" "$unrelated"
chmod 0644 "$esbuild" "$tsgo" "$tsc" "$unrelated"

"$script_dir/restore-pnpm-executables.sh" "$fixture_root/node_modules/.pnpm"

test -x "$esbuild"
test -x "$tsgo"
test -x "$tsc"
test ! -x "$unrelated"
