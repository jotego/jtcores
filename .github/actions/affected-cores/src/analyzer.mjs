import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { execFileSync } from 'node:child_process';

export const PULL_REQUEST_COMMENT_MARKER = '<!-- jtcores-affected-cores -->';

function filesystemPath(root, relativePath) {
  return path.join(root, ...relativePath.split('/'));
}

function isCore(root, name) {
  return fs.existsSync(filesystemPath(root, `cores/${name}/cfg/files.yaml`)) &&
    fs.existsSync(filesystemPath(root, `cores/${name}/cfg/macros.def`));
}

export function coreNames(root) {
  const coreDirectory = filesystemPath(root, 'cores');
  if (!fs.existsSync(coreDirectory)) throw new Error(`${root} does not contain cores/`);
  return fs.readdirSync(coreDirectory, { withFileTypes: true })
    .filter((entry) => entry.isDirectory() && isCore(root, entry.name))
    .map((entry) => entry.name)
    .sort();
}

function relativeIfInside(base, filename) {
  const relative = path.relative(base, filename);
  if (!relative || relative === '..' || relative.startsWith(`..${path.sep}`) || path.isAbsolute(relative)) {
    return null;
  }
  return relative.replaceAll('\\', '/');
}

function repositoryRelative(root, filename, overlayCores = null) {
  const normal = filename.replaceAll('\\', '/').trim();
  if (!normal) return null;
  if (path.isAbsolute(normal)) {
    if (overlayCores) {
      const overlayRelative = relativeIfInside(overlayCores, normal);
      if (overlayRelative) return `cores/${overlayRelative}`;
    }
    return relativeIfInside(root, normal);
  }
  return normal.startsWith('../') ? null : normal;
}

function isGeneratedSource(filename) {
  return /_(?:header|mmr)\.v$/i.test(path.basename(filename));
}

/**
 * JTFRAME's MMR generator writes generated Verilog directly below $CORES.
 * Give it a writable shadow of one core: normal HDL files are symlinks, while
 * existing *_mmr.v files are copied so a generator can never write through a
 * symlink into the checkout. All other cores remain directory symlinks.
 */
function createCoreOverlay(root, core, temporaryDirectory) {
  const sourceCores = filesystemPath(root, 'cores');
  const overlayCores = path.join(temporaryDirectory, 'cores');
  fs.mkdirSync(overlayCores, { recursive: true });

  for (const entry of fs.readdirSync(sourceCores, { withFileTypes: true })) {
    if (!entry.isDirectory()) continue;
    fs.symlinkSync(path.join(sourceCores, entry.name), path.join(overlayCores, entry.name));
  }

  const sourceCore = path.join(sourceCores, core);
  const overlayCore = path.join(overlayCores, core);
  fs.unlinkSync(overlayCore);
  fs.mkdirSync(overlayCore);

  for (const entry of fs.readdirSync(sourceCore, { withFileTypes: true })) {
    const source = path.join(sourceCore, entry.name);
    const destination = path.join(overlayCore, entry.name);
    if (entry.name !== 'hdl') {
      fs.symlinkSync(source, destination);
      continue;
    }

    fs.mkdirSync(destination);
    for (const hdlEntry of fs.readdirSync(source, { withFileTypes: true })) {
      const hdlSource = path.join(source, hdlEntry.name);
      const hdlDestination = path.join(destination, hdlEntry.name);
      if (hdlEntry.isFile() && hdlEntry.name.endsWith('_mmr.v')) {
        fs.copyFileSync(hdlSource, hdlDestination);
      } else {
        fs.symlinkSync(hdlSource, hdlDestination);
      }
    }
  }

  const overlayHdl = path.join(overlayCore, 'hdl');
  fs.mkdirSync(overlayHdl, { recursive: true });
  const generatedHeader = path.join(overlayHdl, `jt${core}_header.v`);
  if (!fs.existsSync(generatedHeader)) {
    fs.writeFileSync(generatedHeader, '// Placeholder used only while resolving JTFRAME files.\n');
  }

  return overlayCores;
}

/**
 * Ask JTFRAME for the authoritative file list of one core.
 *
 * `jtframe files plain` writes a file named `files` in its working directory.
 * A temporary directory keeps that generated file and ucode products out of
 * the checkout. JTFRAME itself remains responsible for YAML, macro, glob,
 * alias, and nested-config resolution.
 */
export function filesForCore(root, core) {
  const workingDirectory = fs.mkdtempSync(path.join(os.tmpdir(), 'jtcores-affected-'));
  const mmrConfig = filesystemPath(root, `cores/${core}/cfg/mmr.yaml`);
  const overlayCores = createCoreOverlay(root, core, workingDirectory);
  const script = [
    'set -euo pipefail',
    'export JTROOT="$JTCORES_ROOT"',
    'export JTFRAME="$JTROOT/modules/jtframe"',
    'export CORES="$JTCORES_CORES"',
    'export MODULES="$JTROOT/modules"',
    'export JTBIN="$PWD/jtbin"',
    'mkdir -p "$JTBIN"',
    ...(fs.existsSync(mmrConfig) ? ['"$JTFRAME/bin/jtframe" mmr "$JTCORES_CORE"'] : []),
    '"$JTFRAME/bin/jtframe" files plain "$JTCORES_CORE"',
    'cat files',
  ].join('\n');

  try {
    const output = execFileSync('bash', ['-c', script], {
      cwd: workingDirectory,
      encoding: 'utf8',
      env: {
        ...process.env,
        JTCORES_ROOT: root,
        JTCORES_CORE: core,
        JTCORES_CORES: overlayCores ?? filesystemPath(root, 'cores'),
      },
      stdio: ['ignore', 'pipe', 'pipe'],
    });
    return [...new Set(output.split(/\r?\n/)
      .map((filename) => repositoryRelative(root, filename, overlayCores))
      .filter(Boolean)
      .filter((filename) => !isGeneratedSource(filename)))].sort();
  } catch (error) {
    const detail = error.stderr?.toString().trim() || error.message;
    throw new Error(`jtframe files plain ${core} failed: ${detail}`);
  } finally {
    fs.rmSync(workingDirectory, { recursive: true, force: true });
  }
}

function submodulePaths(root) {
  const gitmodules = filesystemPath(root, '.gitmodules');
  if (!fs.existsSync(gitmodules)) return [];
  return fs.readFileSync(gitmodules, 'utf8')
    .split(/\r?\n/)
    .map((line) => line.match(/^\s*path\s*=\s*(.+?)\s*$/)?.[1])
    .filter(Boolean)
    .map((value) => value.replaceAll('\\', '/'));
}

export function normalizeChangedFiles(value) {
  if (Array.isArray(value)) {
    return [...new Set(value.map(String).map((filename) => filename.trim()).filter(Boolean))].sort();
  }
  const trimmed = String(value ?? '').trim();
  if (!trimmed) return [];
  if (trimmed.startsWith('[')) {
    const parsed = JSON.parse(trimmed);
    if (!Array.isArray(parsed)) throw new Error('changed-files JSON must be an array');
    return normalizeChangedFiles(parsed);
  }
  return normalizeChangedFiles(trimmed.split(/\r?\n/));
}

export function changedFilesFromGit(root, baseSha, headSha = 'HEAD') {
  if (!baseSha) throw new Error('base-sha is required when changed-files is not provided');
  const output = execFileSync(
    'git',
    ['-C', root, 'diff', '--name-only', '--no-renames', `${baseSha}...${headSha}`],
    { encoding: 'utf8' },
  );
  return normalizeChangedFiles(output);
}

function usesFile(fileList, changedFile, submodules) {
  if (fileList.includes(changedFile)) return true;
  return submodules.some((submodule) => changedFile === submodule &&
    fileList.some((filename) => filename.startsWith(`${submodule}/`)));
}

export function affectFromFileLists({ changedFiles, fileLists, submodules = [] }) {
  const affected = {};
  const matched = new Set();
  const files = normalizeChangedFiles(changedFiles);

  for (const core of Object.keys(fileLists).sort()) {
    const affectingFiles = files.filter((changedFile) => usesFile(fileLists[core], changedFile, submodules));
    if (affectingFiles.length === 0) continue;
    affected[core] = affectingFiles;
    affectingFiles.forEach((filename) => matched.add(filename));
  }

  return {
    affected,
    affectedCoreNames: Object.keys(affected),
    unmatchedFiles: files.filter((filename) => !matched.has(filename)),
  };
}

export function analyzeRepository({ repositoryPath, changedFiles, listFiles = filesForCore }) {
  const root = path.resolve(repositoryPath);
  const fileLists = {};
  const unresolvedCores = [];
  for (const core of coreNames(root)) {
    try {
      fileLists[core] = listFiles(root, core);
    } catch (error) {
      unresolvedCores.push({ core, error: error.message });
    }
  }
  return {
    ...affectFromFileLists({
    changedFiles,
    fileLists,
    submodules: submodulePaths(root),
    }),
    unresolvedCores,
  };
}

export function markdownReport(result) {
  const rows = [];
  if (result.affectedCoreNames.length === 0) {
    rows.push('No cores are affected by the changed files.');
  } else {
    rows.push(
      '## Cores possibly affected',
      '',
      '| Core | Changed build inputs |',
      '| --- | --- |',
    );
    for (const core of result.affectedCoreNames) {
      rows.push(`| \`${core}\` | ${result.affected[core].map((file) => `\`${file}\``).join('<br>')} |`);
    }
  }
  if (result.unresolvedCores?.length > 0) {
    rows.push('', `> Warning: JTFRAME could not resolve ${result.unresolvedCores.map(({ core }) => `\`${core}\``).join(', ')}.`);
  }
  return `${rows.join('\n')}\n`;
}

function filenameOnly(filename) {
  return filename.replaceAll('\\', '/').split('/').at(-1);
}

export function pullRequestComment(result) {
  const rows = [PULL_REQUEST_COMMENT_MARKER, '## Cores possibly affected', ''];
  if (result.affectedCoreNames.length === 0) {
    rows.push('No cores are affected by the changed files.');
  } else {
    for (const core of result.affectedCoreNames) {
      rows.push(`- **${core}**`);
      for (const filename of [...new Set(result.affected[core].map(filenameOnly))]) {
        rows.push(`  - \`${filename}\``);
      }
    }
  }
  if (result.unresolvedCores?.length > 0) {
    rows.push('', `> Warning: JTFRAME could not resolve ${result.unresolvedCores.map(({ core }) => `\`${core}\``).join(', ')}.`);
  }
  return `${rows.join('\n')}\n`;
}
