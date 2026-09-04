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
  packagedPluginRoot = "lib/openclaw/dist/extensions/${lock.id}";

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

      # Keep the plugin at its compiled workspace depth. Generated extension
      # modules import shared gateway chunks through ../../<chunk>.js, so
      # flattening the plugin root changes module resolution even when its
      # public entry point still imports successfully.
      mkdir -p "$out/lib/openclaw/dist/extensions"
      cp -R "${pluginRoot}" "$out/${packagedPluginRoot}"
      chmod -R u+w "$out/${packagedPluginRoot}"

      # pnpm leaves workspace-only links in compiled extension trees. They are
      # build conveniences, not runtime dependencies: plugin SDK imports use
      # the explicit `openclaw` peer below, while `.bin` is never loaded at
      # runtime. Remove only symlinks so a future real directory is preserved.
      for build_only_link in \
        "$out/${packagedPluginRoot}/node_modules/.bin" \
        "$out/${packagedPluginRoot}/node_modules/@openclaw/plugin-sdk"; do
        if [ -L "$build_only_link" ]; then
          rm "$build_only_link"
        fi
      done

      # Preserve the shared compiled runtime addressed by those relative
      # imports. Copying the complete dist tree also keeps later generated
      # chunk edges correct without guessing a transitive file closure.
      for entry in "${openclawPackage}/lib/openclaw/dist"/*; do
        [ "$(basename "$entry")" = extensions ] && continue
        cp -R "$entry" "$out/lib/openclaw/dist/$(basename "$entry")"
      done

      # Package metadata and runtime assets are discovered by walking upward
      # from shared dist chunks. Retain that package-root contract too.
      for entry in "${openclawPackage}/lib/openclaw"/*; do
        case "$(basename "$entry")" in
          dist|node_modules) continue ;;
        esac
        ln -s "$entry" "$out/lib/openclaw/$(basename "$entry")"
      done

      # Workspace plugins import the public OpenClaw plugin SDK as a peer.
      # Keep that peer explicit even when Node preserves the package symlink.
      mkdir -p "$out/${packagedPluginRoot}/node_modules"
      ln -s "${openclawPackage}/lib/openclaw" "$out/${packagedPluginRoot}/node_modules/openclaw"

      # Shared gateway chunks resolve their third-party dependencies from the
      # gateway package root, not from the nested extension directory.
      ln -s "${openclawPackage}/lib/openclaw/node_modules" "$out/lib/openclaw/node_modules"
    '';

    passthru.openclawRuntimePlugin = {
      inherit (lock) id;
      source = lock.selectedSource or "workspace";
      loadPath = "${drv}/${packagedPluginRoot}";
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
