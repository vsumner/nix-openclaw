{
  lib,
  stdenvNoCC,
  jq,
  openclawPackage,
}:

lock:

let
  packageName = "openclaw-runtime-plugin-${
    lib.replaceStrings [ "@" "/" ":" ] [ "" "-" "-" ] lock.id
  }";
  pluginRoot = "${openclawPackage}/lib/openclaw/dist/extensions/${lock.id}";

  drv = stdenvNoCC.mkDerivation {
    pname = packageName;
    version = lock.version or "locked";

    dontUnpack = true;
    dontConfigure = true;
    dontBuild = true;

    nativeBuildInputs = [ jq ];

    installPhase = ''
      if [ ! -f "${pluginRoot}/openclaw.plugin.json" ]; then
        echo "OpenClaw gateway does not contain the ${lock.id} runtime plugin" >&2
        exit 1
      fi
      if [ "$(${jq}/bin/jq -r .id "${pluginRoot}/openclaw.plugin.json")" != "${lock.id}" ]; then
        echo "OpenClaw gateway runtime plugin manifest id does not match ${lock.id}" >&2
        exit 1
      fi
      if [ "$(${jq}/bin/jq -r .name "${pluginRoot}/package.json")" != "${lock.packageName}" ]; then
        echo "OpenClaw gateway runtime plugin package name does not match ${lock.packageName}" >&2
        exit 1
      fi
      if [ "$(${jq}/bin/jq -r .version "${pluginRoot}/package.json")" != "${lock.version}" ]; then
        echo "OpenClaw gateway runtime plugin version does not match ${lock.version}" >&2
        exit 1
      fi
      for runtime_entry in ${
        lib.escapeShellArgs (
          (lock.runtimeExtensions or [ ])
          ++ lib.optional ((lock.runtimeSetupEntry or null) != null) lock.runtimeSetupEntry
        )
      }; do
        if [ ! -f "${pluginRoot}/''${runtime_entry#./}" ]; then
          echo "OpenClaw gateway runtime plugin is missing $runtime_entry" >&2
          exit 1
        fi
      done

      mkdir -p "$out"
      for entry in "${pluginRoot}"/* "${pluginRoot}"/.[!.]* "${pluginRoot}"/..?*; do
        [ -e "$entry" ] || continue
        cp -R "$entry" "$out/$(basename "$entry")"
      done

      # Workspace plugins import the public OpenClaw plugin SDK as a peer.
      # Keep that peer explicit even when Node preserves the package symlink.
      mkdir -p "$out/node_modules"
      ln -s "${openclawPackage}/lib/openclaw" "$out/node_modules/openclaw"
    '';

    passthru.openclawRuntimePlugin = {
      inherit (lock) id;
      source = lock.selectedSource or "workspace";
      loadPath = drv;
    }
    // lib.optionalAttrs ((lock.packageName or null) != null) {
      packageName = lock.packageName;
    }
    // lib.optionalAttrs ((lock.version or null) != null) {
      version = lock.version;
    };

    meta = with lib; {
      description = "OpenClaw workspace runtime plugin ${lock.id}";
      homepage = "https://github.com/openclaw/openclaw";
      license = licenses.mit;
      platforms = platforms.darwin ++ platforms.linux;
    };
  };
in
assert lib.assertMsg ((lock.selectedSource or null) == "workspace")
  "OpenClaw workspace runtime plugin ${lock.id} has invalid selectedSource ${
    toString (lock.selectedSource or null)
  }";
assert lib.assertMsg (
  lock.workspacePath == "extensions/${lock.id}"
) "OpenClaw workspace runtime plugin ${lock.id} has invalid workspacePath ${lock.workspacePath}";
drv
