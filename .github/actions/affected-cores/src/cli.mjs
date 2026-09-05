#!/usr/bin/env node
import { analyzeRepository, changedFilesFromGit, markdownReport, normalizeChangedFiles } from './analyzer.mjs';

function argument(name) {
  const index = process.argv.indexOf(name);
  return index === -1 ? '' : process.argv[index + 1] ?? '';
}

const repositoryPath = argument('--repo') || process.cwd();
const changedFiles = argument('--changed-files');
const baseSha = argument('--base');
const headSha = argument('--head') || 'HEAD';

try {
  const files = changedFiles
    ? normalizeChangedFiles(changedFiles)
    : changedFilesFromGit(repositoryPath, baseSha, headSha);
  const result = analyzeRepository({ repositoryPath, changedFiles: files });
  process.stdout.write(JSON.stringify({ ...result, report: markdownReport(result) }, null, 2));
  process.stdout.write('\n');
} catch (error) {
  console.error(error.message);
  process.exitCode = 1;
}
