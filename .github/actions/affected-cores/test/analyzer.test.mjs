import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';
import {
  affectFromFileLists,
  analyzeRepository,
  filesForCore,
  markdownReport,
  normalizeChangedFiles,
  pullRequestComment,
  PULL_REQUEST_COMMENT_MARKER,
  syncPullRequestComment,
} from '../src/analyzer.mjs';

test('uses generated MMR and header placeholders only to resolve the JTFRAME list', () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'jtframe-files-'));
  try {
    const command = path.join(root, 'modules/jtframe/bin/jtframe');
    fs.mkdirSync(path.dirname(command), { recursive: true });
    fs.mkdirSync(path.join(root, 'cores/demo/cfg'), { recursive: true });
    fs.mkdirSync(path.join(root, 'cores/demo/hdl'), { recursive: true });
    fs.writeFileSync(path.join(root, 'cores/demo/cfg/files.yaml'), 'demo:\n');
    fs.writeFileSync(path.join(root, 'cores/demo/cfg/macros.def'), 'CORENAME=demo\n');
    fs.writeFileSync(path.join(root, 'cores/demo/cfg/mmr.yaml'), '- name: demo\n');
    fs.writeFileSync(path.join(root, 'cores/demo/hdl/demo.v'), 'module demo; endmodule\n');
    fs.writeFileSync(path.join(root, 'cores/demo/hdl/demo_mmr.v'), 'source file\n');
    fs.writeFileSync(command, `#!/usr/bin/env bash
set -euo pipefail
test "$JTROOT" = "${root}"
test "$MODULES" = "$JTROOT/modules"
test -d "$JTBIN"
test "$CORES" != "$JTROOT/cores"
if [ "$1" = mmr ]; then
  test "$2" = demo
  printf 'generated file\\n' > "$CORES/demo/hdl/demo_mmr.v"
  exit 0
fi
test "$1" = files
test "$2" = plain
test "$3" = demo
test -f "$CORES/demo/hdl/demo_mmr.v"
test -f "$CORES/demo/hdl/jtdemo_header.v"
printf '%s\\n' "$CORES/demo/hdl/demo.v" "$CORES/demo/hdl/demo_mmr.v" "$CORES/demo/hdl/jtdemo_header.v" > files
`);
    fs.chmodSync(command, 0o755);

    assert.deepEqual(filesForCore(root, 'demo'), ['cores/demo/hdl/demo.v']);
    assert.equal(fs.readFileSync(path.join(root, 'cores/demo/hdl/demo_mmr.v'), 'utf8'), 'source file\n');
    assert.equal(fs.existsSync(path.join(root, 'cores/demo/hdl/jtdemo_header.v')), false);
  } finally {
    fs.rmSync(root, { recursive: true, force: true });
  }
});

test('creates the temporary header directory for config-only cores', () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'jtframe-config-only-'));
  try {
    const command = path.join(root, 'modules/jtframe/bin/jtframe');
    fs.mkdirSync(path.dirname(command), { recursive: true });
    fs.mkdirSync(path.join(root, 'cores/bare/cfg'), { recursive: true });
    fs.writeFileSync(path.join(root, 'cores/bare/cfg/files.yaml'), 'bare:\n');
    fs.writeFileSync(path.join(root, 'cores/bare/cfg/macros.def'), 'CORENAME=bare\n');
    fs.writeFileSync(command, `#!/usr/bin/env bash
set -euo pipefail
test "$1" = files
test "$2" = plain
test "$3" = bare
test -f "$CORES/bare/hdl/jtbare_header.v"
printf '%s\\n' "$JTROOT/modules/jtframe/hdl/jtframe_ff.v" > files
`);
    fs.chmodSync(command, 0o755);

    assert.deepEqual(filesForCore(root, 'bare'), ['modules/jtframe/hdl/jtframe_ff.v']);
  } finally {
    fs.rmSync(root, { recursive: true, force: true });
  }
});

test('maps each exact JTFRAME file-list entry to every consuming core', () => {
  const result = affectFromFileLists({
    changedFiles: [
      'cores/alpha/hdl/alpha.v',
      'modules/jtframe/hdl/jtframe_ff.v',
      'README.md',
    ],
    fileLists: {
      alpha: ['cores/alpha/hdl/alpha.v', 'modules/jtframe/hdl/jtframe_ff.v'],
      beta: ['cores/alpha/hdl/alpha.v'],
      gamma: ['modules/jtframe/hdl/jtframe_ff.v'],
    },
  });

  assert.deepEqual(result.affected, {
    alpha: ['cores/alpha/hdl/alpha.v', 'modules/jtframe/hdl/jtframe_ff.v'],
    beta: ['cores/alpha/hdl/alpha.v'],
    gamma: ['modules/jtframe/hdl/jtframe_ff.v'],
  });
  assert.deepEqual(result.unmatchedFiles, ['README.md']);
});

test('keeps reporting when JTFRAME cannot resolve one core', () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'jtframe-cores-'));
  try {
    for (const core of ['good', 'broken']) {
      const config = path.join(root, `cores/${core}/cfg`);
      fs.mkdirSync(config, { recursive: true });
      fs.writeFileSync(path.join(config, 'files.yaml'), `${core}:\n`);
      fs.writeFileSync(path.join(config, 'macros.def'), `CORENAME=${core}\n`);
    }
    const result = analyzeRepository({
      repositoryPath: root,
      changedFiles: ['cores/good/hdl/good.v'],
      listFiles: (_root, core) => {
        if (core === 'broken') throw new Error('missing generated source');
        return ['cores/good/hdl/good.v'];
      },
    });

    assert.deepEqual(result.affected, { good: ['cores/good/hdl/good.v'] });
    assert.deepEqual(result.unresolvedCores, [{ core: 'broken', error: 'missing generated source' }]);
  } finally {
    fs.rmSync(root, { recursive: true, force: true });
  }
});

test('a submodule gitlink change affects every core using a file below it', () => {
  const result = affectFromFileLists({
    changedFiles: ['modules/jt900h'],
    fileLists: {
      ngp: ['modules/jt900h/hdl/jt900h.v'],
      ngpc: ['modules/jt900h/hdl/jt95c061.v'],
      other: ['modules/jtframe/hdl/jtframe_ff.v'],
    },
    submodules: ['modules/jt900h'],
  });

  assert.deepEqual(result.affected, {
    ngp: ['modules/jt900h'],
    ngpc: ['modules/jt900h'],
  });
});

test('changed-file input accepts either newline text or a JSON array', () => {
  assert.deepEqual(normalizeChangedFiles('b.v\na.v\nb.v\n'), ['a.v', 'b.v']);
  assert.deepEqual(normalizeChangedFiles('["b.v", "a.v"]'), ['a.v', 'b.v']);
});

test('reports unresolved cores even when no changed input matched', () => {
  const report = markdownReport({
    affectedCoreNames: [],
    unresolvedCores: [{ core: 'demo', error: 'missing input' }],
  });

  assert.match(report, /No cores are affected/);
  assert.match(report, /JTFRAME could not resolve `demo`/);
});

test('formats the pull-request comment with bold core names and basename-only inputs', () => {
  const comment = pullRequestComment({
    affectedCoreNames: ['rastan', 'vlfied'],
    affected: {
      rastan: ['cores/rastan/hdl/jtrastan_obj.v'],
      vlfied: ['cores/rastan/hdl/jtrastan_obj.v'],
    },
    unresolvedCores: [],
  });

  assert.match(comment, new RegExp(PULL_REQUEST_COMMENT_MARKER.replace(/[<>!-]/g, '\\$&')));
  assert.match(comment, /- \*\*rastan\*\*\n  - `jtrastan_obj\.v`/);
  assert.match(comment, /- \*\*vlfied\*\*\n  - `jtrastan_obj\.v`/);
  assert.doesNotMatch(comment, /cores\/rastan\/hdl/);
});

function response(status, payload) {
  return {
    ok: status >= 200 && status < 300,
    status,
    json: async () => payload,
    text: async () => typeof payload === 'string' ? payload : JSON.stringify(payload),
  };
}

test('creates one marker-tagged pull-request comment, then updates that same ID', async () => {
  const body = `${PULL_REQUEST_COMMENT_MARKER}\n- **rastan**\n  - \`jtrastan_obj.v\`\n`;
  const createCalls = [];
  const created = await syncPullRequestComment({
    token: 'token',
    repository: 'jotego/jtcores',
    pullRequestNumber: 123,
    body,
    hasAffectedCores: true,
    apiUrl: 'https://github.example/api/v3',
    fetchImpl: async (url, options = {}) => {
      createCalls.push({ url, options });
      if (options.method === 'POST') return response(201, { id: 77 });
      return response(200, []);
    },
  });

  assert.deepEqual(created, { id: 77, status: 'created' });
  assert.equal(createCalls.length, 2);
  assert.equal(createCalls[1].options.method, 'POST');
  assert.deepEqual(JSON.parse(createCalls[1].options.body), { body });

  const updateCalls = [];
  const updated = await syncPullRequestComment({
    token: 'token',
    repository: 'jotego/jtcores',
    pullRequestNumber: 123,
    body: `${body}new input\n`,
    hasAffectedCores: true,
    fetchImpl: async (url, options = {}) => {
      updateCalls.push({ url, options });
      if (options.method === 'PATCH') return response(200, { id: 77 });
      return response(200, [{ id: 77, body }]);
    },
  });

  assert.deepEqual(updated, { id: 77, status: 'updated' });
  assert.equal(updateCalls.length, 2);
  assert.equal(updateCalls[1].options.method, 'PATCH');
  assert.match(updateCalls[1].url, /issues\/comments\/77$/);
});
