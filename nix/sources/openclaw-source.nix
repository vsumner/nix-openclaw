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
  workspaceRuntimePluginOverrides = [
    "llama-cpp"
    "zai"
  ];
  releaseTag = "v2026.9.6";
  releaseVersion = "2026.9.6";
  runtimePluginVersion = "2026.9.6";
  rev = "eb377ac59e6c9fd6c7705028034812becf00271b";
  hash = "sha256-IKshrMAfgpY756WHZpEgm6tbKbPro4ejnpo2696LPdc=";
  pnpmDepsHash = {
    aarch64-darwin = "sha256-l+CJ8j4Ip7AP5abBR+YxTgDZSiysZqYtcOD9Kj7jvK4=";
    x86_64-linux = "sha256-UWVSaltblerLnTxHDZzhz+QAKRCIZmTZAAWOYI7E2GI=";
  };
}
