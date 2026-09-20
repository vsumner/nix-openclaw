# Pinned OpenClaw source for nix-openclaw
{
  owner = "openclaw";
  repo = "openclaw";
  # pnpm 12's native fetcher emits relative tarball URLs inside Nix's Darwin
  # fixed-output sandbox. The committed v9 lock remains pnpm 11 compatible.
  pnpmMajor = "12";
  applyPublicSurfaceHardlinksPatch = false;
  # Remove these once the pinned upstream release preserves manifest-declared
  # Control UI payloads in dist-runtime and accepts immutable Nix-store assets.
  applyControlUiRuntimeAssetsPatch = true;
  applyControlUiNixHardlinksPatch = true;
  pnpmHostOnly = true;
  applySkipPluginAutoEnableNixModePatch = false;
  applyNixStorePluginOwnershipPatch = true;
  # The gateway's Z.AI compatibility patch changes provider runtime behavior, so
  # export that plugin from this exact built workspace rather than the
  # unpatched npm tarball for the same release.
  workspaceRuntimePluginOverrides = [ "zai" ];
  releaseTag = "v2026.9.5";
  releaseVersion = "2026.9.5";
  runtimePluginVersion = "2026.9.5";
  rev = "ec9c1a13db8938e5a3eaa51fca2e981cde2395a9";
  hash = "sha256-M0nfeZDy6MafWCfqefwDRdL1MFLs8l1YZJmB6sV9IyU=";
  pnpmDepsHash = {
    aarch64-darwin = "sha256-b/Gi7e3qfa1EvBj8SOETJfRpJh+UNketrvfBTPOy3Cs=";
    x86_64-linux = "sha256-9lidd5x6cFhEgtoYBy1qEukH6tAZEAQDgc35pz252do=";
  };
}
