# Nix plugin trust regression

Apply `manifest-registry.test.patch` to a disposable checkout of the pinned
OpenClaw source after applying `nix/patches/allow-nix-store-plugin-ownership.patch`.
Use that source's locked dependencies, then run from its root:

```sh
pnpm exec vitest run --config test/vitest/vitest.plugins.config.ts \
  src/plugins/manifest-registry.test.ts --pool=forks --maxWorkers=1
```

The fixture exercises the actual registry trust path with a parsed Codex
manifest. It checks catalog-matched Nix roots, ambiguous owners, non-store roots,
disabled Nix mode, and mismatched catalog IDs. Only filesystem manifest loading
is stubbed; catalog lookup, Nix-root policy, and trust resolution are real.

Keep this test-only patch separate from the runtime patch so test edits do not
recompile the gateway. Pair it with the `runtime-plugin-codex-gateway-smoke` Nix
check, which starts the built gateway with the actual immutable Codex package.
The fixture does not claim to test filesystem discovery; upstream's hardlink and
manifest-boundary tests cover that separately.
