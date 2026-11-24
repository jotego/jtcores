package regression

import (
	"context"
	"encoding/xml"
	"errors"
	"os"
	"path/filepath"
	"strings"
	"syscall"
	"testing"
)

func TestBulkMiSTerROMInputClassification(t *testing.T) {
	root := t.TempDir()
	roms := filepath.Join(root, "roms")
	beta := filepath.Join(root, "jtutil")
	assets := filepath.Join(root, "assets")
	for _, dir := range []string{roms, beta, assets} {
		if err := os.MkdirAll(dir, 0700); err != nil {
			t.Fatal(err)
		}
	}
	t.Setenv("JTUTIL", beta)
	payload := testMiSTerZIPPayload(t, beta, "jtbeta.zip", map[string][]byte{"beta.bin": []byte("fixture")})
	var inventory mraInventory
	if err := xml.Unmarshal([]byte(`<mame><setname>test</setname><rbf>jtfixture</rbf><rom index="0" zip="jtbeta.zip"><part name="beta.bin"/></rom></mame>`), &inventory); err != nil {
		t.Fatal(err)
	}
	archives, _, err := resolveMiSTerROMFixtures(inventory, roms, assets, "test")
	if err != nil || len(archives) != 1 || archives[0].Path != payload.Path {
		t.Fatalf("beta fallback: %+v %v", archives, err)
	}
	if _, err = readMRAArchivePart(archives, "jtbeta.zip", mraPart{Name: "missing"}); !IsMiSTerGamePreparationError(err) {
		t.Fatalf("missing ROM is not game error: %v", err)
	}
	if !miSTerFatalROMIO(&os.PathError{Op: "open", Path: "fixture", Err: syscall.EIO}) {
		t.Fatal("I/O failure downgraded")
	}
	if IsMiSTerGamePreparationError(errors.New("global configuration error")) {
		t.Fatal("global failure downgraded")
	}
}

func TestBulkMissingRBFIsExplicitGameError(t *testing.T) {
	root := t.TempDir()
	_, err := prepareMiSTerGameAssets(nil, Config{}, root, root, root, root, "fixture", "game", "unused", "unused")
	if !IsMiSTerGamePreparationError(err) {
		t.Fatalf("missing RBF not marked as game input error: %v", err)
	}
}

func TestMiSTerTargetSkipUsesSelectedSource(t *testing.T) {
	host := t.TempDir()
	snapshot := t.TempDir()
	pinJTFRAMEForSourceTest(t, host, "fixture", "JTFRAME_RATE=60.00\n")
	pinJTFRAMEForSourceTest(t, snapshot, "fixture", "JTFRAME_SKIP\n")
	hostSkip, err := miSTerTargetSkipped(host, "fixture")
	if err != nil {
		t.Fatal(err)
	}
	frozenSkip, err := miSTerTargetSkipped(snapshot, "fixture")
	if err != nil {
		t.Fatal(err)
	}
	if hostSkip || !frozenSkip {
		t.Fatalf("host skip=%v frozen skip=%v", hostSkip, frozenSkip)
	}
}

func TestMiSTerTargetSkipsCoresWithoutRegression(t *testing.T) {
	cases := map[string]bool{
		"JTFRAME_RATE=60.00\n":               false,
		"JTFRAME_MR_GAME_DDR\n":              true,
		"JTFRAME_LF_BUFFER\n":                true,
		"JTFRAME_LF_BUFFER\nJTFRAME_MR_LF_BRAM\n": false,
		"MISTER_DEBUG_NOHDMI\n":              true,
	}
	for def, want := range cases {
		source := t.TempDir()
		pinJTFRAMEForSourceTest(t, source, "fixture", def)
		got, err := miSTerTargetSkipped(source, "fixture")
		if err != nil {
			t.Fatal(err)
		}
		if got != want {
			t.Errorf("%q: skipped=%v, want %v", def, got, want)
		}
	}
}

func TestBulkArchiveKeepsReadyGameBesideMissingRBF(t *testing.T) {
	root := t.TempDir()
	source := filepath.Join(root, "source")
	release := filepath.Join(root, "release")
	roms := filepath.Join(root, "roms")
	for _, dir := range []string{source, filepath.Join(release, "mra"), filepath.Join(release, "mister"), roms} {
		if err := os.MkdirAll(dir, 0700); err != nil {
			t.Fatal(err)
		}
	}
	pinJTFRAMEForSourceTest(t, source, "fixture", "JTFRAME_RATE=60.00\n")
	missingCfg := filepath.Join(source, "cores", "missing", "cfg")
	if err := os.MkdirAll(missingCfg, 0700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(missingCfg, "macros.def"), []byte("JTFRAME_RATE=60.00\n"), 0600); err != nil {
		t.Fatal(err)
	}
	for _, core := range []string{"fixture", "missing"} {
		if err := os.WriteFile(filepath.Join(source, "cores", core, "cfg", "mame2mra.toml"), nil, 0600); err != nil {
			t.Fatal(err)
		}
		raw := []byte("<mame><name>test</name><setname>" + core + "game</setname><rbf>jt" + core + "</rbf></mame>")
		if err := os.WriteFile(filepath.Join(release, "mra", core+".mra"), raw, 0600); err != nil {
			t.Fatal(err)
		}
	}
	if err := os.WriteFile(filepath.Join(release, "mra", "missing2.mra"), []byte(`<mame><name>test</name><setname>missinggame2</setname><rbf>jtmissing</rbf></mame>`), 0600); err != nil { t.Fatal(err) }
	if err := os.WriteFile(filepath.Join(release, "mister", "jtfixture.rbf"), []byte("fixture rbf"), 0600); err != nil {
		t.Fatal(err)
	}
	cfg := Config{Source: source, SourceConfigRoot: source, ROMSource: roms, CaptureContract: &MiSTerCaptureContract{MainSHA256: strings.Repeat("c", 64)}}
	m, err := prepareMiSTerReleaseSelection(context.Background(), cfg, source, release, filepath.Join(root, "work"), []string{"fixture", "missing"}, nil, true)
	if err != nil {
		t.Fatal(err)
	}
	if len(m.Cores) != 1 || len(m.Cores[0].Games) != 1 || m.Cores[0].Games[0].MisterAssets == nil || len(m.SkippedBuilds) != 1 || m.SkippedBuilds[0] != "missing" {
		t.Fatalf("mixed inventory: %+v", m.Cores)
	}
	if _, err = prepareMiSTerReleaseSelection(context.Background(), cfg, source, release, filepath.Join(root, "strict"), []string{"fixture", "missing"}, nil); err == nil {
		t.Fatal("strict inventory accepted missing RBF")
	}
	pinned := filepath.Join(root, "pinned")
	if err = os.MkdirAll(pinned, 0700); err != nil { t.Fatal(err) }
	pinJTFRAMEForSourceTest(t, pinned, "fixture", "JTFRAME_RATE=60.00\n")
	t.Setenv("JTROOT", source)
	t.Setenv("JTFRAME", filepath.Join(source, "modules", "jtframe"))
	if err = os.WriteFile(filepath.Join(source, "cores", "fixture", "cfg", "reg.yaml"), []byte("fixturegame:\n  skip: true\n"), 0600); err != nil { t.Fatal(err) }
	cfg.SourceConfigRoot = pinned
	empty, err := prepareMiSTerReleaseSelection(context.Background(), cfg, source, release, filepath.Join(root, "empty"), []string{"fixture"}, nil, true)
	if err != nil || len(empty.Cores) != 0 || len(empty.SkippedGames) != 1 { t.Fatalf("current host skip ignored with pinned source: %+v %v", empty, err) }
	if err = os.Remove(filepath.Join(source, "cores", "fixture", "cfg", "reg.yaml")); err != nil { t.Fatal(err) }
	cfg.SourceConfigRoot = source
	rbf := filepath.Join(release, "mister", "jtfixture.rbf")
	if err = os.WriteFile(rbf, nil, 0600); err != nil { t.Fatal(err) }
	if _, err = prepareMiSTerReleaseSelection(context.Background(), cfg, source, release, filepath.Join(root, "corrupt"), []string{"fixture"}, nil, true); err == nil || IsMiSTerGamePreparationError(err) { t.Fatalf("empty RBF was skipped: %v", err) }
	if err = os.WriteFile(rbf, []byte("fixture rbf"), 0600); err != nil { t.Fatal(err) }
	withROM := []byte(`<mame><name>test</name><setname>fixturegame</setname><rbf>jtfixture</rbf><rom index="0" zip="missing.zip"><part name="x"/></rom></mame>`)
	if err = os.WriteFile(filepath.Join(release, "mra", "fixture.mra"), withROM, 0600); err != nil {
		t.Fatal(err)
	}
	cfg.ROMSource = filepath.Join(root, "absent")
	_, err = prepareMiSTerReleaseSelection(context.Background(), cfg, source, release, filepath.Join(root, "badroot"), []string{"fixture"}, nil, true)
	if err == nil || IsMiSTerGamePreparationError(err) {
		t.Fatalf("missing shared ROM source was not fatal: %v", err)
	}
}

func TestManualMiSTerRunRejectsAutomaticScope(t *testing.T) {
	f := newRunCommitRecoveryFixture(t, "manual-scope")
	f.policy.RunScopeID = MiSTerAutomaticRunScopeID
	_, err := RunCommitMiSTer(context.Background(), f.log, f.prepared, f.cfg, f.deps, f.policy)
	if err == nil || !strings.Contains(err.Error(), "reserved") {
		t.Fatalf("automatic scope accepted: %v", err)
	}
}
