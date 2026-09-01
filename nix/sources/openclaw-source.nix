# Pinned OpenClaw source for nix-openclaw
{
  owner = "openclaw";
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
  rev = "0965053fe6b9341776df147a6934b7485c60b5ca";
  hash = "sha256-lSYGSyD3rt1YDyZ7d99V1080rMcLSu67skP54XuW1Cw=";
  pnpmDepsHash = {
    aarch64-darwin = "sha256-AzK5q+RGy0KI7pbRiJ6XbOigQ8OqmWQdSCwkPwf7VfE=";
    x86_64-linux = "sha256-PIGHF8m2MAH20FTIzzKbs13F4xoUPdFl9JBF+P22xTg=";
  };
}
