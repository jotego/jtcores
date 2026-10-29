package cmd

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestSeedExportPrefersPassingOutput(t *testing.T) {
	root := seed_export_root(t)
	cfg := seed_export_config(root, true)
	failed := seed_export_job(t, 0, "failed-seed", false, "3.995", "-0.084", "10.732", true)
	passed := seed_export_job(t, 17944, "passing-seed", true, "3.614", "0.113", "10.865", true)
	later_failed := seed_export_job(t, 42, "later-failed-seed", false, "4.500", "-0.200", "11.000", true)
	for _, job := range []seed_job{failed, passed, later_failed} {
		if _, e := cfg.copy_if_best(job, job.worst_slack()); e != nil {
			t.Fatal(e)
		}
	}
	if e := cfg.finish_trials(); e != nil {
		t.Fatal(e)
	}
	seed_export_check_release(t, root, "passing-seed", "3.614ns")
}

func TestSeedExportNOSTAFallback(t *testing.T) {
	root := seed_export_root(t)
	cfg := seed_export_config(root, true)
	first := seed_export_job(t, 0, "first-failed-seed", false, "2.800", "-0.020", "5.000", true)
	best := seed_export_job(t, 3, "best-failed-seed", false, "3.100", "-0.010", "5.100", true)
	for _, job := range []seed_job{first, best} {
		if _, e := cfg.copy_if_best(job, job.worst_slack()); e != nil {
			t.Fatal(e)
		}
	}
	if e := cfg.finish_trials(); e != nil {
		t.Fatal(e)
	}
	seed_export_check_release(t, root, "best-failed-seed", "3.100ns")
}

func TestSeedExportRequiresPassingOutputOrNOSTAFallback(t *testing.T) {
	t.Run("ordinary timing failure", func(t *testing.T) {
		root := seed_export_root(t)
		cfg := seed_export_config(root, false)
		failed := seed_export_job(t, 0, "failed-seed", false, "-0.400", "-0.100", "1.000", true)
		if _, e := cfg.copy_if_best(failed, failed.worst_slack()); e != nil {
			t.Fatal(e)
		}
		if e := cfg.finish_trials(); e == nil {
			t.Fatal("all-failed timing trials unexpectedly passed")
		}
		if _, e := os.Stat(cfg.release.release_rbf()); !os.IsNotExist(e) {
			t.Fatalf("failed seed unexpectedly produced a release RBF: %v", e)
		}
	})
	t.Run("no NOSTA trials", func(t *testing.T) {
		cfg := seed_export_config(seed_export_root(t), true)
		if e := cfg.finish_trials(); e == nil {
			t.Fatal("NOSTA passed without a completed build and copied output")
		}
	})
	t.Run("EASY_STA requires jtcore pass", func(t *testing.T) {
		root := seed_export_root(t)
		cfg := seed_export_config(root, false)
		failed := seed_export_job(t, 0, "easy-failed-seed", false, "-0.400", "0.100", "1.000", true)
		if _, e := cfg.copy_if_best(failed, failed.worst_slack()); e != nil {
			t.Fatal(e)
		}
		if e := cfg.finish_trials(); e == nil {
			t.Fatal("EASY_STA accepted a failed seed with setup slack above -0.5 ns")
		}
		passed := seed_export_job(t, 1, "easy-passed-seed", true, "-0.333", "0.100", "1.000", true)
		if _, e := cfg.copy_if_best(passed, passed.worst_slack()); e != nil {
			t.Fatal(e)
		}
		if e := cfg.finish_trials(); e != nil {
			t.Fatal(e)
		}
		seed_export_check_release(t, root, "easy-passed-seed", "-0.333ns")
	})
}

func TestSeedExportErrorsOnMissingOrUnwritableRBF(t *testing.T) {
	t.Run("missing source RBF", func(t *testing.T) {
		root := seed_export_root(t)
		cfg := seed_export_config(root, false)
		job := seed_export_job(t, 0, "missing-rbf", true, "1.000", "0.100", "1.000", false)
		if _, e := cfg.copy_if_best(job, job.worst_slack()); e == nil {
			t.Fatal("missing source RBF was not reported")
		}
		if cfg.best_valid {
			t.Fatal("missing source RBF marked the release output valid")
		}
	})
	t.Run("unwritable release RBF path", func(t *testing.T) {
		root := seed_export_root(t)
		cfg := seed_export_config(root, false)
		job := seed_export_job(t, 0, "copy-error", true, "1.000", "0.100", "1.000", true)
		if e := os.MkdirAll(filepath.Dir(cfg.release.release_rbf()), 0755); e != nil {
			t.Fatal(e)
		}
		if e := os.Mkdir(cfg.release.release_rbf(), 0755); e != nil {
			t.Fatal(e)
		}
		if _, e := cfg.copy_if_best(job, job.worst_slack()); e == nil {
			t.Fatal("release RBF copy failure was not reported")
		}
		if cfg.best_valid {
			t.Fatal("failed RBF copy marked the release output valid")
		}
	})
}

func seed_export_root(t *testing.T) string {
	t.Helper()
	root := t.TempDir()
	t.Setenv("JTROOT", root)
	return root
}

func seed_export_config(root string, nosta bool) *seed_config {
	return &seed_config{
		release: seed_release{core: "1942", target: "mist", rbf: "jt1942"},
		nosta:   nosta,
	}
}

func seed_export_job(t *testing.T, seed int, rbf string, pass bool, setup, hold, recovery string, write_rbf bool) seed_job {
	t.Helper()
	builddir := filepath.Join(t.TempDir(), fmt.Sprintf("seed-%d", seed))
	if e := os.MkdirAll(builddir, 0755); e != nil {
		t.Fatal(e)
	}
	if write_rbf {
		if e := os.WriteFile(filepath.Join(builddir, "jt1942.rbf"), []byte(rbf), 0600); e != nil {
			t.Fatal(e)
		}
	}
	fit := "; Total logic elements ; 123 / 500 ( 25 % )\n; Total RAM Blocks ; 2 / 8 ( 25 % )\n"
	sta := fmt.Sprintf("Worst-case setup slack is %s\nWorst-case hold slack is %s\nWorst-case recovery slack is %s\n", setup, hold, recovery)
	if e := os.WriteFile(filepath.Join(builddir, "seed.fit.rpt"), []byte(fit), 0600); e != nil {
		t.Fatal(e)
	}
	if e := os.WriteFile(filepath.Join(builddir, "seed.sta.rpt"), []byte(sta), 0600); e != nil {
		t.Fatal(e)
	}
	return seed_job{seed: seed, builddir: builddir, pass: pass}
}

func seed_export_check_release(t *testing.T, root, want_rbf, want_sta string) {
	t.Helper()
	rbf, e := os.ReadFile(filepath.Join(root, "release", "mist", "jt1942.rbf"))
	if e != nil {
		t.Fatal(e)
	}
	if string(rbf) != want_rbf {
		t.Fatalf("release RBF %q, want %q", rbf, want_rbf)
	}
	stats, e := os.ReadFile(filepath.Join(root, "release", "mist", "jt1942.yml"))
	if e != nil {
		t.Fatal(e)
	}
	if !strings.Contains(string(stats), "sta: "+want_sta) {
		t.Fatalf("release stats %q do not match selected RBF STA %q", stats, want_sta)
	}
}
