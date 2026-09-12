import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import { checkWorkboardControlUiAssets } from "./check-workboard-control-ui-assets.mjs";

const MAX_ASSET_BYTES = 4 * 1024 * 1024;

function writeFixture(options = {}) {
  const styles =
    Object.hasOwn(options, "styles") ? options.styles : ["dist/control-ui/build/index.css"];
  const packageRoot = fs.mkdtempSync(path.join(os.tmpdir(), "workboard-package-check-"));
  const sourceRoot = path.join(packageRoot, "dist", "extensions", "workboard");
  const runtimeRoot = path.join(packageRoot, "dist-runtime", "extensions", "workboard");
  const assetDir = path.join("dist", "control-ui", "build");
  for (const root of [sourceRoot, runtimeRoot]) {
    fs.mkdirSync(path.join(root, assetDir, "chunks"), { recursive: true });
    fs.writeFileSync(
      path.join(root, "openclaw.plugin.json"),
      JSON.stringify({
        controlUi: {
          entry: "dist/control-ui/build/index.js",
          ...(styles === undefined ? {} : { styles }),
        },
      }),
    );
    fs.writeFileSync(path.join(root, assetDir, "index.js"), "entry");
    fs.writeFileSync(path.join(root, assetDir, "index.css"), "style");
    fs.writeFileSync(path.join(root, assetDir, "chunks", "vendor.js"), "chunk");
  }
  return { packageRoot, sourceRoot, runtimeRoot, assetDir };
}

function withFixture(run) {
  const fixture = writeFixture();
  try {
    run(fixture);
  } finally {
    fs.rmSync(fixture.packageRoot, { recursive: true, force: true });
  }
}

test("checks every bounded Workboard browser asset", () => {
  withFixture(({ packageRoot }) => checkWorkboardControlUiAssets(packageRoot));
});

test("accepts a Workboard manifest without styles", () => {
  const fixture = writeFixture({ styles: undefined });
  try {
    checkWorkboardControlUiAssets(fixture.packageRoot);
  } finally {
    fs.rmSync(fixture.packageRoot, { recursive: true, force: true });
  }
});

test("rejects a missing nested Workboard browser chunk", () => {
  withFixture(({ packageRoot, runtimeRoot, assetDir }) => {
    fs.unlinkSync(path.join(runtimeRoot, assetDir, "chunks", "vendor.js"));
    assert.throws(() => checkWorkboardControlUiAssets(packageRoot), /asset set differs|asset is missing/);
  });
});

test("rejects a rewritten nested Workboard browser chunk", () => {
  withFixture(({ packageRoot, runtimeRoot, assetDir }) => {
    fs.writeFileSync(path.join(runtimeRoot, assetDir, "chunks", "vendor.js"), "rewritten");
    assert.throws(() => checkWorkboardControlUiAssets(packageRoot), /differs from source payload/);
  });
});

test("rejects a symlinked nested Workboard browser chunk", () => {
  withFixture(({ packageRoot, runtimeRoot, assetDir }) => {
    const chunk = path.join(runtimeRoot, assetDir, "chunks", "vendor.js");
    fs.unlinkSync(chunk);
    fs.writeFileSync(path.join(runtimeRoot, "outside.js"), "chunk");
    fs.symlinkSync(path.join(runtimeRoot, "outside.js"), chunk);
    assert.throws(() => checkWorkboardControlUiAssets(packageRoot), /not a regular file/);
  });
});

test("rejects a symlinked Workboard browser directory ancestor", () => {
  withFixture(({ packageRoot, runtimeRoot }) => {
    const controlUiDir = path.join(runtimeRoot, "dist", "control-ui");
    const outsideDir = path.join(runtimeRoot, "outside-control-ui");
    fs.renameSync(controlUiDir, outsideDir);
    fs.symlinkSync(outsideDir, controlUiDir);
    assert.throws(() => checkWorkboardControlUiAssets(packageRoot), /unsafe ancestor/);
  });
});

for (const affected of ["runtime", "both"]) {
  test(`rejects nested browser directory symlinks in ${affected} trees`, () => {
    withFixture(({ packageRoot, sourceRoot, runtimeRoot, assetDir }) => {
      for (const root of affected === "both" ? [sourceRoot, runtimeRoot] : [runtimeRoot]) {
        const chunks = path.join(root, assetDir, "chunks");
        const outside = path.join(root, "outside-chunks");
        fs.renameSync(chunks, outside);
        fs.symlinkSync(outside, chunks);
      }
      assert.throws(() => checkWorkboardControlUiAssets(packageRoot), /not a regular file/);
    });
  });
}

test("rejects an oversized nested Workboard browser chunk", () => {
  withFixture(({ packageRoot, runtimeRoot, assetDir }) => {
    fs.writeFileSync(path.join(runtimeRoot, assetDir, "chunks", "vendor.js"), Buffer.alloc(MAX_ASSET_BYTES + 1));
    assert.throws(() => checkWorkboardControlUiAssets(packageRoot), /asset exceeds/);
  });
});

test("rejects nested Workboard browser chunks over the aggregate limit", () => {
  withFixture(({ packageRoot, sourceRoot, runtimeRoot, assetDir }) => {
    for (const root of [sourceRoot, runtimeRoot]) {
      for (const fileName of ["vendor.js", "first.js", "second.js"]) {
        fs.writeFileSync(path.join(root, assetDir, "chunks", fileName), Buffer.alloc(3 * 1024 * 1024));
      }
    }
    assert.throws(() => checkWorkboardControlUiAssets(packageRoot), /exceeds 8388608 bytes/);
  });
});
