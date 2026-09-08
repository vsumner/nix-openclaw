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
  releaseTag = "v2026.9.2";
  releaseVersion = "2026.9.2";
  runtimePluginVersion = "2026.9.2";
  rev = "3928bad9badfcb6c7d140530435e806fb8092190";
  hash = "sha256-VRY5aJDmctoblL9hPb//Y3H1+1zWoKa0sbApdHu4saY=";
  pnpmDepsHash = {
    aarch64-darwin = "sha256-iyRuJsWegwdvrfC6C6rlXO/OKxxFnmsAlLvLGVThR4k=";
    x86_64-linux = "sha256-qzFwVe/T1xgOFwuHHkY6yVokgn/1kGkN89EqYDxevKE=";
  };
}
