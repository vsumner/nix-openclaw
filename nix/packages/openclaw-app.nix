{
  lib,
  stdenvNoCC,
  fetchzip,
}:

stdenvNoCC.mkDerivation {
  pname = "openclaw-app";
  version = "2026.9.6";

  src = fetchzip {
    url = "https://github.com/openclaw/openclaw/releases/download/v2026.9.6/OpenClaw-2026.9.6.zip";
    hash = "sha256-YpJ+Hx3oGnc33u7qTLiKtO+X8xjS0KA0U5YSjiyy4Rw=";
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
