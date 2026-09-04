#!/usr/bin/env bash
set -euo pipefail

store_path="${1:?usage: normalize-pnpm-json-files.sh STORE_PATH}"

while IFS= read -r -d '' file; do
  if jq empty "$file" >/dev/null 2>&1; then
    normalized="$(mktemp "${file}.XXXXXX")"
    # Preserve insertion order: conditional exports are resolved in key order,
    # so sorting package.json can change which runtime entry Node selects.
    jq 'del(.. | .checkedAt?)' "$file" > "$normalized"
    mv "$normalized" "$file"
  else
    printf 'preserving non-JSON *.json payload: %s\n' "${file#"$store_path"/}" >&2
  fi
done < <(find "$store_path" -type f -name '*.json' -print0)
