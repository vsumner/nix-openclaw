# Qualified owner authorization regression

Apply `nix/patches/preserve-qualified-owner-policy.patch` and then this directory's
`command-auth.test.patch` to a disposable checkout of the pinned OpenClaw source.
From that source root, with its locked dependencies, run:

```sh
pnpm exec vitest run src/auto-reply/command-auth.owner-default.test.ts --pool=forks --maxWorkers=1
```

Without the runtime patch, the two non-admin browser cases fail: filtering
channel-qualified owners removes the global owner-command restriction. With the
patch, browser admin scope still authorizes commands, channel-specific owners
remain authorized only on their channel, and empty/wildcard owner policies keep
their existing behavior. Both Discord and Telegram must be registered in the
channel matrix so prefixes are recognized exactly as they are in a multi-channel
host. The wildcard matrix uses Discord alone and includes Telegram and an
unregistered provider to prove policy detection does not depend on loaded plugins.

Keep the test patch separate from the runtime patch to avoid rebuilding the
gateway for test-only edits. Reevaluate the runtime patch when upgrading the
pinned source; remove it once upstream carries equivalent enforcement and proof.
