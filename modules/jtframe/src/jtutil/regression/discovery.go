/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */

package regression

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
	"time"
)

const compileAllWorkflow = "compile-all.yaml"

var ErrNoEligibleBuild = errors.New("no completed successful compile_all build with a downloadable SiDi128 artifact is available")

type discoveredRun struct {
	DatabaseID         int64     `json:"databaseId"`
	WorkflowName       string    `json:"workflowName"`
	WorkflowDatabaseID int64     `json:"workflowDatabaseId"`
	RunNumber          int64     `json:"number"`
	Status             string    `json:"status"`
	Conclusion         string    `json:"conclusion"`
	HeadSHA            string    `json:"headSha"`
	HeadBranch         string    `json:"headBranch"`
	Event              string    `json:"event"`
	CreatedAt          time.Time `json:"createdAt"`
	Attempt            int       `json:"attempt"`
}

var ghArtifactDownload = func(ctx context.Context, repository string, artifactID int64, destination string) error {
	cmd := exec.CommandContext(ctx, "gh", "api", fmt.Sprintf("repos/%s/actions/artifacts/%d/zip", repository, artifactID))
	out, err := os.Create(destination)
	if err != nil {
		return err
	}
	cmd.Stdout = out
	var stderr strings.Builder
	cmd.Stderr = &stderr
	runErr := cmd.Run()
	closeErr := out.Close()
	if runErr != nil {
		return fmt.Errorf("gh artifact download: %s: %w", strings.TrimSpace(stderr.String()), runErr)
	}
	return closeErr
}

type ghArtifactList struct {
	TotalCount int `json:"total_count"`
	Artifacts  []struct {
		ID      int64  `json:"id"`
		Name    string `json:"name"`
		Expired bool   `json:"expired"`
		Digest  string `json:"digest"`
	} `json:"artifacts"`
}

type apiWorkflowRun struct {
	ID         int64     `json:"id"`
	Name       string    `json:"name"`
	WorkflowID int64     `json:"workflow_id"`
	RunNumber  int64     `json:"run_number"`
	Attempt    int       `json:"run_attempt"`
	Status     string    `json:"status"`
	Conclusion string    `json:"conclusion"`
	HeadSHA    string    `json:"head_sha"`
	HeadBranch string    `json:"head_branch"`
	Event      string    `json:"event"`
	CreatedAt  time.Time `json:"created_at"`
}

// gh is kept behind a small function so build discovery can be tested with a
// deterministic fake executable. Callers should use it only after gh preflight.
var ghCommand = func(ctx context.Context, args ...string) ([]byte, error) {
	cmd := exec.CommandContext(ctx, "gh", args...)
	out, err := cmd.Output()
	if err != nil {
		if ee, ok := err.(*exec.ExitError); ok {
			return nil, fmt.Errorf("gh %s: %s: %w", strings.Join(args, " "), strings.TrimSpace(string(ee.Stderr)), err)
		}
		return nil, fmt.Errorf("gh %s: %w", strings.Join(args, " "), err)
	}
	return out, nil
}

func discoverBuild(ctx context.Context, repository, runID string) (BuildIdentity, error) {
	return discoverBuildIn(ctx, repository, runID, "")
}

func discoverBuildIn(ctx context.Context, repository, runID, dataRoot string) (BuildIdentity, error) {
	return discover_build(ctx, repository, runID, dataRoot, Config{})
}

func discover_build(ctx context.Context, repository, runID, dataRoot string, cfg Config) (BuildIdentity, error) {
	var since time.Time
	if cfg.BuildsSince != "" {
		var err error
		since, err = time.Parse(time.RFC3339, cfg.BuildsSince)
		if err != nil { return BuildIdentity{}, fmt.Errorf("builds-since must be an RFC3339 timestamp: %w", err) }
	}
	if repository == "" {
		repository = "jotego/jtcores"
	}
	if repository != "jotego/jtcores" {
		return BuildIdentity{}, fmt.Errorf("regression build discovery requires repository jotego/jtcores")
	}
	if runID != "" {
		id, err := strconv.ParseInt(runID, 10, 64)
		if err != nil {
			return BuildIdentity{}, fmt.Errorf("run id %q must be a GitHub Actions numeric run id", runID)
		}
		if identity, e := getEligibleRun(ctx, repository, id); e == nil {
			return identity, nil
		} else if !isRunIDNotFound(e) {
			// A real database ID may fail eligibility, artifact lookup, or API
			// access. Preserve that diagnosis rather than reinterpreting it as a
			// human run-number selector.
			return BuildIdentity{}, e
		}
		return getEligibleRunByNumber(ctx, repository, id)
	}
	runs, err := listWorkflowRuns(ctx, repository)
	if err != nil {
		return BuildIdentity{}, err
	}
	// Oldest-first backlog policy, but only choose a fully successful attempt.
	sort.Slice(runs, func(i, j int) bool {
		if runs[i].CreatedAt.Equal(runs[j].CreatedAt) {
			return runs[i].DatabaseID < runs[j].DatabaseID
		}
		return runs[i].CreatedAt.Before(runs[j].CreatedAt)
	})
	for _, r := range runs {
		if r.CreatedAt.Before(since) { continue }
		if r.DatabaseID == 0 || !strings.EqualFold(r.WorkflowName, "Compile all") || r.Status != "completed" || r.Conclusion != "success" || r.HeadSHA == "" {
			continue
		}
		if commit_complete(dataRoot, r.HeadSHA, cfg.NoPublish) {
			continue
		}
		id, err := getEligibleRun(ctx, repository, r.DatabaseID)
		if err == nil {
			return id, nil
		}
		// A successful run with no artifact is not processed; keep looking for an
		// eligible build and leave the candidate for the next polling invocation.
	}
	return BuildIdentity{}, ErrNoEligibleBuild
}

func getEligibleRun(ctx context.Context, repository string, runID int64) (BuildIdentity, error) {
	data, err := ghCommand(ctx, "run", "view", strconv.FormatInt(runID, 10), "--repo", repository, "--json", "databaseId,workflowName,workflowDatabaseId,number,attempt,status,conclusion,headSha,headBranch,event,createdAt,jobs")
	if err != nil {
		return BuildIdentity{}, fmt.Errorf("inspect workflow run %d: %w", runID, err)
	}
	var run struct {
		discoveredRun
		Jobs []struct {
			Conclusion string `json:"conclusion"`
			Status     string `json:"status"`
		} `json:"jobs"`
	}
	if err = json.Unmarshal(data, &run); err != nil {
		return BuildIdentity{}, fmt.Errorf("parse workflow run %d: %w", runID, err)
	}
	r := run.discoveredRun
	if r.DatabaseID != runID {
		return BuildIdentity{}, fmt.Errorf("workflow run lookup for %d returned database id %d", runID, r.DatabaseID)
	}
	if !strings.EqualFold(r.WorkflowName, "Compile all") || r.Status != "completed" || r.Conclusion != "success" || r.HeadSHA == "" || r.Attempt <= 0 {
		return BuildIdentity{}, fmt.Errorf("workflow run %d is not a completed successful compile_all attempt", runID)
	}
	if len(run.Jobs) == 0 {
		return BuildIdentity{}, fmt.Errorf("workflow run %d has no job completion inventory", runID)
	}
	for _, j := range run.Jobs {
		if j.Status != "completed" || j.Conclusion != "success" {
			return BuildIdentity{}, fmt.Errorf("workflow run %d includes an incomplete or failed job", runID)
		}
	}
	artifactData, err := ghCommand(ctx, "api", fmt.Sprintf("repos/%s/actions/runs/%d/artifacts", repository, runID))
	if err != nil {
		return BuildIdentity{}, fmt.Errorf("list artifacts for run %d attempt %d: %w", runID, r.Attempt, err)
	}
	var artifacts ghArtifactList
	if err = json.Unmarshal(artifactData, &artifacts); err != nil {
		return BuildIdentity{}, fmt.Errorf("parse artifacts for run %d: %w", runID, err)
	}
	var selected *struct {
		ID      int64  `json:"id"`
		Name    string `json:"name"`
		Expired bool   `json:"expired"`
		Digest  string `json:"digest"`
	}
	for i := range artifacts.Artifacts {
		a := &artifacts.Artifacts[i]
		if a.Expired {
			continue
		}
		expected := strings.ToLower(r.HeadSHA[:7]) + ".zip"
		if strings.EqualFold(a.Name, expected) || strings.EqualFold(a.Name, "sidi128") {
			if selected == nil || strings.EqualFold(a.Name, expected) {
				selected = a
			}
		}
	}
	if selected == nil {
		return BuildIdentity{}, fmt.Errorf("workflow run %d (selected attempt %d) has no unexpired build artifact", runID, r.Attempt)
	}
	if selected.ID <= 0 || strings.TrimSpace(selected.Digest) == "" {
		return BuildIdentity{}, fmt.Errorf("workflow run %d (selected attempt %d) artifact %q has no immutable ID or digest", runID, r.Attempt, selected.Name)
	}
	pr := 0
	var associationErr error
	var prData struct {
		PullRequests []struct {
			Number int `json:"number"`
		} `json:"pull_requests"`
	}
	if raw, e := ghCommand(ctx, "api", fmt.Sprintf("repos/%s/actions/runs/%d", repository, runID)); e != nil {
		associationErr = e
	} else if e = json.Unmarshal(raw, &prData); e != nil {
		associationErr = fmt.Errorf("decode workflow run PR association: %w", e)
	} else if len(prData.PullRequests) > 0 {
		pr = prData.PullRequests[0].Number
	}
	if pr == 0 && r.Event == "workflow_dispatch" && r.HeadBranch != "" && r.HeadBranch != "master" {
		var lookupErr error
		pr, lookupErr = pullRequestForCommit(ctx, repository, r.HeadSHA, r.HeadBranch)
		if lookupErr != nil {
			return BuildIdentity{}, fmt.Errorf("resolve originating pull request for dispatched branch %s: %w", r.HeadBranch, lookupErr)
		}
		if pr == 0 && associationErr != nil {
			return BuildIdentity{}, fmt.Errorf("resolve originating pull request for dispatched branch %s: %w", r.HeadBranch, associationErr)
		}
	}
	return BuildIdentity{Repository: repository, Workflow: compileAllWorkflow, WorkflowID: r.WorkflowDatabaseID, RunID: strconv.FormatInt(runID, 10), RunNumber: r.RunNumber, Attempt: strconv.Itoa(r.Attempt), SHA: r.HeadSHA, Ref: r.HeadBranch, Event: r.Event, PR: pr, Artifact: selected.Name, ArtifactID: selected.ID, ArtifactAPIHash: strings.TrimPrefix(selected.Digest, "sha256:"), Conclusion: r.Conclusion, ExpectedJobs: len(run.Jobs), SucceededJobs: len(run.Jobs)}, nil
}

func pullRequestForCommit(ctx context.Context, repository, sha, branch string) (int, error) {
	if sha == "" || branch == "" {
		return 0, fmt.Errorf("commit SHA and branch are required for PR association lookup")
	}
	raw, err := ghCommand(ctx, "api", fmt.Sprintf("repos/%s/commits/%s/pulls", repository, sha))
	if err != nil {
		return 0, err
	}
	var candidates []struct {
		Number int `json:"number"`
		Head   struct {
			Ref string `json:"ref"`
			SHA string `json:"sha"`
		} `json:"head"`
	}
	if err := json.Unmarshal(raw, &candidates); err != nil {
		return 0, fmt.Errorf("decode commit PR association: %w", err)
	}
	match, count := 0, 0
	for _, candidate := range candidates {
		if candidate.Number > 0 && candidate.Head.Ref == branch {
			match, count = candidate.Number, count+1
			if candidate.Head.SHA == sha {
				return candidate.Number, nil
			}
		}
	}
	if count == 1 {
		return match, nil
	}
	return 0, nil
}

func isRunIDNotFound(err error) bool {
	if err == nil {
		return false
	}
	message := strings.ToLower(err.Error())
	return strings.Contains(message, "http 404") || strings.Contains(message, "404 not found") || strings.Contains(message, "status: 404")
}

func getEligibleRunByNumber(ctx context.Context, repository string, number int64) (BuildIdentity, error) {
	runs, err := listWorkflowRuns(ctx, repository)
	if err != nil {
		return BuildIdentity{}, err
	}
	for _, r := range runs {
		if r.RunNumber == number {
			return getEligibleRun(ctx, repository, r.DatabaseID)
		}
	}
	return BuildIdentity{}, fmt.Errorf("no compile_all run has run number %d", number)
}

func listWorkflowRuns(ctx context.Context, repository string) ([]discoveredRun, error) {
	endpoint := fmt.Sprintf("repos/%s/actions/workflows/%s/runs?per_page=100", repository, compileAllWorkflow)
	data, err := ghCommand(ctx, "api", "--paginate", "--slurp", endpoint)
	if err != nil {
		return nil, fmt.Errorf("list compile_all runs: %w", err)
	}
	var pages []struct {
		WorkflowRuns []apiWorkflowRun `json:"workflow_runs"`
	}
	if err = json.Unmarshal(data, &pages); err != nil {
		return nil, fmt.Errorf("parse paginated compile_all run list: %w", err)
	}
	runs := make([]discoveredRun, 0)
	for _, page := range pages {
		for _, r := range page.WorkflowRuns {
			runs = append(runs, discoveredRun{DatabaseID: r.ID, WorkflowName: r.Name, WorkflowDatabaseID: r.WorkflowID, RunNumber: r.RunNumber, Attempt: r.Attempt, Status: r.Status, Conclusion: r.Conclusion, HeadSHA: r.HeadSHA, HeadBranch: r.HeadBranch, Event: r.Event, CreatedAt: r.CreatedAt})
		}
	}
	return runs, nil
}

func buildAlreadyComplete(root, runID, attempt string, local_only ...bool) bool {
	if root == "" {
		return false
	}
	// Only the canonical full campaign can complete a build; partial pilots and
	// manual retakes must never suppress the automatic inventory.
	path := filepath.Join(root, "log", runID+"-attempt-"+attempt, "summary.json")
	raw, err := os.ReadFile(path)
	if err != nil { return false }
	var summary Summary
	if json.Unmarshal(raw, &summary) != nil || summary.Build.RunID != runID || summary.Build.Attempt != attempt { return false }
	if summary.Status == "complete" { return true }
	if len(local_only)==0 || !local_only[0] || summary.Status != "publication-pending" || summary.OperationalError != "" || len(summary.Games)==0 { return false }
	for _, game := range summary.Games {
		switch game.Outcome {
		case Pass, New, Fail, Error, Unsupported:
		default: return false
		}
	}
	return true
}

// DiscoverBuild selects transport metadata; durable regression identity is SHA.
func DiscoverBuild(ctx context.Context, cfg Config, root, selector string) (BuildIdentity, error) {
	return discover_build(ctx, cfg.Repository, selector, root, cfg)
}
