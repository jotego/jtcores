/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */

package regression

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strings"
	"time"
)

// GiteaPublisher keeps one private issue per tested commit, updating it on
// completion or interruption. Build discovery and downloads still use GitHub.
type GiteaPublisher struct {
	Server, Repository, Token string
	Client                    *http.Client
}

type gitea_issue struct {
	Number int    `json:"number"`
	Body   string `json:"body"`
	URL    string `json:"html_url"`
}

func (p GiteaPublisher) Preflight(BuildIdentity) error {
	if p.Token == "" {
		return fmt.Errorf("GITEA_TOKEN is required for Gitea reports")
	}
	server, err := url.Parse(p.Server)
	if err != nil || server.Host == "" || server.Scheme != "http" && server.Scheme != "https" || server.User != nil || server.RawQuery != "" || server.Fragment != "" {
		return fmt.Errorf("GITEA_SERVER_URL must be an HTTP(S) server URL")
	}
	parts := strings.Split(p.Repository, "/")
	if len(parts) != 2 || !safeComponent(parts[0]) || !safeComponent(parts[1]) {
		return fmt.Errorf("Gitea report repository must be owner/repository")
	}
	var repo struct {
		Name    string `json:"full_name"`
		Private bool   `json:"private"`
	}
	if err = p.request("GET", "", nil, &repo); err != nil {
		return err
	}
	if repo.Name != p.Repository || !repo.Private {
		return fmt.Errorf("Gitea regression reports require the configured private repository")
	}
	return nil
}

func (p GiteaPublisher) Publish(summary Summary, previous string) (string, error) {
	if !valid_commit(summary.RunID) {
		return "", fmt.Errorf("Gitea report requires a full tested commit")
	}
	marker := "<!-- jtutil-regression:" + summary.RunID + " -->"
	number := 0
	if previous != "" {
		expected := strings.TrimRight(p.Server, "/") + "/" + p.Repository + "/issues/"
		if !strings.HasPrefix(previous, expected) {
			return "", fmt.Errorf("saved Gitea report belongs to another destination")
		}
		if _, err := fmt.Sscanf(strings.TrimPrefix(previous, expected), "%d", &number); err != nil || number < 1 || fmt.Sprint(number) != strings.TrimPrefix(previous, expected) {
			return "", fmt.Errorf("invalid saved Gitea report")
		}
	} else {
		// Inspect bodies, including closed issues, so a lost local receipt or
		// an uncertain create response cannot produce a duplicate report.
		for page := 1; ; page++ {
			var issues []gitea_issue
			if err := p.request("GET", fmt.Sprintf("/issues?state=all&type=issues&limit=50&page=%d", page), nil, &issues); err != nil {
				return "", err
			}
			for _, issue := range issues {
				if strings.Contains(issue.Body, marker) {
					number = issue.Number
					break
				}
			}
			if number > 0 || len(issues) == 0 {
				break
			}
		}
	}
	body := formatGitHubSummary(summary, marker)
	payload := map[string]string{"title": "SiDi128 regression: " + summary.RunID[:12], "body": body}
	path, method := "/issues", "POST"
	if number > 0 {
		path += fmt.Sprintf("/%d", number)
		method = "PATCH"
	}
	var issue gitea_issue
	if err := p.request(method, path, payload, &issue); err != nil {
		return "", err
	}
	if issue.Number < 1 {
		return "", fmt.Errorf("Gitea returned an invalid issue")
	}
	// Use the configured host rather than the server's potentially internal
	// ROOT_URL, so saved receipts and links agree on the report destination.
	return strings.TrimRight(p.Server, "/") + "/" + p.Repository + fmt.Sprintf("/issues/%d", issue.Number), nil
}

func (p GiteaPublisher) request(method, path string, payload, result any) error {
	var body io.Reader
	if payload != nil {
		data, err := json.Marshal(payload)
		if err != nil {
			return err
		}
		body = bytes.NewReader(data)
	}
	endpoint := strings.TrimRight(p.Server, "/") + "/api/v1/repos/" + p.Repository + path
	req, err := http.NewRequest(method, endpoint, body)
	if err != nil {
		return err
	}
	req.Header.Set("Authorization", "token "+p.Token)
	req.Header.Set("Accept", "application/json")
	if payload != nil {
		req.Header.Set("Content-Type", "application/json")
	}
	client := p.Client
	if client == nil {
		client = &http.Client{Timeout: 30 * time.Second, CheckRedirect: func(*http.Request, []*http.Request) error { return http.ErrUseLastResponse }}
	}
	response, err := client.Do(req)
	if err != nil {
		return fmt.Errorf("Gitea API request failed: %w", err)
	}
	defer response.Body.Close()
	if response.StatusCode < 200 || response.StatusCode >= 300 {
		return fmt.Errorf("Gitea API %s failed: HTTP %d", method, response.StatusCode)
	}
	if result == nil {
		return nil
	}
	return json.NewDecoder(io.LimitReader(response.Body, 8<<20)).Decode(result)
}

func campaign_complete(root, commit string, cfg Config) bool {
	if cfg.NoPublish || cfg.ReportTarget != "gitea" {
		return commit_complete(root, commit, cfg.NoPublish)
	}
	progress, err := ReadProgress(root, commit)
	return err == nil && progress.AutomaticComplete && progress.GiteaReportComplete && progress.GiteaReportURL != ""
}
