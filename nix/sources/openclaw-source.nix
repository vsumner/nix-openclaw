# Pinned OpenClaw source for nix-openclaw
{
  owner = "openclaw";
  repo = "openclaw";
  # pnpm 12's native fetcher emits relative tarball URLs inside Nix's Darwin
  # fixed-output sandbox. The committed v9 lock remains pnpm 11 compatible.
  pnpmMajor = "11";
  pnpmHostOnly = true;
  applyPublicSurfaceHardlinksPatch = false;
  applySkipPluginAutoEnableNixModePatch = false;
  applyNixStorePluginOwnershipPatch = true;
  releaseTag = "v2026.8.1";
  releaseVersion = "2026.8.1";
  runtimePluginVersion = "2026.8.1";
  # The gateway's Z.AI compatibility patch changes provider runtime behavior, so
  # export that plugin from this exact built workspace rather than the
  # unpatched npm tarball for the same release.
  workspaceRuntimePluginOverrides = [ "zai" ];
  rev = "0e0b89663f945324a9a9698a58ff8019fe78da8a";
  hash = "sha256-6Ve5C4bCWnHYtTFcxGxkti7chCa+2H2welXAzVOYlMg=";
  pnpmDepsHash = {
    aarch64-darwin = "sha256-HQo90xa8LCtuErfAXR6gBPL/pJCJtr8Uk2+Vih0YjrU=";
    x86_64-linux = "sha256-2frmMu4z+mSgJlBy4roqI8K+5sVZK12e7z4aHxQ1sM0=";
  };
}
