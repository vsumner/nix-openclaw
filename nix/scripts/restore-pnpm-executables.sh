#!/bin/sh
set -eu

virtual_store="${1:?usage: restore-pnpm-executables.sh PNPM_VIRTUAL_STORE}"

find "$virtual_store" -type f \( \
  -path '*/node_modules/@esbuild/*/bin/esbuild' -o \
  -path '*/node_modules/@typescript/native-preview-*/lib/tsgo' \
  \) -exec chmod u+x {} +
