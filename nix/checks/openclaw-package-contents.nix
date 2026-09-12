{
  lib,
  stdenv,
  nodejs_22,
  openclawGateway,
}:

stdenv.mkDerivation {
  pname = "openclaw-package-contents";
  version = lib.getVersion openclawGateway;

  dontUnpack = true;
  dontConfigure = true;
  dontBuild = true;

  env = {
    OPENCLAW_GATEWAY = openclawGateway;
    WORKBOARD_CONTROL_UI_CHECK = "${../scripts/check-workboard-control-ui-assets.mjs}";
  };

  doCheck = true;
  nativeCheckInputs = [ nodejs_22 ];
  checkPhase = "${../scripts/check-package-contents.sh}";
  installPhase = "${../scripts/empty-install.sh}";
}
