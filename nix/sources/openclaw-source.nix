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
  rev = "a410b40c75fdfcd7ed62ac860885aa5280bb5fcc";
  hash = "sha256-P67DSJUi7r/0Fg435tE69Wyby9ZEY+Zhpnyx3oRoxtE=";
  pnpmDepsHash = {
    aarch64-darwin = "sha256-AzK5q+RGy0KI7pbRiJ6XbOigQ8OqmWQdSCwkPwf7VfE=";
    x86_64-linux = "sha256-PIGHF8m2MAH20FTIzzKbs13F4xoUPdFl9JBF+P22xTg=";
  };
}
