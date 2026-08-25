import fs from 'node:fs';
import path from 'node:path';
import {
  analyzeRepository,
  changedFilesFromGit,
  markdownReport,
  normalizeChangedFiles,
  pullRequestComment,
  syncPullRequestComment,
} from './analyzer.mjs';

function input(name, fallback = '') {
  return process.env[`INPUT_${name.toUpperCase().replaceAll('-', '_')}`] ?? fallback;
}

function setOutput(name, value) {
  const serialized = String(value);
  const outputPath = process.env.GITHUB_OUTPUT;
  if (!outputPath) return;
  const marker = `affected_cores_${name.replaceAll('-', '_')}`;
  fs.appendFileSync(outputPath, `${name}<<${marker}\n${serialized}\n${marker}\n`);
}

try {
  const repositoryPath = path.resolve(input('repository-path', '.'));
  const suppliedFiles = input('changed-files');
  const changedFiles = suppliedFiles.trim()
    ? normalizeChangedFiles(suppliedFiles)
    : changedFilesFromGit(repositoryPath, input('base-sha'), input('head-sha', 'HEAD'));
  const result = analyzeRepository({ repositoryPath, changedFiles });
  const report = markdownReport(result);

  setOutput('affected-cores', JSON.stringify(result.affected));
  setOutput('affected-core-names', JSON.stringify(result.affectedCoreNames));
  setOutput('unmatched-files', JSON.stringify(result.unmatchedFiles));
  setOutput('unresolved-cores', JSON.stringify(result.unresolvedCores));
  setOutput('report', report);

  process.stdout.write(report);
  for (const { core, error } of result.unresolvedCores) {
    process.stdout.write(`::warning title=JTFRAME file list unavailable::${core}: ${error}\n`);
  }
  if (process.env.GITHUB_STEP_SUMMARY) fs.appendFileSync(process.env.GITHUB_STEP_SUMMARY, report);

  const token = input('github-token');
  const repository = input('repository', process.env.GITHUB_REPOSITORY ?? '');
  const pullRequestNumber = input('pull-request-number');
  if (token && repository && pullRequestNumber) {
    const comment = await syncPullRequestComment({
      token,
      repository,
      pullRequestNumber,
      body: pullRequestComment(result),
      hasAffectedCores: result.affectedCoreNames.length > 0,
      apiUrl: input('github-api-url', process.env.GITHUB_API_URL ?? 'https://api.github.com'),
    });
    setOutput('pull-request-comment-id', comment.id);
    setOutput('pull-request-comment-status', comment.status);
    process.stdout.write(`Pull-request comment: ${comment.status}${comment.id ? ` (${comment.id})` : ''}.\n`);
  }
} catch (error) {
  console.error(`::error::${error.message}`);
  process.exitCode = 1;
}
