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
  releaseTag = "v2026.9.4";
  releaseVersion = "2026.9.4";
  runtimePluginVersion = "2026.9.4";
  rev = "3a9d69db306cd7f081e06254cb89c4bcc14a7107";
  hash = "sha256-xeUf0Emyhen4hnxjhbTI59d02QfB3YWTxhlqNkKuiUA=";
  pnpmDepsHash = {
    aarch64-darwin = "sha256-iyRuJsWegwdvrfC6C6rlXO/OKxxFnmsAlLvLGVThR4k=";
    x86_64-linux = "sha256-tvNBaUJr6ibPR0OJxU7ArL6kC7UgFqIyQFeEI2M6vEk=";
  };
}
