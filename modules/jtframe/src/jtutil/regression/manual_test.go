/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */
package regression

import (
	"context"
	"encoding/xml"
	"fmt"
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"testing"
)

func manualWrite(t *testing.T, path string, data []byte) {
	t.Helper()
	if e := os.MkdirAll(filepath.Dir(path), 0750); e != nil {
		t.Fatal(e)
	}
	if e := os.WriteFile(path, data, 0640); e != nil {
		t.Fatal(e)
	}
}
func manualMRA(set, core string) []byte {
	return []byte(fmt.Sprintf(`<misterromdescription><name>%s</name><setname>%s</setname><rbf>jt%s</rbf><rom index="0"><part>01 02</part></rom><rom index="2"><part>ab cd</part></rom></misterromdescription>`, set, set, core))
}
func fakeManualCommands(t *testing.T) (*[]string, *[]string) {
	t.Helper()
	previous := manualCommand
	t.Cleanup(func() { manualCommand = previous })
	generated, parsed := []string{}, []string{}
	manualCommand = func(_ context.Context, source string, args ...string) ([]byte, error) {
		if args[0] == "bash" && strings.Contains(args[2], "jtframe mra2rom") {
			raw, e := os.ReadFile(args[4])
			if e != nil {
				return nil, e
			}
			var m mraInventory
			if e = xml.Unmarshal(raw, &m); e != nil {
				return nil, e
			}
			generated = append(generated, m.Setname)
			manualWrite(t, filepath.Join(source, "rom", m.Setname+".rom"), []byte{1, 2})
			manualWrite(t, filepath.Join(source, "rom", strings.ToUpper(m.Setname)+".RAM"), []byte{0xab, 0xcd})
			return nil, nil
		}
		if args[0] == "bash" {
			if strings.Count(args[2], "jtframe mra --nodbg") != 2 {
				t.Fatalf("manual generation paths omitted --nodbg: %s", args[2])
			}
			core, set, release := args[4], args[5], args[6]
			parsed = append(parsed, core+":"+set)
			if set == "" {
				set = "parent"
			}
			manualWrite(t, filepath.Join(release, "mra", set+".mra"), manualMRA(set, core))
			manualWrite(t, filepath.Join(release, "mra", "unrelated.mra"), manualMRA("unrelated", "other"))
			return nil, nil
		}
		if len(args) == 6 && args[1] == "-s" && args[2] == "-A" && args[3] == "-a" {
			manualWrite(t, args[4], []byte("[ARC]\nNAME=TEST\nRBF=JTTEST\n"))
			return nil, nil
		}
		return nil, fmt.Errorf("unexpected command %v", args)
	}
	return &generated, &parsed
}
func TestManualJTBinReadsSelectedSourceWithoutChanges(t *testing.T) {
	source, release := t.TempDir(), t.TempDir()
	t.Setenv("JTBIN", release)
	paths := map[string][]byte{filepath.Join(release, "sidi128", "jttest.rbf"): []byte("binary"), filepath.Join(release, "mra", "Parent.mra"): manualMRA("parent", "test"), filepath.Join(release, "mra", "other.mra"): manualMRA("irrelevant", "other"), filepath.Join(release, "mra", "_alternatives", "Clone.mra"): manualMRA("clone", "test")}
	for p, b := range paths {
		manualWrite(t, p, b)
	}
	generated, parsed := fakeManualCommands(t)
	cfg := Config{Source: source, MRAConverter: "converter"}
	manifest, e := PrepareManual(context.Background(), cfg, t.TempDir(), "test", "clone", true)
	if e != nil {
		t.Fatal(e)
	}
	if !reflect.DeepEqual(*generated, []string{"clone"}) || len(*parsed) != 0 {
		t.Fatalf("unselected work generated%v parsed%v", *generated, *parsed)
	}
	if manifest.Build.Workflow != "manual" || manifest.Build.Event != "manual-jtbin" || manifest.Build.SHA != "" || manifest.Build.ArtifactSHA == "" {
		t.Fatalf("bad identity %+v", manifest.Build)
	}
	game := manifest.Cores[0].Games[0]
	if game.Setname != "clone" || len(game.ROMs) != 2 || !strings.HasSuffix(game.ROMs[1], "CLONE.RAM") {
		t.Fatalf("bad fixtures %+v", game)
	}
	for p, want := range paths {
		got, e := os.ReadFile(p)
		if e != nil || string(got) != string(want) {
			t.Fatalf("input modified %s", p)
		}
	}
	manualWrite(t, filepath.Join(release, "sidi128", "jttest.rbf"), []byte("replacement binary"))
	if game.RBF != filepath.Join(release,"sidi128","jttest.rbf") { t.Fatal("RBF is not read from the selected release directory") }
	if e := verify_prepared_files(game); e == nil || !strings.Contains(e.Error(),"prepared input changed") { t.Fatalf("changed release input not detected: %v",e) }
	second, e := PrepareManual(context.Background(), cfg, t.TempDir(), "test", "clone", true)
	if e != nil {
		t.Fatal(e)
	}
	if second.RunID == manifest.RunID {
		t.Fatal("reused campaign identity")
	}
	if second.Build.ArtifactSHA == manifest.Build.ArtifactSHA {
		t.Fatal("changed RBF bytes did not change manual artifact identity")
	}
}
func TestManualJTBinCoreExcludesAlternativesAndUnknownSetBeforeROM(t *testing.T) {
	source, release := t.TempDir(), t.TempDir()
	t.Setenv("JTBIN", release)
	manualWrite(t, filepath.Join(release, "sidi128", "jttest.rbf"), []byte("binary"))
	manualWrite(t, filepath.Join(release, "mra", "Parent.mra"), manualMRA("parent", "test"))
	manualWrite(t, filepath.Join(release, "mra", "_alternatives", "Clone.mra"), manualMRA("clone", "test"))
	generated, _ := fakeManualCommands(t)
	cfg := Config{Source: source, MRAConverter: "converter"}
	m, e := PrepareManual(context.Background(), cfg, t.TempDir(), "test", "", true)
	if e != nil {
		t.Fatal(e)
	}
	if len(m.Cores[0].Games) != 1 || !reflect.DeepEqual(*generated, []string{"parent"}) {
		t.Fatalf("expanded clones %v", *generated)
	}
	*generated = nil
	if _, e = PrepareManual(context.Background(), cfg, t.TempDir(), "test", "unknown", true); e == nil {
		t.Fatal("unknown set accepted")
	}
	if len(*generated) != 0 {
		t.Fatalf("ROM work for unknown %v", *generated)
	}
}
func TestManualLocalFiltersCoreAndExplicitCloneBeforeGeneration(t *testing.T) {
	source := t.TempDir()
	manualWrite(t, filepath.Join(source, "cores", "test", "cfg", "mame2mra.toml"), []byte("[parse]"))
	manualWrite(t, filepath.Join(source, "release", "sidi128", "jttest.rbf"), []byte("binary"))
	generated, parsed := fakeManualCommands(t)
	m, e := PrepareManual(context.Background(), Config{Source: source, MRAConverter: "converter"}, t.TempDir(), "test", "clone", false)
	if e != nil {
		t.Fatal(e)
	}
	if !reflect.DeepEqual(*parsed, []string{"test:clone"}) || !reflect.DeepEqual(*generated, []string{"clone"}) {
		t.Fatalf("unscoped generation parsed%v generated%v", *parsed, *generated)
	}
	game := m.Cores[0].Games[0]
	if game.RBF != filepath.Join(source,"release","sidi128","jttest.rbf") || game.ARC != filepath.Join(source,"rom","clone.arc") { t.Fatalf("nonstandard game paths: %+v",game) }
	for _, input := range game.ROMs {
		if filepath.Dir(input) != filepath.Join(source,"rom") { t.Fatalf("ROM/RAM copy: %s",input) }
	}
	if _,ok:=game.PreparedHashes[filepath.Join(source,"release","mra","clone.mra")]; !ok { t.Fatal("standard MRA identity not recorded") }
	if m.Build.SHA != "" || m.Build.Event != "manual-local" {
		t.Fatalf("bad provenance %+v", m.Build)
	}
}
func TestManualRejectsUnsafeNamesBeforeAnyPreparation(t *testing.T) {
	generated, parsed := fakeManualCommands(t)
	for _, name := range []string{"../test", "test/../../x", "test\nother", ".", "test;echo"} {
		if _, e := PrepareManual(context.Background(), Config{Source: t.TempDir()}, t.TempDir(), name, "", false); e == nil {
			t.Fatalf("unsafe core accepted %q", name)
		}
	}
	if len(*generated) != 0 || len(*parsed) != 0 {
		t.Fatal("unsafe selection performed work")
	}
}
