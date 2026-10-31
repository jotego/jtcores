/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */
package regression

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestSourceExclusionsUseJtframeCaseInsensitiveFamilySelectors(t *testing.T) {
	source := t.TempDir()
	manualWrite(t, filepath.Join(source, "cores", "fake", "cfg", "mame2mra.toml"), []byte("[parse]\ndEbUg.Machines=[\"parent\"]\ndEbUg.sEtNaMeS=[\"exact\"]\nskip.Setnames=[\"skipset\"]\n"))
	manualWrite(t, filepath.Join(source, "doc", "mame.xml"), []byte(`<mame><machine name="parent"/><machine name="clone" cloneof="parent"/><machine name="other"/></mame>`))
	tuples := []InventoryTuple{}
	for _, s := range []string{"parent", "clone", "exact", "skipset", "other"} {
		tuples = append(tuples, InventoryTuple{Core: "fake", Setname: s, RBF: "jtfake"})
	}
	excluded, err := sourceExclusions(source, tuples)
	if err != nil {
		t.Fatal(err)
	}
	for _, tuple := range tuples {
		want := tuple.Setname != "other"
		if (excluded[tupleKey(tuple)] != "") != want {
			t.Fatalf("wrong classification %+v: %v", tuple, excluded)
		}
	}
}
func TestSourceExclusionsRefuseUnknownCloneFamilyWithoutMetadata(t *testing.T) {
	source := t.TempDir()
	manualWrite(t, filepath.Join(source, "cores", "fake", "cfg", "mame2mra.toml"), []byte("[parse]\ndebug.machine=\"parent\"\n"))
	if _, err := sourceExclusions(source, []InventoryTuple{{Core: "fake", Setname: "clone", RBF: "jtfake"}}); err == nil || !strings.Contains(err.Error(), "eligibility needs") {
		t.Fatalf("cannot silently accept unknown clone: %v", err)
	}
}
func TestJtframeInventoryAndROMCommandsPassNoDebug(t *testing.T) {
	source := t.TempDir()
	manualWrite(t, filepath.Join(source, "setprj.sh"), []byte("jtframe() { printf '%s ' \"$@\"; return 1; }\n"))
	output, _ := jtframeMRACommand(context.Background(), source, "fake", "", false)
	if !strings.Contains(string(output), "mra --nodbg --mainonly") {
		t.Fatalf("inventory omitted nodbg: %s", output)
	}
	_, _, _, err := generateExactROM(context.Background(), source, "fake", "casegame", "jtfake", "/roms", "unused")
	if err == nil || !strings.Contains(err.Error(), "mra --nodbg --mainonly") {
		t.Fatalf("ROM command omitted nodbg: %v", err)
	}
}
func TestArtifactFallbackNeverRestoresCurrentDebugOrSkippedGames(t *testing.T) {
	source, root := t.TempDir(), t.TempDir()
	for _, core := range []string{"good", "cal50"} {
		manualWrite(t, filepath.Join(source, "cores", core, "cfg", "macros.def"), []byte("JTFRAME_BUTTONS=2\n"))
	}
	manualWrite(t, filepath.Join(source, "cores", "good", "cfg", "mame2mra.toml"), []byte("[parse]\n"))
	manualWrite(t, filepath.Join(source, "cores", "cal50", "cfg", "mame2mra.toml"), []byte("[parse]\ndebug.Machines=[\"downtown\",\"twineagl\"]\nskip.machines=[\"arbalest\",\"metafox\"]\n"))
	manualWrite(t, filepath.Join(source, "doc", "mame.xml"), []byte(`<mame><machine name="downtown"/><machine name="twineagl"/><machine name="arbalest"/><machine name="metafox"/></mame>`))
	old := jtframeMRACommand
	t.Cleanup(func() { jtframeMRACommand = old })
	jtframeMRACommand = func(_ context.Context, src, core, roms string, have bool) ([]byte, error) {
		if core == "good" {
			manualWrite(t, filepath.Join(src, "release", "mra", "good.mra"), []byte(`<misterromdescription><setname>good</setname><rbf>jtgood</rbf></misterromdescription>`))
		}
		return nil, nil
	}
	rbfRoot := filepath.Join(root, "rbf")
	manualWrite(t, filepath.Join(rbfRoot, "jtgood.rbf"), []byte("rbf"))
	manualWrite(t, filepath.Join(rbfRoot, "jtcal50.rbf"), []byte("rbf"))
	entries := map[string]string{"release/mra/Good.mra": `<misterromdescription><setname>good</setname><rbf>jtgood</rbf></misterromdescription>`}
	for _, set := range []string{"downtown", "twineagl", "arbalest", "metafox"} {
		entries["release/mra/"+set+".mra"] = `<misterromdescription><setname>` + set + `</setname><rbf>jtcal50</rbf></misterromdescription>`
	}
	artifact := filepath.Join(root, "artifact.zip")
	writeZip(t, artifact, entries)
	converter := filepath.Join(root, "converter")
	manualWrite(t, converter, []byte("#!/bin/sh\nprintf '[ARC]\\nNAME=GOOD\\nRBF=JTGOOD\\n' > \"$4\"\n"))
	if err := os.Chmod(converter, 0750); err != nil {
		t.Fatal(err)
	}
	cores, rec, err := mainGameInventory(context.Background(), source, rbfRoot, filepath.Join(root, "fixtures"), artifact, BuildIdentity{}, Config{MRAConverter: converter})
	if err != nil {
		t.Fatal(err)
	}
	if len(cores) != 1 || cores[0].Core != "good" || len(cores[0].Games) != 1 {
		t.Fatalf("excluded games restored: %+v", cores)
	}
	if len(rec.ArtifactFallbacks) != 0 || len(rec.SourceExcluded) != 4 || len(rec.SourceExclusionReasons) != 4 {
		t.Fatalf("exclusions not reconciled: %+v", rec)
	}
	for _, tuple := range rec.ArtifactOnly {
		if !strings.Contains(rec.ArtifactOnlyJustifications[tupleKey(tuple)], "Excluded from regression") {
			t.Fatal("exclusion reason missing")
		}
	}
	jtframeMRACommand = func(context.Context, string, string, string, bool) ([]byte, error) {
		return []byte("simulated parser failure"), fmt.Errorf("exit 1")
	}
	failedCores, failedRec, err := mainGameInventory(context.Background(), source, rbfRoot, filepath.Join(root, "failed-fixtures"), artifact, BuildIdentity{}, Config{MRAConverter: converter})
	if err != nil {
		t.Fatal(err)
	}
	if len(failedCores) != 1 || failedCores[0].Core != "good" || len(failedRec.ArtifactFallbacks) != 1 || !strings.Contains(failedCores[0].Games[0].PreparationError, "simulated parser failure") {
		t.Fatalf("genuine generation failure hidden: cores=%+v rec=%+v", failedCores, failedRec)
	}
}
func TestManualJTBinRejectsDebugParentAndCloneBeforeROM(t *testing.T) {
	source, release := t.TempDir(), t.TempDir()
	t.Setenv("JTBIN", release)
	manualWrite(t, filepath.Join(source, "cores", "test", "cfg", "mame2mra.toml"), []byte("[parse]\ndebug.Machines=[\"parent\"]\n"))
	manualWrite(t, filepath.Join(source, "doc", "mame.xml"), []byte(`<mame><machine name="parent"/><machine name="clone" cloneof="parent"/></mame>`))
	manualWrite(t, filepath.Join(release, "sidi128", "jttest.rbf"), []byte("rbf"))
	manualWrite(t, filepath.Join(release, "mra", "Parent.mra"), manualMRA("parent", "test"))
	manualWrite(t, filepath.Join(release, "mra", "_alternatives", "Clone.mra"), manualMRA("clone", "test"))
	generated, _ := fakeManualCommands(t)
	for _, set := range []string{"parent", "clone"} {
		if _, err := PrepareManual(context.Background(), Config{Source: source}, t.TempDir(), "test", set, true); err == nil || !strings.Contains(err.Error(), "not regression eligible") {
			t.Fatalf("debug set %s accepted: %v", set, err)
		}
	}
	if len(*generated) != 0 {
		t.Fatalf("debug ROM generation attempted: %v", *generated)
	}
}

func TestManualLocalExplicitDebugSetRejectedBeforeGeneration(t *testing.T) {
	source := t.TempDir()
	manualWrite(t, filepath.Join(source, "cores", "test", "cfg", "mame2mra.toml"), []byte("[parse]\ndebug.Setnames=[\"clone\"]\n"))
	generated, parsed := fakeManualCommands(t)
	_, err := PrepareManual(context.Background(), Config{Source: source}, t.TempDir(), "test", "clone", false)
	if err == nil || !strings.Contains(err.Error(), "not regression eligible") {
		t.Fatalf("explicit debug rejection missing: %v", err)
	}
	if len(*generated) != 0 || len(*parsed) != 0 {
		t.Fatal("explicit debug selection performed preparation")
	}
}

func TestExplicitManifestEligibilityRejectsDebugAndSkipWithoutMutation(t *testing.T) {
	source := t.TempDir()
	manualWrite(t, filepath.Join(source, "cores", "fake", "cfg", "mame2mra.toml"), []byte("[parse]\ndebug.Setnames=[\"debuggame\"]\nskip.Setnames=[\"skipped\"]\n"))
	manifest := Manifest{RunID: "historical", Cores: []CoreManifest{{Core: "fake", Games: []GameSpec{{Setname: "debuggame"}, {Setname: "releasegame"}, {Setname: "skipped"}}}}}
	before := fmt.Sprintf("%+v", manifest)
	err := ValidateManifestEligibility(source, manifest)
	if err == nil || !strings.Contains(err.Error(), "fake/debuggame") || !strings.Contains(err.Error(), "fake/skipped") || !strings.Contains(err.Error(), "regenerate the inventory") {
		t.Fatalf("bad rejection %v", err)
	}
	if before != fmt.Sprintf("%+v", manifest) {
		t.Fatal("historical manifest modified")
	}
	if err = ValidateManifestEligibility(source, Manifest{Cores: []CoreManifest{{Core: "fake", Games: []GameSpec{{Setname: "releasegame"}}}}}); err != nil {
		t.Fatal(err)
	}
}

func TestManifestEligibilityRejectsUnsafeNamesBeforeReadingSource(t *testing.T) {
	for _, test := range []struct{ core, set string }{{"../outside", "game"}, {"fake", "../game"}, {"fake", "bad\nSITE LOAD"}, {"", "game"}} {
		manifest := Manifest{Cores: []CoreManifest{{Core: test.core, Games: []GameSpec{{Setname: test.set}}}}}
		err := ValidateManifestEligibility(filepath.Join(t.TempDir(), "absent-project"), manifest)
		if err == nil || !strings.Contains(err.Error(), "unsafe") {
			t.Fatalf("unsafe names not rejected before reading source: %+v %v", test, err)
		}
	}
}

func TestArtifactOnlyUnknownFamilyRemainsPreparationError(t *testing.T) {
    source,root:=t.TempDir(),t.TempDir()
    manualWrite(t,filepath.Join(source,"cores","fake","cfg","macros.def"),[]byte("JTFRAME_BUTTONS=2\n"))
    manualWrite(t,filepath.Join(source,"cores","fake","cfg","mame2mra.toml"),[]byte("[parse]\nskip.bootlegs=true\nskip.machine=\"parent\"\n"))
    manualWrite(t,filepath.Join(source,"doc","mame.xml"),[]byte(`<mame><machine name="known"/></mame>`))
    old:=jtframeMRACommand
    defer func(){jtframeMRACommand=old}()
    jtframeMRACommand=func(_ context.Context,src,core,roms string,have bool)([]byte,error){
        manualWrite(t,filepath.Join(src,"release","mra","known.mra"),[]byte(manualMRA("known","fake")))
        return nil,nil
    }
    rbf_root:=filepath.Join(root,"rbf")
    manualWrite(t,filepath.Join(rbf_root,"jtfake.rbf"),[]byte("rbf"))
    artifact:=filepath.Join(root,"artifact.zip")
    writeZip(t,artifact,map[string]string{"release/mra/Known.mra":string(manualMRA("known","fake")),"release/mra/Unknown.mra":string(manualMRA("unknown","fake"))})
    cores,rec,err:=mainGameInventory(context.Background(),source,rbf_root,filepath.Join(root,"fixtures"),artifact,BuildIdentity{},Config{MRAConverter:"/bin/false"})
    if err!=nil {t.Fatal(err)}
    if len(cores)!=1 || len(cores[0].Games)!=2 || len(rec.ArtifactFallbacks)!=1 {t.Fatalf("lost inventory: %+v %+v",cores,rec)}
    found:=false
    for _,game:=range cores[0].Games {
        if game.Setname=="unknown" {
            found=true
            if !strings.Contains(game.PreparationError,"project mainonly inventory omitted") {t.Fatalf("unknown title could execute: %+v",game)}
        }
    }
    if !found {t.Fatal("artifact-only title disappeared")}
    tuple:=InventoryTuple{Core:"fake",Setname:"unknown",RBF:"jtfake"}
    if _,err=sourceExclusions(source,[]InventoryTuple{tuple});err==nil {t.Fatal("manual unknown classification must still fail")}
}

func TestEligibilityUsesCustomXMLAndOverrides(t *testing.T) {
    source:=t.TempDir()
    manualWrite(t,filepath.Join(source,"cores","fake","cfg","mame2mra.toml"),[]byte("[parse]\nskip.bootlegs=true\ndebug.machine=\"parent\"\n"))
    manualWrite(t,filepath.Join(source,"doc","mame.xml"),[]byte(`<mame><machine name="overridden" cloneof="parent"/></mame>`))
    manualWrite(t,filepath.Join(source,"doc","custom.xml"),[]byte(`<mame><machine name="aquario"><description>Clockwork Aquario (prototype)</description></machine><machine name="overridden"/><machine name="custom_clone" cloneof="parent"/><machine name="custom_bootleg"><description>Game (bootleg)</description></machine></mame>`))
    tuples:=[]InventoryTuple{}
    for _,set:=range []string{"aquario","overridden","custom_clone","custom_bootleg"} {tuples=append(tuples,InventoryTuple{Core:"fake",Setname:set,RBF:"jtfake"})}
    excluded,err:=sourceExclusions(source,tuples)
    if err!=nil{t.Fatal(err)}
    for _,tuple:=range tuples {
        want:=tuple.Setname=="custom_clone" || tuple.Setname=="custom_bootleg"
        if (excluded[tupleKey(tuple)]!="")!=want {t.Fatalf("custom classification mismatch: %+v %v",tuple,excluded)}
    }
}
