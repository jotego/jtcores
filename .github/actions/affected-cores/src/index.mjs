import fs from 'node:fs';
import path from 'node:path';
import {
  analyzeRepository,
  actionInput,
  changedFilesFromGit,
  markdownReport,
  normalizeChangedFiles,
  pullRequestComment,
} from './analyzer.mjs';

function setOutput(name, value) {
  const serialized = String(value);
  const outputPath = process.env.GITHUB_OUTPUT;
  if (!outputPath) return;
  const marker = `affected_cores_${name.replaceAll('-', '_')}`;
  fs.appendFileSync(outputPath, `${name}<<${marker}\n${serialized}\n${marker}\n`);
}

try {
  const repositoryPath = path.resolve(actionInput('repository-path', process.env, '.'));
  const suppliedFiles = actionInput('changed-files');
  const changedFiles = suppliedFiles.trim()
    ? normalizeChangedFiles(suppliedFiles)
    : changedFilesFromGit(
      repositoryPath,
      actionInput('base-sha'),
      actionInput('head-sha', process.env, 'HEAD'),
    );
  const result = analyzeRepository({ repositoryPath, changedFiles });
  const report = markdownReport(result);

  setOutput('affected-cores', JSON.stringify(result.affected));
  setOutput('affected-core-names', JSON.stringify(result.affectedCoreNames));
  setOutput('unmatched-files', JSON.stringify(result.unmatchedFiles));
  setOutput('unresolved-cores', JSON.stringify(result.unresolvedCores));
  setOutput('report', report);
  setOutput('pull-request-comment', pullRequestComment(result));

  process.stdout.write(report);
  for (const { core, error } of result.unresolvedCores) {
    process.stdout.write(`::warning title=JTFRAME file list unavailable::${core}: ${error}\n`);
  }
  if (process.env.GITHUB_STEP_SUMMARY) fs.appendFileSync(process.env.GITHUB_STEP_SUMMARY, report);
} catch (error) {
  console.error(`::error::${error.message}`);
  process.exitCode = 1;
}
