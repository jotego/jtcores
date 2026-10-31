/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */

package regression

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"strings"
	"time"
)

const githubRepository = "jotego/jtcores"

type GitHubPublisher struct {
	Timeout time.Duration
	TempDir string
}

func (p GitHubPublisher) Preflight(build BuildIdentity) error {
	if _, e := exec.LookPath("gh"); e != nil {
		return fmt.Errorf("GitHub CLI gh is not installed or not on PATH")
	}
	if _, e := p.run("auth", "status", "--hostname", "github.com"); e != nil {
		return fmt.Errorf("GitHub authentication failed: %w", e)
	}
	out, e := p.run("repo", "view", githubRepository, "--json", "nameWithOwner")
	if e != nil {
		return fmt.Errorf("GitHub repository %s is inaccessible: %w", githubRepository, e)
	}
	var repo struct {
		Name string `json:"nameWithOwner"`
	}
	if e = json.Unmarshal([]byte(out), &repo); e != nil || repo.Name != githubRepository {
		return fmt.Errorf("GitHub repository identity did not resolve to %s", githubRepository)
	}
	if buildReportsToPR(build) {
		if build.PR < 1 {
			return fmt.Errorf("PR build is missing originating pull request number")
		}
		if _, e = p.run("pr", "view", fmt.Sprint(build.PR), "--repo", githubRepository, "--json", "number,url"); e != nil {
			return fmt.Errorf("report PR #%d is inaccessible: %w", build.PR, e)
		}
	} else {
		if build.Ref == "" {
			return fmt.Errorf("master build is missing its tested ref")
		}
	}
	return nil
}

func (p GitHubPublisher) Publish(summary Summary) (string, map[string]any, error) {
	marker := fmt.Sprintf("<!-- jtutil-regression:%s:%s -->", summary.Build.RunID, summary.Build.Attempt)
	if valid_commit(summary.RunID) { marker = "<!-- jtutil-regression:"+summary.RunID+" -->" }
	body := formatGitHubSummary(summary, marker)
	if buildReportsToPR(summary.Build) {
		if summary.Build.PR < 1 {
			return "", nil, fmt.Errorf("missing originating PR number")
		}
		comments, e := p.run("pr", "view", fmt.Sprint(summary.Build.PR), "--repo", githubRepository, "--json", "comments,url")
		if e != nil {
			return "", nil, e
		}
		var parsed struct {
			URL      string `json:"url"`
			Comments []struct {
				Body string `json:"body"`
				URL  string `json:"url"`
			} `json:"comments"`
		}
		if e = json.Unmarshal([]byte(comments), &parsed); e != nil {
			return "", nil, e
		}
		for _, comment := range parsed.Comments {
			if strings.Contains(comment.Body, marker) {
				return comment.URL, map[string]any{"status": "published", "type": "pr-comment", "url": comment.URL, "marker": marker}, nil
			}
		}
		bodyFile, e := writeBodyFile(p.TempDir, summary.RunID, body)
		if e != nil {
			return "", nil, e
		}
		defer os.Remove(bodyFile)
		out, e := p.run("pr", "comment", fmt.Sprint(summary.Build.PR), "--repo", githubRepository, "--body-file", bodyFile)
		if e != nil {
			return "", nil, e
		}
		return parseLastURL(out), map[string]any{"status": "published", "type": "pr-comment", "url": parseLastURL(out), "marker": marker}, nil
	}
	issues, e := p.run("issue", "list", "--repo", githubRepository, "--state", "all", "--limit", "1000", "--search", marker, "--json", "number,title,body,url")
	if e != nil {
		return "", nil, e
	}
	var found []struct {
		Number int    `json:"number"`
		Body   string `json:"body"`
		URL    string `json:"url"`
	}
	if e = json.Unmarshal([]byte(issues), &found); e != nil {
		return "", nil, e
	}
	for _, issue := range found {
		if strings.Contains(issue.Body, marker) {
			return issue.URL, map[string]any{"status": "published", "type": "issue", "number": issue.Number, "url": issue.URL, "marker": marker}, nil
		}
	}
	bodyFile, e := writeBodyFile(p.TempDir, summary.RunID, body)
	if e != nil {
		return "", nil, e
	}
	defer os.Remove(bodyFile)
	label := summary.Build.RunID
	if summary.Build.RunNumber > 0 {
		label = fmt.Sprint(summary.Build.RunNumber)
	}
	title:=fmt.Sprintf("SiDi128 regression: %s #%s", build_workflow_label(summary.Build), label)
	if valid_commit(summary.RunID) {title="SiDi128 regression: "+summary.RunID[:12]}
	out, e := p.run("issue", "create", "--repo", githubRepository, "--title", title, "--body-file", bodyFile)
	if e != nil {
		return "", nil, e
	}
	url := parseLastURL(out)
	return url, map[string]any{"status": "published", "type": "issue", "url": url, "marker": marker}, nil
}

// Pull-request association metadata can also appear on push/workflow runs.
// Only an actual PR event, or an explicitly dispatched run on an associated
// non-master PR branch, should publish a PR comment. Pushes (including master)
// remain issue reports even if GitHub associates a PR with the commit.
func buildReportsToPR(build BuildIdentity) bool {
	if build.Event == "pull_request" || build.Event == "pull_request_target" {
		return true
	}
	return build.Event == "workflow_dispatch" && build.PR > 0 && build.Ref != "master"
}

func (p GitHubPublisher) run(args ...string) (string, error) {
	limit := p.Timeout
	if limit <= 0 {
		limit = 30 * time.Second
	}
	ctx, cancel := context.WithTimeout(context.Background(), limit)
	defer cancel()
	cmd := exec.CommandContext(ctx, "gh", args...)
	var out bytes.Buffer
	cmd.Stdout = &out
	cmd.Stderr = &out
	e := cmd.Run()
	if ctx.Err() == context.DeadlineExceeded {
		return out.String(), fmt.Errorf("gh %s timed out", args[0])
	}
	if e != nil {
		return out.String(), fmt.Errorf("gh %s: %w: %s", args[0], e, strings.TrimSpace(out.String()))
	}
	return out.String(), nil
}

func writeBodyFile(tempDir, runID, body string) (string, error) {
	if strings.ContainsAny(runID, `/\\`) || runID == "" {
		return "", fmt.Errorf("unsafe run id")
	}
	dir := tempDir
	if dir == "" {
		return "", fmt.Errorf("GitHub publication temp directory must be inside regression storage")
	}
	if e := os.MkdirAll(dir, 0700); e != nil {
		return "", e
	}
	f, e := os.CreateTemp(dir, runID+"-*.md")
	if e != nil {
		return "", e
	}
	if _, e = f.WriteString(body); e != nil {
		f.Close()
		os.Remove(f.Name())
		return "", e
	}
	if e = f.Close(); e != nil {
		os.Remove(f.Name())
		return "", e
	}
	return f.Name(), nil
}

func parseLastURL(output string) string {
	for _, field := range strings.Fields(output) {
		if strings.HasPrefix(field, "https://github.com/") {
			return strings.TrimRight(field, ".,")
		}
	}
	return ""
}

func formatGitHubSummary(summary Summary, marker string) string {
	var b strings.Builder
	fmt.Fprintf(&b, "# SiDi128 video regression\n\n%s\n\n", marker)
	label := summary.Build.RunID
	if summary.Build.RunNumber > 0 {
		label = fmt.Sprint(summary.Build.RunNumber)
	}
	if valid_commit(summary.RunID) {fmt.Fprintf(&b,"RBF source commit: `%s`.\n\n",summary.Build.SHA)} else {
		fmt.Fprintf(&b, "Build: %s #%s (run %s, attempt %s), source `%s`, ref `%s`.\n\n", build_workflow_label(summary.Build), label, summary.Build.RunID, summary.Build.Attempt, summary.Build.SHA, summary.Build.Ref)
	}
	fmt.Fprintf(&b, "Duration: %s. Status: **%s**.\n\n", summary.Duration.Round(time.Second), summary.Status)
	fmt.Fprintln(&b, "## Coverage")
	fmt.Fprintln(&b)
	fmt.Fprintln(&b, "| Outcome | Games |\n|---|---:|")
	for _, outcome := range []Outcome{Pass, New, Fail, Error, Unsupported, Pending} {
		if count := summary.Coverage[string(outcome)]; count > 0 {
			fmt.Fprintf(&b, "| %s | %d |\n", outcome, count)
		}
	}
	attention := 0
	for _, game := range summary.Games {
		if game.Outcome == New || game.Outcome == Fail || game.Outcome == Error {
			attention++
		}
	}
	if summary.OperationalError != "" {
		attention++
	}
	fmt.Fprintln(&b)
	if attention == 0 {
		fmt.Fprintln(&b, "No games require attention.")
	} else {
		fmt.Fprintln(&b, "## Games requiring attention")
		fmt.Fprintln(&b)
		for _, game := range summary.Games {
			if game.Outcome == New || game.Outcome == Fail || game.Outcome == Error {
				fmt.Fprintf(&b, "- `%s/%s` — **%s** at %s: %s.\n", game.Core, game.Setname, game.Outcome, game.Stage, game.Message)
			}
		}
		if summary.OperationalError != "" {
			fmt.Fprintf(&b, "- Batch operation: %s.\n", summary.OperationalError)
		}
	}
	fmt.Fprintf(&b, "\nCaptures and execution records are retained under `$JOTEGO/regression` (run `%s`).\n", summary.RunID)
	return b.String()
}

func build_workflow_label(build BuildIdentity) string {
    if build.Workflow==compileSidi128Workflow { return "compile_sidi128" }
    return "compile_all"
}
