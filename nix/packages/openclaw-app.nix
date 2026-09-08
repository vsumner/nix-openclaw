{
  lib,
  stdenvNoCC,
  fetchzip,
}:

stdenvNoCC.mkDerivation {
  pname = "openclaw-app";
  version = "2026.9.3";

  src = fetchzip {
    url = "https://github.com/openclaw/openclaw/releases/download/v2026.9.3/OpenClaw-2026.9.3.zip";
    hash = "sha256-L4M+3njnlFQiJdYfBpcRNL3kPcUCVTw+V5Z+H+k/ihc=";
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
