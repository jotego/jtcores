package cmd

import (
	"bytes"
	"os"
	"path/filepath"
	"strings"
	"testing"
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

func Test_gh_build_target_slug_rejects_mist_combo(t *testing.T) {
	_, e := gh_build_target_slug([]string{"mist", "mister"})
	if e == nil {
		t.Fatalf("expected mist combo rejection")
	}
}

func Test_new_gh_build_config(t *testing.T) {
	root := t.TempDir()
	t.Setenv("JTROOT", root)
	cfg, e := new_gh_build_config("cps3", []string{"mister", "pocket"})
	if e != nil {
		t.Fatal(e)
	}
	if cfg.artifact != "release-mister-pocket-cps3" {
		t.Fatalf("unexpected artifact name: %s", cfg.artifact)
	}
	if cfg.jtroot != root {
		t.Fatalf("unexpected JTROOT: %s", cfg.jtroot)
	}
}

func Test_new_gh_build_config_requires_jtroot(t *testing.T) {
	t.Setenv("JTROOT", "")
	_, e := new_gh_build_config("cps3", []string{"mister"})
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
	script := "#!/bin/sh\nprintf '%s\\n' \"$*\" >> \"$GH_LOG\"\nif [ \"$1 $2\" = \"workflow run\" ]; then echo https://github.com/jotego/jtcores/actions/runs/42; fi\n"
	e := os.WriteFile(fake_gh, []byte(script), 0775)
	if e != nil {
		t.Fatal(e)
	}
	t.Setenv("PATH", tmp+":"+os.Getenv("PATH"))
	t.Setenv("GH_LOG", log)
	t.Setenv("JTROOT", root)
	gh_build_ref = ""
	cfg, e := new_gh_build_config("cps3", []string{"mister", "pocket"})
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
		"workflow run compile-one.yaml -f core=cps3 -f target=mister,pocket",
		"run watch 42 --compact --exit-status",
		"run download 42 -n release-mister-pocket-cps3 -D " + root,
	} {
		if !strings.Contains(got, expected) {
			t.Fatalf("missing gh call %q in:\n%s", expected, got)
		}
	}
}

func Test_gh_build_target_flag_parses_comma_list(t *testing.T) {
	gh_build_targets = nil
	ghBuildCmd.SetOut(&bytes.Buffer{})
	ghBuildCmd.SetErr(&bytes.Buffer{})
	ghBuildCmd.SetArgs([]string{"-t", "mister,pocket", "cps3"})
	e := ghBuildCmd.ParseFlags([]string{"-t", "mister,pocket"})
	if e != nil {
		t.Fatal(e)
	}
	if strings.Join(gh_build_targets, ",") != "mister,pocket" {
		t.Fatalf("unexpected target flag parse: %#v", gh_build_targets)
	}
}
