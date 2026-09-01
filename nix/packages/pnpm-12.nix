{
  lib,
  autoPatchelfHook,
  stdenv,
  stdenvNoCC,
  fetchurl,
  nodejs_22,
}:

let
  platformSource =
    {
      aarch64-darwin = {
        package = "exe.darwin-arm64";
        hash = "sha256-CebGU81Ooxu1OxAzdUKOXxfuMuHfqNS2An46lAFRD70=";
      };
      x86_64-linux = {
        package = "exe.linux-x64";
        hash = "sha256-LU1krEpBOWTzyXRW8u4jrjRv8pw8d9w2EdJE9ksW1AU=";
      };
    }
    .${stdenvNoCC.hostPlatform.system}
      or (throw "Unsupported pnpm 12 platform ${stdenvNoCC.hostPlatform.system}");
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "pnpm";
  version = "12.2.1";

  src = fetchurl {
    url = "https://registry.npmjs.org/@pnpm/${platformSource.package}/-/${platformSource.package}-${finalAttrs.version}.tgz";
    hash = platformSource.hash;
  };

  nativeBuildInputs = lib.optionals stdenvNoCC.hostPlatform.isLinux [ autoPatchelfHook ];
  buildInputs = lib.optionals stdenvNoCC.hostPlatform.isLinux [ stdenv.cc.cc.lib ];

  installPhase = ''
    runHook preInstall

    install -d $out/bin $out/libexec/pnpm
    cp pnpm $out/libexec/pnpm/pnpm
    chmod +x $out/libexec/pnpm/pnpm
    substitute ${../scripts/pnpm-exe-wrapper.sh} $out/bin/pnpm \
      --subst-var-by entrypoint $out/libexec/pnpm/pnpm
    substitute ${../scripts/pnpm-exe-wrapper.sh} $out/bin/pnpx \
      --subst-var-by entrypoint $out/libexec/pnpm/pnpm
    chmod +x $out/bin/pnpm $out/bin/pnpx

    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck

    tmp="$(mktemp -d)"
    mkdir -p "$tmp/home" "$tmp/project"
    printf '{"packageManager":"pnpm@12.99.99"}\n' > "$tmp/project/package.json"
    (
      cd "$tmp/project"
      version="$(HOME="$tmp/home" $out/bin/pnpm --version)"
      test "$version" = "${finalAttrs.version}"
    )
    rm -rf "$tmp"

    runHook postInstallCheck
  '';

  passthru = {
    majorVersion = lib.versions.major finalAttrs.version;
    nodejs = nodejs_22;
    "nodejs-slim" = nodejs_22;
  };

  meta = {
    description = "Fast, disk space efficient package manager for JavaScript";
    homepage = "https://pnpm.io/";
    changelog = "https://github.com/pnpm/pnpm/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
    mainProgram = "pnpm";
  };
})
