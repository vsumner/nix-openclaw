import assert from "node:assert/strict";
import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import {
  decodePacquet,
  hydrateMissingPublicationTimes,
  normalizeMetadataTree,
  normalizePacquet,
  normalizeRegistryDocument,
} from "./normalize-pnpm-metadata.mjs";

function fixture() {
  const oldRecord = Buffer.from(JSON.stringify({ name: "@scope/demo", version: "1.0.0" }));
  const wantedRecord = Buffer.from(JSON.stringify({ name: "@scope/demo", version: "1.1.0" }));
  const metadata = Buffer.from(JSON.stringify({ modified: "2026-09-01T00:00:00.000Z" }));
  const index = Buffer.from(JSON.stringify({
    name: "@scope/demo",
    distTags: { latest: "2.0.0" },
    time: {
      modified: "2026-09-01T00:00:00.000Z",
      "1.0.0": "2026-01-01T00:00:00.000Z",
      "1.1.0": "2026-02-01T00:00:00.000Z",
      "2.0.0": "2026-09-01T00:00:00.000Z",
    },
    versions: [
      ["1.0.0", 0, oldRecord.length],
      ["1.1.0", oldRecord.length, wantedRecord.length],
    ],
  }));
  return Buffer.concat([
    Buffer.from(`pacquet-meta-v1 ${metadata.length} ${index.length}\n`),
    metadata,
    index,
    oldRecord,
    wantedRecord,
  ]);
}

function pacquetFixture(records) {
  let offset = 0;
  const versions = records.map(([version, manifest]) => {
    const content = Buffer.from(JSON.stringify(manifest));
    const record = [version, offset, content.length, content];
    offset += content.length;
    return record;
  });
  const metadata = Buffer.from(JSON.stringify({}));
  const index = Buffer.from(JSON.stringify({
    name: "stable-package",
    distTags: {},
    time: Object.fromEntries(records.map(([version]) => [
      version,
      version === "1.0.0" ? "2026-01-01T00:00:00.000Z" : "2026-01-02T00:00:00.000Z",
    ])),
    versions: versions.map(([version, recordOffset, length]) => [version, recordOffset, length]),
  }));
  return Buffer.concat([
    Buffer.from(`pacquet-meta-v1 ${metadata.length} ${index.length}\n`),
    metadata,
    index,
    ...versions.map((record) => record[3]),
  ]);
}

test("normalization retains only lockfile versions and stable publication evidence", () => {
  const normalized = normalizePacquet(fixture(), new Set(["1.1.0"]));
  const decoded = decodePacquet(normalized);
  assert.deepEqual(decoded.index.versions.map(([version]) => version), ["1.1.0"]);
  assert.deepEqual(decoded.index.distTags, {});
  assert.deepEqual(decoded.index.time, {
    "1.1.0": "2026-02-01T00:00:00.000Z",
    modified: "2026-02-01T00:00:00.000Z",
  });
  assert.equal(JSON.parse(decoded.versions.toString()).version, "1.1.0");
});

test("normalization omits metadata with no locked version", () => {
  assert.equal(normalizePacquet(fixture(), new Set(["9.9.9"])), undefined);
});

test("normalization preserves timestamp absence without inventing policy evidence", () => {
  const source = fixture();
  const decoded = decodePacquet(source);
  decoded.index.time = {};
  const metadata = Buffer.from(JSON.stringify(decoded.metadata));
  const index = Buffer.from(JSON.stringify(decoded.index));
  const withoutTimes = Buffer.concat([
    Buffer.from(`pacquet-meta-v1 ${metadata.length} ${index.length}\n`),
    metadata,
    index,
    decoded.versions,
  ]);

  const normalized = normalizePacquet(withoutTimes, new Set(["1.1.0"]));
  const normalizedDecoded = decodePacquet(normalized);
  assert.deepEqual(normalizedDecoded.metadata, {});
  assert.deepEqual(normalizedDecoded.index.time, {});
});

test("normalization canonicalizes manifest objects but preserves export and import condition order", () => {
  const first = {
    version: "1.0.0",
    dependencies: { zebra: "1.0.0", alpha: "1.0.0" },
    exports: { ".": { node: "./node.js", default: "./default.js" } },
    imports: { "#internal": { development: "./dev.js", default: "./prod.js" } },
    files: ["node.js", "default.js"],
    name: "stable-package",
  };
  const reordered = {
    name: "stable-package",
    files: ["node.js", "default.js"],
    imports: { "#internal": { development: "./dev.js", default: "./prod.js" } },
    exports: { ".": { node: "./node.js", default: "./default.js" } },
    dependencies: { alpha: "1.0.0", zebra: "1.0.0" },
    version: "1.0.0",
  };
  const other = { name: "stable-package", version: "2.0.0" };
  const wanted = new Set(["1.0.0", "2.0.0"]);

  const nativeFirst = normalizePacquet(pacquetFixture([["2.0.0", other], ["1.0.0", first]]), wanted);
  const nativeReordered = normalizePacquet(pacquetFixture([["1.0.0", reordered], ["2.0.0", other]]), wanted);
  assert.deepEqual(nativeFirst, nativeReordered);

  const registryFirst = normalizeRegistryDocument({
    name: "stable-package",
    time: { "2.0.0": "2026-01-02T00:00:00.000Z", "1.0.0": "2026-01-01T00:00:00.000Z" },
    versions: { "2.0.0": other, "1.0.0": first },
  }, wanted);
  const registryReordered = normalizeRegistryDocument({
    name: "stable-package",
    time: { "1.0.0": "2026-01-01T00:00:00.000Z", "2.0.0": "2026-01-02T00:00:00.000Z" },
    versions: { "1.0.0": reordered, "2.0.0": other },
  }, wanted);
  assert.deepEqual(registryFirst, registryReordered);
  assert.deepEqual(nativeFirst, registryFirst);

  const decoded = decodePacquet(nativeFirst);
  assert.deepEqual(decoded.index.versions.map(([version]) => version), ["1.0.0", "2.0.0"]);
  const [, manifestOffset, manifestLength] = decoded.index.versions[0];
  const manifest = JSON.parse(decoded.versions.subarray(manifestOffset, manifestOffset + manifestLength));
  assert.deepEqual(Object.keys(manifest.dependencies), ["alpha", "zebra"]);
  assert.deepEqual(Object.keys(manifest.exports["."]), ["node", "default"]);
  assert.deepEqual(Object.keys(manifest.imports["#internal"]), ["development", "default"]);
  assert.deepEqual(manifest.files, ["node.js", "default.js"]);
});

test("higher-quality metadata can replace a read-only normalized record", async (t) => {
  const root = await fs.mkdtemp(path.join(os.tmpdir(), "pnpm-metadata-test-"));
  t.after(() => fs.rm(root, { recursive: true, force: true }));
  const source = path.join(root, "source");
  const output = path.join(root, "output");
  const record = path.join(source, "@scope", "demo.jsonl");
  await fs.mkdir(path.dirname(record), { recursive: true });
  await fs.writeFile(record, fixture());

  await normalizeMetadataTree(source, ["@scope/demo@1.1.0"], output);
  await normalizeMetadataTree(source, ["@scope/demo@1.1.0"], output);

  const normalized = decodePacquet(await fs.readFile(path.join(output, "@scope", "demo.jsonl")));
  assert.equal(normalized.index.time["1.1.0"], "2026-02-01T00:00:00.000Z");
});

test("registry hydration supplies exact publication evidence for timestamp-free records", async (t) => {
  const root = await fs.mkdtemp(path.join(os.tmpdir(), "pnpm-metadata-hydrate-"));
  t.after(() => fs.rm(root, { recursive: true, force: true }));
  const target = path.join(root, "@scope", "demo.jsonl");
  const decoded = decodePacquet(fixture());
  decoded.index.time = {};
  const metadata = Buffer.from(JSON.stringify(decoded.metadata));
  const index = Buffer.from(JSON.stringify(decoded.index));
  await fs.mkdir(path.dirname(target), { recursive: true });
  await fs.writeFile(target, Buffer.concat([
    Buffer.from(`pacquet-meta-v1 ${metadata.length} ${index.length}\n`),
    metadata,
    index,
    decoded.versions,
  ]));

  const registryDocument = {
    name: "@scope/demo",
    time: { "1.1.0": "2026-02-01T00:00:00.000Z" },
    versions: { "1.1.0": { name: "@scope/demo", version: "1.1.0" } },
  };
  await hydrateMissingPublicationTimes(root, ["@scope/demo@1.1.0"], async () => ({
    ok: true,
    json: async () => registryDocument,
  }));

  const normalized = decodePacquet(await fs.readFile(target));
  assert.equal(normalized.index.time["1.1.0"], "2026-02-01T00:00:00.000Z");
  assert.deepEqual(
    decodePacquet(normalizeRegistryDocument(registryDocument, new Set(["1.1.0"]))).index.time,
    {
      "1.1.0": "2026-02-01T00:00:00.000Z",
      modified: "2026-02-01T00:00:00.000Z",
    },
  );
});

test("registry hydration creates metadata that pnpm did not persist", async (t) => {
  const root = await fs.mkdtemp(path.join(os.tmpdir(), "pnpm-metadata-missing-"));
  t.after(() => fs.rm(root, { recursive: true, force: true }));
  const registryDocument = {
    name: "plain-package",
    time: { "2.0.0": "2026-03-01T00:00:00.000Z" },
    versions: { "2.0.0": { name: "plain-package", version: "2.0.0" } },
  };

  await hydrateMissingPublicationTimes(root, ["plain-package@2.0.0"], async () => ({
    ok: true,
    json: async () => registryDocument,
  }));

  const normalized = decodePacquet(await fs.readFile(path.join(root, "plain-package.jsonl")));
  assert.equal(normalized.index.time["2.0.0"], "2026-03-01T00:00:00.000Z");
});
