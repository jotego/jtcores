package cmd

import (
	"bytes"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"testing"
	"time"
)

func Test_gh_build_target_slug(t *testing.T) {
	slug, e := gh_build_target_slug([]string{"mister", "pocket"})
	if e != nil {
		t.Fatal(e)
	}
	if slug != "mister-pocket" {
		t.Fatalf("unexpected slug: %s", slug)
	}
	slug, e = gh_build_target_slug([]string{"sidi", "sidi128"})
	if e != nil {
		t.Fatal(e)
	}
	if slug != "sidi-sidi128" {
		t.Fatalf("unexpected slug: %s", slug)
	}
}

func Test_gh_build_target_slug_allows_mist_combo(t *testing.T) {
	slug, e := gh_build_target_slug([]string{"mist", "mister"})
	if e != nil {
		t.Fatal(e)
	}
	if slug != "mist-mister" {
		t.Fatalf("unexpected slug: %s", slug)
	}
}

func Test_new_gh_build_config(t *testing.T) {
	root := t.TempDir()
	t.Setenv("JTROOT", root)
	cfg, e := new_gh_build_config([]string{"cps3"}, []string{"mister", "pocket"})
	if e != nil {
		t.Fatal(e)
	}
	if cfg.release != filepath.Join(root, "release") {
		t.Fatalf("unexpected release folder: %s", cfg.release)
	}
}

func Test_new_gh_build_config_requires_jtroot(t *testing.T) {
	t.Setenv("JTROOT", "")
	_, e := new_gh_build_config([]string{"cps3"}, []string{"mister"})
	if e == nil {
		t.Fatalf("expected missing JTROOT error")
	}
}

func Test_gh_build_run_id(t *testing.T) {
	id, e := gh_build_run_id("https://github.com/jotego/jtcores/actions/runs/123456789\n")
	if e != nil {
		t.Fatal(e)
	}
	if id != "123456789" {
		t.Fatalf("unexpected run id: %s", id)
	}
}

func Test_gh_build_run_id_rejects_missing_url(t *testing.T) {
	_, e := gh_build_run_id(filepath.Join("no", "url", "here"))
	if e == nil {
		t.Fatalf("expected missing run id error")
	}
}

func Test_gh_build_run_invokes_gh_sequence(t *testing.T) {
	tmp := t.TempDir()
	root := filepath.Join(tmp, "jtroot")
	log := filepath.Join(tmp, "gh.log")
	fake_gh := filepath.Join(tmp, "gh")
	script := "#!/bin/sh\nprintf '%s\\n' \"$*\" >> \"$GH_LOG\"\ncase \"$1 $2\" in\n  \"workflow run\") echo https://github.com/jotego/jtcores/actions/runs/42 ;;\n  \"run view\") echo '{\"status\":\"queued\",\"conclusion\":\"\",\"jobs\":[]}' ;;\nesac\n"
	e := os.WriteFile(fake_gh, []byte(script), 0775)
	if e != nil {
		t.Fatal(e)
	}
	t.Setenv("PATH", tmp+":"+os.Getenv("PATH"))
	t.Setenv("GH_LOG", log)
	t.Setenv("JTROOT", root)
	gh_build_ref = ""
	cfg, e := new_gh_build_config([]string{"cps3", "gng"}, []string{"mister", "pocket"})
	if e != nil {
		t.Fatal(e)
	}
	e = cfg.run()
	if e != nil {
		t.Fatal(e)
	}
	buf, e := os.ReadFile(log)
	if e != nil {
		t.Fatal(e)
	}
	got := string(buf)
	for _, expected := range []string{
		"workflow run compile-custom.yaml -f core=cps3,gng -f target=mister,pocket",
		"run watch 42 --compact --exit-status --interval 10",
		"run download 42 -n release-mister-cps3 -D " + filepath.Join(root, "release"),
		"run download 42 -n release-pocket-cps3 -D " + filepath.Join(root, "release"),
		"run download 42 -n release-mister-gng -D " + filepath.Join(root, "release"),
		"run download 42 -n release-pocket-gng -D " + filepath.Join(root, "release"),
	} {
		if !strings.Contains(got, expected) {
			t.Fatalf("missing gh call %q in:\n%s", expected, got)
		}
	}
	if _, e := os.Stat(filepath.Join(root, "release")); e != nil {
		t.Fatalf("release folder was not created: %v", e)
	}
}

func Test_gh_build_batch_uses_run_view(t *testing.T) {
	tmp := t.TempDir()
	root := filepath.Join(tmp, "jtroot")
	log := filepath.Join(tmp, "gh.log")
	fake_gh := filepath.Join(tmp, "gh")
	script := "#!/bin/sh\nprintf '%s\\n' \"$*\" >> \"$GH_LOG\"\ncase \"$1 $2\" in\n  \"workflow run\") echo https://github.com/jotego/jtcores/actions/runs/42 ;;\n  \"run view\") echo '{\"status\":\"completed\",\"conclusion\":\"success\",\"jobs\":[{\"name\":\"compile (cps3, mister)\",\"status\":\"completed\",\"conclusion\":\"success\"}]}' ;;\nesac\n"
	e := os.WriteFile(fake_gh, []byte(script), 0775)
	if e != nil {
		t.Fatal(e)
	}
	t.Setenv("PATH", tmp+":"+os.Getenv("PATH"))
	t.Setenv("GH_LOG", log)
	t.Setenv("JTROOT", root)
	gh_build_ref = ""
	gh_build_batch = true
	defer func() { gh_build_batch = false }()
	cfg, e := new_gh_build_config([]string{"cps3"}, []string{"mister"})
	if e != nil {
		t.Fatal(e)
	}
	e = cfg.run()
	if e != nil {
		t.Fatal(e)
	}
	buf, e := os.ReadFile(log)
	if e != nil {
		t.Fatal(e)
	}
	got := string(buf)
	for _, expected := range []string{
		"workflow run compile-custom.yaml -f core=cps3 -f target=mister",
		"run view 42 --json status,conclusion,jobs",
		"run download 42 -n release-mister-cps3 -D " + filepath.Join(root, "release"),
	} {
		if !strings.Contains(got, expected) {
			t.Fatalf("missing gh call %q in:\n%s", expected, got)
		}
	}
	if strings.Contains(got, "run watch") {
		t.Fatalf("batch mode should not call gh run watch:\n%s", got)
	}
}

func Test_gh_build_target_flag_parses_comma_list(t *testing.T) {
	gh_build_targets = nil
	ghBuildCmd.SetOut(&bytes.Buffer{})
	ghBuildCmd.SetErr(&bytes.Buffer{})
	ghBuildCmd.SetArgs([]string{"-t", "mister,pocket", "cps3", "gng"})
	e := ghBuildCmd.ParseFlags([]string{"-t", "mister,pocket"})
	if e != nil {
		t.Fatal(e)
	}
	if strings.Join(gh_build_targets, ",") != "mister,pocket" {
		t.Fatalf("unexpected target flag parse: %#v", gh_build_targets)
	}
}

// gh_build_fake_404 installs a fake gh whose first `fails` calls to
// `run view` print a 404 error. Later calls report a successful run.
func gh_build_fake_404(t *testing.T, fails int, errmsg string) (string, string) {
	t.Helper()
	tmp := t.TempDir()
	root := filepath.Join(tmp, "jtroot")
	log := filepath.Join(tmp, "gh.log")
	count := filepath.Join(tmp, "count")
	fake_gh := filepath.Join(tmp, "gh")
	script := `#!/bin/sh
printf '%s\n' "$*" >> "$GH_LOG"
case "$1 $2" in
  "workflow run") echo https://github.com/jotego/jtcores/actions/runs/42 ;;
  "run view")
    n=$(cat "$GH_COUNT" 2>/dev/null || echo 0)
    n=$((n+1))
    echo $n > "$GH_COUNT"
    if [ $n -le $GH_FAILS ]; then
      echo "$GH_ERR" >&2
      exit 1
    fi
    echo '{"status":"completed","conclusion":"success","jobs":[{"name":"compile (cps3, mister)","status":"completed","conclusion":"success"}]}' ;;
esac
`
	if e := os.WriteFile(fake_gh, []byte(script), 0775); e != nil {
		t.Fatal(e)
	}
	t.Setenv("PATH", tmp+":"+os.Getenv("PATH"))
	t.Setenv("GH_LOG", log)
	t.Setenv("GH_COUNT", count)
	t.Setenv("GH_FAILS", strconv.Itoa(fails))
	t.Setenv("GH_ERR", errmsg)
	t.Setenv("JTROOT", root)
	gh_build_ref = ""
	old_timeout, old_interval := gh_build_find_timeout, gh_build_find_interval
	gh_build_find_timeout, gh_build_find_interval = 2*time.Second, 10*time.Millisecond
	t.Cleanup(func() { gh_build_find_timeout, gh_build_find_interval = old_timeout, old_interval })
	return root, log
}

const gh_build_404_msg = "HTTP 404: Not Found (https://api.github.com/repos/jotego/jtcores/actions/runs/42/jobs?per_page=100)"

func Test_gh_build_retries_transient_404(t *testing.T) {
	for _, batch := range []bool{true, false} {
		root, log := gh_build_fake_404(t, 2, gh_build_404_msg)
		gh_build_batch = batch
		cfg, e := new_gh_build_config([]string{"cps3"}, []string{"mister"})
		gh_build_batch = false
		if e != nil {
			t.Fatal(e)
		}
		if e = cfg.run(); e != nil {
			t.Fatalf("batch=%v: %v", batch, e)
		}
		buf, e := os.ReadFile(log)
		if e != nil {
			t.Fatal(e)
		}
		got := string(buf)
		if n := strings.Count(got, "run view 42"); n != 3 {
			t.Fatalf("batch=%v: expected 3 run view calls, got %d:\n%s", batch, n, got)
		}
		if !strings.Contains(got, "run download 42 -n release-mister-cps3 -D "+filepath.Join(root, "release")) {
			t.Fatalf("batch=%v: artifact not downloaded:\n%s", batch, got)
		}
		if batch == strings.Contains(got, "run watch") {
			t.Fatalf("batch=%v: unexpected run watch usage:\n%s", batch, got)
		}
	}
}

func Test_gh_build_persistent_404_times_out(t *testing.T) {
	_, log := gh_build_fake_404(t, 9, gh_build_404_msg)
	gh_build_find_timeout = 50 * time.Millisecond
	cfg, e := new_gh_build_config([]string{"cps3"}, []string{"mister"})
	if e != nil {
		t.Fatal(e)
	}
	e = cfg.run()
	if e == nil || !strings.Contains(e.Error(), "not found") {
		t.Fatalf("expected not found error, got %v", e)
	}
	buf, _ := os.ReadFile(log)
	if strings.Contains(string(buf), "run download") {
		t.Fatalf("should not download after failure:\n%s", buf)
	}
}

func Test_gh_build_other_errors_fail_at_once(t *testing.T) {
	_, log := gh_build_fake_404(t, 9, "HTTP 401: Bad credentials")
	cfg, e := new_gh_build_config([]string{"cps3"}, []string{"mister"})
	if e != nil {
		t.Fatal(e)
	}
	if e = cfg.run(); e == nil {
		t.Fatalf("expected error")
	}
	buf, _ := os.ReadFile(log)
	if n := strings.Count(string(buf), "run view 42"); n != 1 {
		t.Fatalf("expected a single run view call, got %d:\n%s", n, buf)
	}
}
