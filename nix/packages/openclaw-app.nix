{
  lib,
  stdenvNoCC,
  fetchzip,
}:

stdenvNoCC.mkDerivation {
  pname = "openclaw-app";
  version = "2026.8.2";

  src = fetchzip {
    url = "https://github.com/openclaw/openclaw/releases/download/v2026.8.2/OpenClaw-2026.8.2.zip";
    hash = "sha256-5TKmO6ZbzkGvxVqT6f9NtvOeoKJgpmEvYhdh2vrqxO4=";
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
