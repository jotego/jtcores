/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */
package regression

import (
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestGiteaReportCreateResumeAndCompletion(t *testing.T) {
	commit := strings.Repeat("a", 40)
	body := ""
	creates, updates := 0, 0
	scanned_second := false
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("Authorization") != "token secret" {
			t.Error("missing authentication")
			w.WriteHeader(401)
			return
		}
		switch {
		case r.URL.Path == "/api/v1/repos/jotego/jtcores":
			fmt.Fprint(w, `{"full_name":"jotego/jtcores","private":true}`)
		case r.Method == "GET":
			if body == "" {
				fmt.Fprint(w, `[]`)
			} else if r.URL.Query().Get("page") == "1" {
				fmt.Fprint(w, `[{"number":9,"body":"unrelated"}]`)
			} else {
				scanned_second = true
				json.NewEncoder(w).Encode([]gitea_issue{{Number: 42, Body: body}})
			}
		case r.Method == "POST":
			creates++
			var data map[string]string
			json.NewDecoder(r.Body).Decode(&data)
			body = data["body"]
			fmt.Fprint(w, `{"number":42}`)
		case r.Method == "PATCH" && r.URL.Path == "/api/v1/repos/jotego/jtcores/issues/42":
			updates++
			var data map[string]string
			json.NewDecoder(r.Body).Decode(&data)
			body = data["body"]
			fmt.Fprint(w, `{"number":42}`)
		default:
			t.Errorf("unexpected request %s %s", r.Method, r.URL)
			w.WriteHeader(500)
		}
	}))
	defer server.Close()
	p := GiteaPublisher{Server: server.URL, Repository: "jotego/jtcores", Token: "secret"}
	if err := p.Preflight(BuildIdentity{}); err != nil {
		t.Fatal(err)
	}
	summary := Summary{RunID: commit, Build: BuildIdentity{SHA: commit}, Status: "preparing", Coverage: map[string]int{}}
	link, err := p.Publish(summary, "")
	if err != nil {
		t.Fatal(err)
	}
	summary.Status = "interrupted"
	summary.OperationalError = "capture cancelled"
	resumed, err := p.Publish(summary, "")
	if err != nil {
		t.Fatal(err)
	}
	if resumed != link || !strings.Contains(body, "interrupted") || !scanned_second {
		t.Fatal("lost receipt did not find/update existing issue across pages")
	}
	summary.Status = "complete"
	summary.OperationalError = ""
	summary.Coverage["pass"] = 1
	if _, err = p.Publish(summary, link); err != nil {
		t.Fatal(err)
	}
	if creates != 1 || updates != 2 || !strings.Contains(body, "**complete**") || !strings.Contains(body, "| pass | 1 |") {
		t.Fatal("completion was not published to the original issue")
	}
	if _, err = p.Publish(summary, "https://other.invalid/jotego/jtcores/issues/42"); err == nil {
		t.Fatal("foreign report destination accepted")
	}
}

func TestGiteaRejectsPublicRepoAndHTTPFailures(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method == "GET" {
			fmt.Fprint(w, `{"full_name":"jotego/jtcores","private":false}`)
		} else {
			w.WriteHeader(403)
			fmt.Fprint(w, "private server diagnostic or secret")
		}
	}))
	defer server.Close()
	p := GiteaPublisher{Server: server.URL, Repository: "jotego/jtcores", Token: "secret"}
	if err := p.Preflight(BuildIdentity{}); err == nil {
		t.Fatal("public report destination allowed")
	}
	_, err := p.Publish(Summary{RunID: strings.Repeat("b", 40)}, server.URL+"/jotego/jtcores/issues/1")
	if err == nil || !strings.Contains(err.Error(), "403") || strings.Contains(err.Error(), "secret") {
		t.Fatal("unsafe or missing API error")
	}
}

func TestGiteaCompletionIsIndependentOfGitHub(t *testing.T) {
	record, _, _, _ := compact_fixture(t)
	record.Progress.AutomaticComplete = true
	record.Progress.Games = map[string]ProgressGame{"fake/test": {Result: Pass}}
	record.Progress.ReportURL = "https://github.com/report"
	record.Save()
	cfg := Config{ReportTarget: "gitea"}
	if campaign_complete(record.Root, record.Progress.Commit, cfg) {
		t.Fatal("GitHub receipt suppressed Gitea report")
	}
	record.Progress.GiteaReportURL = "http://gitea.test/issue/1"
	record.Save()
	if campaign_complete(record.Root, record.Progress.Commit, cfg) {
		t.Fatal("initial report treated as final")
	}
	record.Progress.GiteaReportComplete = true
	record.Save()
	if !campaign_complete(record.Root, record.Progress.Commit, cfg) {
		t.Fatal("Gitea completion not remembered")
	}
}
