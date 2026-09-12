import fs from "node:fs";
import path from "node:path";

const MAX_ASSETS = 128;
const MAX_DEPTH = 8;
const MAX_ASSET_BYTES = 4 * 1024 * 1024;
const MAX_BUILD_BYTES = 8 * 1024 * 1024;
const ASSET_PATH = /^(?:[\w-][\w.-]*\/)*[\w-][\w.-]*\.(?:m?js|css)$/u;

function requireInside(rootDir, relativePath, label) {
  const rootStat = fs.lstatSync(rootDir);
  if (rootStat.isSymbolicLink() || !rootStat.isDirectory()) {
    throw new Error(`Workboard Control UI ${label} plugin root is not a regular directory`);
  }
  const absolutePath = path.resolve(rootDir, relativePath);
  if (!absolutePath.startsWith(`${rootDir}${path.sep}`)) {
    throw new Error(`Workboard Control UI ${label} escapes plugin root: ${relativePath}`);
  }
  let ancestor = rootDir;
  for (const segment of path.relative(rootDir, absolutePath).split(path.sep)) {
    if (!segment) {
      continue;
    }
    ancestor = path.join(ancestor, segment);
    const ancestorStat = fs.lstatSync(ancestor);
    if (ancestorStat.isSymbolicLink() || !ancestorStat.isDirectory()) {
      throw new Error(`Workboard Control UI ${label} directory has an unsafe ancestor`);
    }
  }
  return absolutePath;
}

function listBrowserAssets(pluginRoot, directory, label) {
  const assetRoot = requireInside(pluginRoot, directory, "directory");
  if (!fs.lstatSync(assetRoot).isDirectory()) {
    throw new Error(`Workboard Control UI ${label} directory is not a directory`);
  }

  const assets = new Map();
  let entries = 0;
  let bytes = 0;
  function visit(currentDir, depth) {
    for (const dirent of fs.readdirSync(currentDir, { withFileTypes: true })) {
      entries += 1;
      if (entries > MAX_ASSETS) {
        throw new Error(`Workboard Control UI ${label} exceeds ${MAX_ASSETS} entries`);
      }
      const absolutePath = path.join(currentDir, dirent.name);
      const relativePath = path.relative(assetRoot, absolutePath).replaceAll(path.sep, "/");
      if (dirent.isSymbolicLink()) {
        throw new Error(`Workboard Control UI ${label} asset is not a regular file: ${relativePath}`);
      }
      if (dirent.isDirectory()) {
        if (depth >= MAX_DEPTH) {
          throw new Error(`Workboard Control UI ${label} exceeds depth ${MAX_DEPTH}`);
        }
        visit(absolutePath, depth + 1);
        continue;
      }
      if (!ASSET_PATH.test(relativePath)) {
        continue;
      }
      const stat = fs.lstatSync(absolutePath);
      if (!dirent.isFile() || stat.isSymbolicLink()) {
        throw new Error(`Workboard Control UI ${label} asset is not a regular file: ${relativePath}`);
      }
      if (stat.size > MAX_ASSET_BYTES) {
        throw new Error(`Workboard Control UI ${label} asset exceeds ${MAX_ASSET_BYTES} bytes`);
      }
      bytes += stat.size;
      if (bytes > MAX_BUILD_BYTES) {
        throw new Error(`Workboard Control UI ${label} exceeds ${MAX_BUILD_BYTES} bytes`);
      }
      assets.set(relativePath, absolutePath);
    }
  }
  visit(assetRoot, 0);
  return assets;
}

function assertSameAssetSet(sourceAssets, runtimeAssets) {
  if (sourceAssets.size !== runtimeAssets.size) {
    throw new Error("Workboard Control UI runtime asset set differs from source");
  }
  for (const [relativePath, sourcePath] of sourceAssets) {
    const runtimePath = runtimeAssets.get(relativePath);
    if (!runtimePath) {
      throw new Error(`Workboard Control UI runtime asset is missing: ${relativePath}`);
    }
    if (!fs.readFileSync(sourcePath).equals(fs.readFileSync(runtimePath))) {
      throw new Error(`Workboard Control UI asset differs from source payload: ${relativePath}`);
    }
  }
}

export function checkWorkboardControlUiAssets(packageRoot) {
  const pluginId = "workboard";
  const sourcePluginRoot = path.join(packageRoot, "dist", "extensions", pluginId);
  const runtimePluginRoot = path.join(packageRoot, "dist-runtime", "extensions", pluginId);
  const manifestPath = path.join(runtimePluginRoot, "openclaw.plugin.json");
  const manifest = JSON.parse(fs.readFileSync(manifestPath, "utf8"));
  const controlUi = manifest.controlUi;
  const styles = controlUi?.styles ?? [];
  if (!controlUi || typeof controlUi.entry !== "string" || !Array.isArray(styles)) {
    throw new Error("Workboard Control UI manifest is invalid");
  }
  const directory = path.posix.dirname(controlUi.entry);
  if (directory === ".") {
    throw new Error("Workboard Control UI manifest entry has no asset directory");
  }
  const sourceAssets = listBrowserAssets(sourcePluginRoot, directory, "source");
  const runtimeAssets = listBrowserAssets(runtimePluginRoot, directory, "runtime");
  const declaredAssets = [controlUi.entry, ...styles].map((asset) => {
    if (typeof asset !== "string") {
      throw new Error("Workboard Control UI manifest asset is invalid");
    }
    return path.posix.relative(directory, asset);
  });
  if (!declaredAssets.every((asset) => sourceAssets.has(asset) && runtimeAssets.has(asset))) {
    throw new Error("Workboard Control UI declared browser assets are missing");
  }
  assertSameAssetSet(sourceAssets, runtimeAssets);
}

if (import.meta.url === new URL(process.argv[1], "file:").href) {
  const packageRoot = process.env.OPENCLAW_PACKAGE_ROOT;
  if (!packageRoot) {
    throw new Error("OPENCLAW_PACKAGE_ROOT is not set");
  }
  checkWorkboardControlUiAssets(packageRoot);
}
