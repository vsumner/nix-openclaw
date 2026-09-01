#!/bin/sh
set -eu

script="${OPENCLAW_WORKSPACE_MATERIALIZER:?OPENCLAW_WORKSPACE_MATERIALIZER is required}"

work="$(mktemp -d)"
stale="$work/workspace/skills/stale"
current="$work/workspace/AGENTS.md"

mkdir -p "$stale" "$work/src"
printf 'stale\n' > "$stale/SKILL.md"
printf 'old-doc\n' > "$current"
printf '%s\n%s\n' "$stale" "$current" > "$work/manifest"
printf 'new-doc\n' > "$work/src/AGENTS.md"
printf '%s\t%s\n' "$work/src/AGENTS.md" "$current" > "$work/source.tsv"

"$script" "$work/manifest" "$work/source.tsv"

test ! -e "$stale"
test -f "$current"
grep -q 'new-doc' "$current"
grep -Fxq "$current" "$work/manifest"
! grep -Fxq "$stale" "$work/manifest"

empty_work="$(mktemp -d)"
empty_stale="$empty_work/workspace/skills/stale"

mkdir -p "$empty_stale"
printf 'stale\n' > "$empty_stale/SKILL.md"
printf '%s\n' "$empty_stale" > "$empty_work/manifest"
: > "$empty_work/source.tsv"

"$script" "$empty_work/manifest" "$empty_work/source.tsv"

test ! -e "$empty_stale"
test ! -s "$empty_work/manifest"

skill_work="$(mktemp -d)"
skill_source="$skill_work/store-backed-skill"
skill_target="$skill_work/materialized/skill"

mkdir -p "$skill_source"
printf '%s\n' '# skill' > "$skill_source/SKILL.md"
ln "$skill_source/SKILL.md" "$skill_source/hardlinked.md"
ln -s SKILL.md "$skill_source/symlinked.md"
printf '%s\t%s\n' "$skill_source" "$skill_target" > "$skill_work/source.tsv"

"$script" "$skill_work/manifest" "$skill_work/source.tsv"

test -f "$skill_target/SKILL.md"
test ! -L "$skill_target/symlinked.md"
test "$(stat -c %h "$skill_target/SKILL.md")" -eq 1
test "$(stat -c %h "$skill_target/hardlinked.md")" -eq 1
