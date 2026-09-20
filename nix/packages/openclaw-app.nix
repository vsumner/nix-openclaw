{
  lib,
  stdenvNoCC,
  fetchzip,
}:

stdenvNoCC.mkDerivation {
  pname = "openclaw-app";
  version = "2026.9.5";

  src = fetchzip {
    url = "https://github.com/openclaw/openclaw/releases/download/v2026.9.5/OpenClaw-2026.9.5.zip";
    hash = "sha256-M0JvLpSWhdA4aKsZE5/XqN3ODUmbfSU2IUrca/g0fLI=";
    stripRoot = false;
  };

  dontUnpack = true;

  installPhase = "${../scripts/openclaw-app-install.sh}";

  meta = with lib; {
    description = "OpenClaw macOS app bundle";
    homepage = "https://github.com/openclaw/openclaw";
    license = licenses.mit;
    platforms = platforms.darwin;
  };
}
