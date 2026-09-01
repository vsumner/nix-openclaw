#!/usr/bin/env node
import fs from "node:fs/promises";
import path from "node:path";

const HEADER = "pacquet-meta-v1";

function parseLockKey(raw) {
  const key = raw.startsWith("/") ? raw.slice(1) : raw;
  const separator = key.lastIndexOf("@");
  if (separator <= 0) return undefined;
  return { name: key.slice(0, separator), version: key.slice(separator + 1).split("(", 1)[0] };
}

export function decodePacquet(buffer) {
  const newline = buffer.indexOf(10);
  if (newline < 0) throw new Error("pnpm metadata is missing its header newline");
  const [format, metadataLengthRaw, indexLengthRaw] = buffer.subarray(0, newline).toString().split(" ");
  if (format !== HEADER) throw new Error(`unsupported pnpm metadata format: ${format}`);
  const metadataLength = Number(metadataLengthRaw);
  const indexLength = Number(indexLengthRaw);
  if (!Number.isSafeInteger(metadataLength) || !Number.isSafeInteger(indexLength)) {
    throw new Error("pnpm metadata header has invalid lengths");
  }
  const metadataStart = newline + 1;
  const indexStart = metadataStart + metadataLength;
  const versionsStart = indexStart + indexLength;
  return {
    metadata: JSON.parse(buffer.subarray(metadataStart, indexStart).toString()),
    index: JSON.parse(buffer.subarray(indexStart, versionsStart).toString()),
    versions: buffer.subarray(versionsStart),
  };
}

export function normalizePacquet(buffer, wantedVersions) {
  const decoded = decodePacquet(buffer);
  const records = [];
  let offset = 0;
  for (const [version, sourceOffset, length] of decoded.index.versions ?? []) {
    if (!wantedVersions.has(version)) continue;
    const content = decoded.versions.subarray(sourceOffset, sourceOffset + length);
    records.push([version, offset, content.length, content]);
    offset += content.length;
  }
  if (records.length === 0) return undefined;

  const times = Object.fromEntries(
    records
      .map(([version]) => [version, decoded.index.time?.[version]])
      .filter(([, published]) => typeof published === "string"),
  );
  const modified = Object.values(times).sort().at(-1);
  const metadata = Buffer.from(JSON.stringify(modified ? { modified } : {}));
  const index = Buffer.from(JSON.stringify({
    name: decoded.index.name,
    distTags: {},
    time: modified ? { ...times, modified } : {},
    versions: records.map(([version, recordOffset, length]) => [version, recordOffset, length]),
  }));
  return Buffer.concat([
    Buffer.from(`${HEADER} ${metadata.length} ${index.length}\n`),
    metadata,
    index,
    ...records.map((record) => record[3]),
  ]);
}

export function normalizeRegistryDocument(document, wantedVersions) {
  if (!document || typeof document.name !== "string") {
    throw new Error("registry metadata has no package name");
  }
  const records = [];
  let offset = 0;
  for (const version of [...wantedVersions].sort()) {
    const manifest = document.versions?.[version];
    const published = document.time?.[version];
    if (!manifest) throw new Error(`registry metadata for ${document.name} has no ${version} manifest`);
    if (typeof published !== "string") {
      throw new Error(`registry metadata for ${document.name}@${version} has no publication time`);
    }
    const content = Buffer.from(JSON.stringify(manifest));
    records.push([version, offset, content.length, content, published]);
    offset += content.length;
  }
  if (records.length === 0) return undefined;

  const times = Object.fromEntries(records.map(([version, , , , published]) => [version, published]));
  const modified = Object.values(times).sort().at(-1);
  const metadata = Buffer.from(JSON.stringify({ modified }));
  const index = Buffer.from(JSON.stringify({
    name: document.name,
    distTags: {},
    time: { ...times, modified },
    versions: records.map(([version, recordOffset, length]) => [version, recordOffset, length]),
  }));
  return Buffer.concat([
    Buffer.from(`${HEADER} ${metadata.length} ${index.length}\n`),
    metadata,
    index,
    ...records.map((record) => record[3]),
  ]);
}

function wantedVersionsByName(lockKeys) {
  const wanted = new Map();
  for (const raw of lockKeys) {
    const parsed = parseLockKey(raw);
    if (!parsed) continue;
    const versions = wanted.get(parsed.name) ?? new Set();
    versions.add(parsed.version);
    wanted.set(parsed.name, versions);
  }
  return wanted;
}

async function writeNormalized(target, normalized) {
  await fs.mkdir(path.dirname(target), { recursive: true });
  try {
    await fs.chmod(target, 0o644);
  } catch (error) {
    if (error.code !== "ENOENT") throw error;
  }
  await fs.writeFile(target, normalized, { mode: 0o644 });
  await fs.chmod(target, 0o444);
}

export async function normalizeMetadataTree(sourceRoot, lockKeys, outputRoot) {
  const wanted = wantedVersionsByName(lockKeys);

  async function visit(directory) {
    for (const entry of await fs.readdir(directory, { withFileTypes: true })) {
      const source = path.join(directory, entry.name);
      if (entry.isDirectory()) {
        await visit(source);
        continue;
      }
      if (!entry.isFile() || !entry.name.endsWith(".jsonl")) continue;
      const decoded = decodePacquet(await fs.readFile(source));
      const versions = wanted.get(decoded.index.name);
      if (!versions) continue;
      const normalized = normalizePacquet(await fs.readFile(source), versions);
      if (!normalized) continue;
      const target = path.join(outputRoot, path.relative(sourceRoot, source));
      await writeNormalized(target, normalized);
    }
  }
  await visit(sourceRoot);
}

export async function hydrateMissingPublicationTimes(outputRoot, lockKeys, fetchImpl = fetch) {
  const wanted = wantedVersionsByName(lockKeys);
  const targets = [];
  const seen = new Set();

  async function visit(directory) {
    for (const entry of await fs.readdir(directory, { withFileTypes: true })) {
      const target = path.join(directory, entry.name);
      if (entry.isDirectory()) {
        await visit(target);
        continue;
      }
      if (!entry.isFile() || !entry.name.endsWith(".jsonl")) continue;
      const decoded = decodePacquet(await fs.readFile(target));
      const versions = wanted.get(decoded.index.name);
      if (!versions) continue;
      seen.add(decoded.index.name);
      const missingTime = [...versions].some(
        (version) => typeof decoded.index.time?.[version] !== "string",
      );
      if (missingTime) targets.push({ name: decoded.index.name, target, versions });
    }
  }
  await visit(outputRoot);
  for (const [name, versions] of wanted) {
    if (seen.has(name)) continue;
    targets.push({ name, target: path.join(outputRoot, `${name}.jsonl`), versions });
  }
  targets.sort((left, right) => left.name.localeCompare(right.name));

  let cursor = 0;
  async function worker() {
    while (cursor < targets.length) {
      const current = targets[cursor++];
      const response = await fetchImpl(
        `https://registry.npmjs.org/${encodeURIComponent(current.name)}`,
        { headers: { accept: "application/json" } },
      );
      if (!response.ok) {
        throw new Error(`failed to fetch full registry metadata for ${current.name}: ${response.status}`);
      }
      const document = await response.json();
      if (document.name !== current.name) {
        throw new Error(`registry metadata name mismatch for ${current.name}`);
      }
      const normalized = normalizeRegistryDocument(document, current.versions);
      await writeNormalized(current.target, normalized);
    }
  }
  await Promise.all(Array.from({ length: Math.min(8, targets.length) }, () => worker()));
}

if (import.meta.url === `file://${process.argv[1]}`) {
  const args = process.argv.slice(2);
  if (args[0] === "--hydrate-missing-times") {
    const [, outputRoot, lockKeysPath] = args;
    if (!outputRoot || !lockKeysPath) {
      throw new Error("usage: normalize-pnpm-metadata.mjs --hydrate-missing-times OUTPUT_ROOT LOCK_KEYS");
    }
    const lockKeys = (await fs.readFile(lockKeysPath, "utf8")).split("\n").filter(Boolean);
    await hydrateMissingPublicationTimes(outputRoot, lockKeys);
  } else {
    const [sourceRoot, lockKeysPath, outputRoot] = args;
    if (!sourceRoot || !lockKeysPath || !outputRoot) {
      throw new Error("usage: normalize-pnpm-metadata.mjs SOURCE_ROOT LOCK_KEYS OUTPUT_ROOT");
    }
    const lockKeys = (await fs.readFile(lockKeysPath, "utf8")).split("\n").filter(Boolean);
    await normalizeMetadataTree(sourceRoot, lockKeys, outputRoot);
  }
}
