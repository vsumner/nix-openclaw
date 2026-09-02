# Pinned OpenClaw source for nix-openclaw
{
  # Temporary 2026.8.2 backport for openclaw/openclaw#136326. Return to the
  # upstream owner once a release contains openclaw/openclaw#136343.
  owner = "vsumner";
  repo = "openclaw";
  # pnpm 12's native fetcher emits relative tarball URLs inside Nix's Darwin
  # fixed-output sandbox. The committed v9 lock remains pnpm 11 compatible.
  pnpmMajor = "12";
  applyPublicSurfaceHardlinksPatch = false;
  pnpmHostOnly = true;
  applySkipPluginAutoEnableNixModePatch = false;
  applyNixStorePluginOwnershipPatch = true;
  # The gateway's Z.AI compatibility patch changes provider runtime behavior, so
  # export that plugin from this exact built workspace rather than the
  # unpatched npm tarball for the same release.
  workspaceRuntimePluginOverrides = [ "zai" ];
  releaseTag = "v2026.8.2";
  releaseVersion = "2026.8.2";
  runtimePluginVersion = "2026.8.2";
  rev = "683e20882caf73987776e9211099e25ac18fa421";
  hash = "sha256-V3pw06gXajL+u16VIgyepIvaE7xJ//so1Gg0g3M3epY=";
  pnpmDepsHash = {
    aarch64-darwin = "sha256-AzK5q+RGy0KI7pbRiJ6XbOigQ8OqmWQdSCwkPwf7VfE=";
    x86_64-linux = "sha256-PIGHF8m2MAH20FTIzzKbs13F4xoUPdFl9JBF+P22xTg=";
  };
}
