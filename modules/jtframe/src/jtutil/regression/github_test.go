/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */

package regression

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestGitHubPublisherRoutesByOriginDespitePRAssociation(t *testing.T) {
	root := t.TempDir()
	bin := filepath.Join(root, "bin")
	if err := os.MkdirAll(bin, 0750); err != nil {
		t.Fatal(err)
	}
	callLog := filepath.Join(root, "gh-calls")
	script := `#!/bin/sh
printf '%s\n' "$*" >> "$GH_CALLS"
case "$1 $2" in
  "auth status") echo authenticated ;;
  "repo view") echo '{"nameWithOwner":"jotego/jtcores"}' ;;
  "pr view") echo '{"url":"https://github.com/jotego/jtcores/pull/1689","comments":[]}' ;;
  "pr comment") echo 'https://github.com/jotego/jtcores/pull/1689#issuecomment-1' ;;
  "issue list") echo '[]' ;;
  "issue create") echo 'https://github.com/jotego/jtcores/issues/2000' ;;
  *) echo "unexpected gh invocation: $*" >&2; exit 2 ;;
esac
`
	if err := os.WriteFile(filepath.Join(bin, "gh"), []byte(script), 0755); err != nil {
		t.Fatal(err)
	}
	oldPath := os.Getenv("PATH")
	oldCalls, hadCalls := os.LookupEnv("GH_CALLS")
	if err := os.Setenv("PATH", bin+string(os.PathListSeparator)+oldPath); err != nil {
		t.Fatal(err)
	}
	if err := os.Setenv("GH_CALLS", callLog); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() {
		_ = os.Setenv("PATH", oldPath)
		if hadCalls {
			_ = os.Setenv("GH_CALLS", oldCalls)
		} else {
			_ = os.Unsetenv("GH_CALLS")
		}
	})

	cases := []struct {
		name, event, ref, want string
	}{
		{name: "master push with PR association", event: "push", ref: "master", want: "issue create"},
		{name: "dispatched PR branch", event: "workflow_dispatch", ref: "jtcores-166", want: "pr comment"},
		{name: "pull request event", event: "pull_request", ref: "feature", want: "pr comment"},
		{name: "fork PR whose head branch is master", event: "pull_request", ref: "master", want: "pr comment"},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			_ = os.Remove(callLog)
			build := BuildIdentity{Repository: githubRepository, Workflow: compileAllWorkflow, RunID: "run-676", Attempt: "1", SHA: "abc", Ref: tc.ref, Event: tc.event, PR: 1689}
			publisher := GitHubPublisher{TempDir: filepath.Join(root, "publication", tc.name)}
			if err := publisher.Preflight(build); err != nil {
				t.Fatal(err)
			}
			if _, _, err := publisher.Publish(Summary{RunID: "run-676", Build: build}); err != nil {
				t.Fatal(err)
			}
			data, err := os.ReadFile(callLog)
			if err != nil {
				t.Fatal(err)
			}
			calls := string(data)
			if !strings.Contains(calls, tc.want) {
				t.Fatalf("expected %q route, gh calls were:\n%s", tc.want, calls)
			}
			if tc.want == "issue create" && strings.Contains(calls, "pr comment") {
				t.Fatalf("master push was routed to PR despite origin: %s", calls)
			}
			if tc.want == "pr comment" && strings.Contains(calls, "issue create") {
				t.Fatalf("PR build was routed to issue: %s", calls)
			}
		})
	}
}
