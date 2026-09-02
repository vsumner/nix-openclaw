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
  rev = "9919a01de61e0d279b9ca449aee2ff9b316effc3";
  hash = "sha256-S3BOyP78CiVwE5PURR3QH2zw1XD1BJgo1ZSmNVSE3Uo=";
  pnpmDepsHash = {
    aarch64-darwin = "sha256-AzK5q+RGy0KI7pbRiJ6XbOigQ8OqmWQdSCwkPwf7VfE=";
    x86_64-linux = "sha256-PIGHF8m2MAH20FTIzzKbs13F4xoUPdFl9JBF+P22xTg=";
  };
}
