# Pinned OpenClaw source for nix-openclaw
{
  owner = "openclaw";
  repo = "openclaw";
  # The fix is merged to main but missed the frozen 2026.9.1 release lineage.
  # Remove this backport once a release contains openclaw/openclaw#136343.
  backupManagedLinksPatch = {
    url = "https://github.com/openclaw/openclaw/commit/0aa9ae9f3e3ee94fbc3233f07b9653ef1402e7e5.patch";
    hash = "sha256-flTsbiybC7q3/5phv1ppg5nG2bGPHLgHcah8hSwrMBA=";
  };
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
  releaseTag = "v2026.9.1";
  releaseVersion = "2026.9.1";
  runtimePluginVersion = "2026.9.1";
  rev = "ad6fe23aecb9b833d68139b0ddc9f239b894d2f1";
  hash = "sha256-g7N+xotLQl0D+5vcBcAuNVyrPQNih9cDKJwwlC+4kBY=";
  pnpmDepsHash = {
    aarch64-darwin = "sha256-DYcRAOzYEy5ObEjletXUWFnamA0E6DOakt6ysQJzsCA=";
    x86_64-linux = "sha256-E/oZVbZXbHq8IEJdWWAqe7chJpDViHszRm2UfApcbnw=";
  };
}
