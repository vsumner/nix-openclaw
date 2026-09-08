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
  releaseTag = "v2026.9.3";
  releaseVersion = "2026.9.3";
  runtimePluginVersion = "2026.9.3";
  rev = "1391f7cd2d40ab5bbcf2f5f831d3a64f520e72d7";
  hash = "sha256-ZahFh0aNN3C/+IPFUXbnZOTymrsPy/LwbnVGPXcRSiw=";
  pnpmDepsHash = {
    aarch64-darwin = "sha256-iyRuJsWegwdvrfC6C6rlXO/OKxxFnmsAlLvLGVThR4k=";
    x86_64-linux = "sha256-/CgtESKVkdGgCrVCql1QzxRfJgQ/CDvR8Wch8Jt1Fhw=";
  };
}
