{
  lib,
  stdenv,
  fetchFromGitHub,
  fetchurl,
  nodejs_24,
  pnpm_10,
  pnpm_11,
  pnpm_12,
  fetchPnpmDeps,
  pkg-config,
  jq,
  python3,
  node-gyp,
  git,
  sqlite,
  zstd,
}:

# Shared build plumbing for OpenClaw gateway-related derivations.
#
# Goals:
# - one source of truth for pnpm deps fetch + common env
# - keep the individual derivations small/boring

{
  pname,
  sourceInfo,
  pnpmDepsPname ? "openclaw-gateway",
  gatewaySrc ? null,
  src ? null,
  enableSharp ? false,
  extraNativeBuildInputs ? [ ],
  extraBuildInputs ? [ ],
  extraEnv ? { },
  pnpmDepsHash ? (sourceInfo.pnpmDepsHash or null),
  packageVersion ? null,
}:

let
  sourceFetch = lib.removeAttrs sourceInfo [
    "pnpmDepsHash"
    "gatewayNpmDepsHash"
    "pnpmMajor"
    "pnpmHostOnly"
    "releaseTag"
    "releaseVersion"
    "runtimePluginVersion"
    "workspaceRuntimePluginOverrides"
    "applyPublicSurfaceHardlinksPatch"
    "applySkipPluginAutoEnableNixModePatch"
    "applyNixStorePluginOwnershipPatch"
    "publicSurfaceHardlinksPatch"
    "fsSafeSource"
  ];

  # Prefer nixpkgs' platform mapping instead of hand-rolled arch/platform.
  pnpmPlatform = stdenv.hostPlatform.node.platform;
  pnpmArch = stdenv.hostPlatform.node.arch;

  revShort = lib.substring 0 8 sourceInfo.rev;
  version = if packageVersion != null then packageVersion else "unstable-${revShort}";

  resolvedSrc =
    if src != null then
      src
    else if gatewaySrc != null then
      gatewaySrc
    else
      fetchFromGitHub sourceFetch;

  fsSafeSource = if sourceInfo ? fsSafeSource then fetchFromGitHub sourceInfo.fsSafeSource else null;
  publicSurfaceHardlinksPatch =
    sourceInfo.publicSurfaceHardlinksPatch or ../patches/allow-package-public-surface-hardlinks.patch;

  nodeAddonApi = import ../packages/node-addon-api.nix { inherit stdenv fetchurl; };
  matrixSdkCryptoVersion = "0.6.6";
  matrixSdkCryptoSource =
    {
      aarch64-darwin = {
        file = "matrix-sdk-crypto.darwin-arm64.node";
        hash = "sha256-mdx9kKqDDZttlrzaI1ic4Pty0Q+E7ER8nSQZN/7obZ8=";
      };
      x86_64-linux = {
        file = "matrix-sdk-crypto.linux-x64-gnu.node";
        hash = "sha256-rrIQKaxrspzQZJP2exmlp1s9A3Ghq0Uv5Z94JJNQ8Pc=";
      };
    }
    .${stdenv.hostPlatform.system}
      or (throw "Unsupported Matrix SDK crypto platform ${stdenv.hostPlatform.system}");
  matrixSdkCryptoBinary = fetchurl {
    url = "https://github.com/matrix-org/matrix-rust-sdk-crypto-nodejs/releases/download/v${matrixSdkCryptoVersion}/${matrixSdkCryptoSource.file}";
    hash = matrixSdkCryptoSource.hash;
  };
  pnpmMajor = toString (sourceInfo.pnpmMajor or "10");
  pnpmByMajor = {
    "10" = pnpm_10;
    "11" = pnpm_11;
    "12" = pnpm_12;
  };
  selectedPnpm = pnpmByMajor.${pnpmMajor} or (throw "Unsupported OpenClaw pnpm major ${pnpmMajor}");
  pnpmNeedsVerifiedStore = lib.elem pnpmMajor [
    "11"
    "12"
  ];
  pnpmHostOnly = sourceInfo.pnpmHostOnly or false;
  resolvedPnpmDepsHash =
    if builtins.isAttrs pnpmDepsHash then
      pnpmDepsHash.${stdenv.hostPlatform.system} or null
    else
      pnpmDepsHash;

  pnpmDeps = fetchPnpmDeps {
    pname = pnpmDepsPname;
    inherit version;
    src = resolvedSrc;
    pnpm = selectedPnpm;
    # fetchPnpmDeps normally inherits this impure variable. pnpm 11 tolerates
    # the resulting empty --registry value, but pnpm 12 can wait indefinitely.
    prePnpmInstall = ''
      export NIX_NPM_REGISTRY=https://registry.npmjs.org
    '';
    hash = if resolvedPnpmDepsHash != null then resolvedPnpmDepsHash else lib.fakeHash;
    fetcherVersion = if pnpmNeedsVerifiedStore then 4 else 3;
    pnpmInstallFlags = lib.optional pnpmHostOnly "--no-force";
    preFixup = lib.optionalString pnpmNeedsVerifiedStore ''
      ${lib.optionalString (!pnpmHostOnly) ''
        expectedIntegrities="$(mktemp)"
        actualIntegrities="$(mktemp)"
        missingIntegrities="$(mktemp)"
        expectedPackages="$(mktemp)"
        yq -r '.packages | to_entries[] | select(.value.resolution.integrity) | [.key, .value.resolution.integrity] | @tsv' pnpm-lock.yaml > "$expectedPackages"
        cut -f2 "$expectedPackages" | sort -u > "$expectedIntegrities"
        ${nodejs_24}/bin/node --no-warnings ${../scripts/list-pnpm-store-integrities.js} "$storePath" | sort -u > "$actualIntegrities"
        comm -23 "$expectedIntegrities" "$actualIntegrities" > "$missingIntegrities"
        if [ -s "$missingIntegrities" ]; then
          echo "ERROR: pnpm store is missing package tarballs from pnpm-lock.yaml:" >&2
          grep -F -f "$missingIntegrities" "$expectedPackages" >&2
          exit 1
        fi
      ''}

      ${nodejs_24}/bin/node --no-warnings ${../scripts/normalize-pnpm-store-index.js} "$storePath"
    '';
    postInstall = lib.optionalString pnpmNeedsVerifiedStore ''
      verifiedCache="$(find "$HOME" -path '*/lockfile-verified.jsonl' -type f -print -quit)"
      if [ -n "$verifiedCache" ]; then
        jq -c '
          .lockfile.path = ""
          | .lockfile.size = -1
          | .lockfile.mtimeNs = ""
          | .lockfile.inode = ""
          | .verifiedAt = "1970-01-01T00:00:01.000Z"
        ' "$verifiedCache" | LC_ALL=C sort -u > "$out/pnpm-lockfile-verified.jsonl"
      fi

      metadataRoot="$(find "$HOME" -path '*/metadata/registry.npmjs.org' -type d -print -quit)"
      fullMetadataRoot="$(find "$HOME" -path '*/metadata-full/registry.npmjs.org' -type d -print -quit)"
      if [ -n "$metadataRoot" ] || [ -n "$fullMetadataRoot" ]; then
        lockKeys="$(mktemp)"
        yq -r '.packages | keys[]' pnpm-lock.yaml > "$lockKeys"
        # Seed every locked package from the abbreviated cache, then overwrite
        # with full metadata where pnpm fetched publication-time evidence.
        if [ -n "$metadataRoot" ]; then
          ${nodejs_24}/bin/node --no-warnings \
            ${../scripts/normalize-pnpm-metadata.mjs} \
            "$metadataRoot" "$lockKeys" "$out/pnpm-metadata/registry.npmjs.org"
        fi
        if [ -n "$fullMetadataRoot" ]; then
          ${nodejs_24}/bin/node --no-warnings \
            ${../scripts/normalize-pnpm-metadata.mjs} \
            "$fullMetadataRoot" "$lockKeys" "$out/pnpm-metadata/registry.npmjs.org"
        fi
        # pnpm's policy verifier does not persist every full packument it
        # checks. Hydrate only timestamp-free locked records from the registry;
        # the fixed-output hash pins the exact resulting evidence.
        ${nodejs_24}/bin/node --no-warnings \
          ${../scripts/normalize-pnpm-metadata.mjs} \
          --hydrate-missing-times "$out/pnpm-metadata/registry.npmjs.org" "$lockKeys"
      fi
    '';
    npm_config_arch = pnpmArch;
    npm_config_platform = pnpmPlatform;
    nativeBuildInputs = [
      git
      nodejs_24
    ];
  };

  envBase = {
    npm_config_arch = pnpmArch;
    npm_config_platform = pnpmPlatform;
    PNPM_CONFIG_MANAGE_PACKAGE_MANAGER_VERSIONS = "false";
    npm_config_nodedir = nodejs_24;
    npm_config_python = python3;
    NODE_PATH = "${nodeAddonApi}/lib/node_modules:${node-gyp}/lib/node_modules";
    PNPM_DEPS = pnpmDeps;
    # pnpm 12's native CLI resolves and installs correctly but can deadlock in
    # `rebuild` without spawning lifecycle children. The pnpm 11 JavaScript CLI
    # replays those scripts against the same lockfile/store layout reliably.
    PNPM_REBUILD = if pnpmMajor == "12" then "${pnpm_11}/bin/pnpm" else "${selectedPnpm}/bin/pnpm";
    MATRIX_SDK_CRYPTO_BINARY = matrixSdkCryptoBinary;
    MATRIX_SDK_CRYPTO_BINARY_NAME = matrixSdkCryptoSource.file;
    MATRIX_SDK_CRYPTO_VERSION = matrixSdkCryptoVersion;
    OPENCLAW_BUILD_ROOT_SH = "${../scripts/build-root.sh}";
    NODE_GYP_WRAPPER_SH = "${../scripts/node-gyp-wrapper.sh}";
    GATEWAY_PREBUILD_SH = "${../scripts/gateway-prebuild.sh}";
    PATCH_BUNDLED_RUNTIME_DEPS_SCRIPT = "${../patches/stage-bundled-plugin-runtime-deps.mjs}";
    PATCH_PUBLIC_SURFACE_HARDLINKS =
      if sourceInfo.applyPublicSurfaceHardlinksPatch or true then
        "${publicSurfaceHardlinksPatch}"
      else
        "";
    PATCH_SKIP_PLUGIN_AUTO_ENABLE_NIX_MODE =
      if sourceInfo.applySkipPluginAutoEnableNixModePatch or true then
        "${../patches/skip-plugin-auto-enable-persist-in-nix-mode.patch}"
      else
        "";
    PATCH_NIX_STORE_PLUGIN_OWNERSHIP =
      if sourceInfo.applyNixStorePluginOwnershipPatch or false then
        "${../patches/allow-nix-store-plugin-ownership.patch}"
      else
        "";
    PATCH_BEFORE_MESSAGE_WRITE_RUN_ID = "${../patches/forward-before-message-write-run-id.patch}";
    PATCH_ZAI_CODING_PLAN_SYSTEM_PROMPT = "${../patches/fix-zai-coding-plan-system-prompt.patch}";
    PROMOTE_PNPM_INTEGRITY_SH = "${../scripts/promote-pnpm-integrity.sh}";
    REMOVE_PACKAGE_MANAGER_FIELD_SH = "${../scripts/remove-package-manager-field.sh}";
    STDENV_SETUP = "${stdenv}/setup";
  }
  // lib.optionalAttrs (fsSafeSource != null) {
    OPENCLAW_FS_SAFE_SOURCE = fsSafeSource;
  };

in
{
  inherit
    version
    pnpmDeps
    pnpmMajor
    resolvedSrc
    pnpmPlatform
    pnpmArch
    pnpmHostOnly
    nodeAddonApi
    selectedPnpm
    ;

  nativeBuildInputs = [
    nodejs_24
    selectedPnpm
    pkg-config
    jq
    python3
    node-gyp
    sqlite
    zstd
  ]
  ++ extraNativeBuildInputs;

  buildInputs = extraBuildInputs;

  env = envBase // (lib.optionalAttrs enableSharp { SHARP_IGNORE_GLOBAL_LIBVIPS = "1"; }) // extraEnv;

  passthru = {
    inherit
      sourceInfo
      pnpmDeps
      pnpmMajor
      selectedPnpm
      ;
    pinnedRev = sourceInfo.rev;
  };
}
