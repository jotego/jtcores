/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */

package regression

import (
	"context"
	"encoding/xml"
	"fmt"
	"hash/crc32"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)


func TestResolveMiSTerROMFixturesUsesOrderedAvailableCandidates(t *testing.T) {
	root := t.TempDir()
	romRoot := filepath.Join(root, "roms")
	assetRoot := filepath.Join(root, "assets")
	if err := os.MkdirAll(romRoot, 0700); err != nil {
		t.Fatal(err)
	}
	if err := os.MkdirAll(assetRoot, 0700); err != nil {
		t.Fatal(err)
	}
	p1, p2 := []byte("part-one"), []byte("part-two")
	crc1 := fmt.Sprintf("%08x", crc32.ChecksumIEEE(p1))
	crc2 := fmt.Sprintf("%08x", crc32.ChecksumIEEE(p2))
	mraRaw := []byte(`<mame><setname>game</setname><rbf>jtcore</rbf><rom index="0" zip="child.zip|parent.zip"><part name="p1.bin" crc="` + crc1 + `"/><part name="p2.bin" crc="` + crc2 + `"/></rom></mame>`)
	var inventory mraInventory
	if err := xml.Unmarshal(mraRaw, &inventory); err != nil {
		t.Fatal(err)
	}
	mraPath := filepath.Join(root, "game.mra")
	if err := os.WriteFile(mraPath, mraRaw, 0600); err != nil {
		t.Fatal(err)
	}

	t.Run("missing earlier child supplied by later parent", func(t *testing.T) {
		parent := testMiSTerZIPPayload(t, romRoot, "parent-data.zip", map[string][]byte{"p1.bin": p1, "p2.bin": p2})
		if err := os.Rename(parent.Path, filepath.Join(romRoot, "parent.zip")); err != nil {
			t.Fatal(err)
		}
		archives, _, err := resolveMiSTerROMFixtures(inventory, romRoot, assetRoot, "game")
		if err != nil {
			t.Fatal(err)
		}
		if len(archives) != 1 || archives[0].Name != "parent.zip" {
			t.Fatalf("available candidate order/content: %+v", archives)
		}
		if err = validateMRAIdentityAndArchives(mraPath, "core", "game", archives, nil); err != nil {
			t.Fatalf("later parent did not satisfy absent child candidates: %v", err)
		}
	})

	t.Run("bad earlier candidate falls through to good later candidate", func(t *testing.T) {
		child := testMiSTerZIPPayload(t, romRoot, "child-data.zip", map[string][]byte{"p1.bin": []byte("bad"), "p2.bin": p2})
		parent := testMiSTerZIPPayload(t, romRoot, "parent-data.zip", map[string][]byte{"p1.bin": p1, "p2.bin": p2})
		if err := os.Rename(child.Path, filepath.Join(romRoot, "child.zip")); err != nil {
			t.Fatal(err)
		}
		if err := os.Rename(parent.Path, filepath.Join(romRoot, "parent.zip")); err != nil {
			t.Fatal(err)
		}
		archives, _, err := resolveMiSTerROMFixtures(inventory, romRoot, assetRoot, "game")
		if err != nil {
			t.Fatal(err)
		}
		if len(archives) != 2 || archives[0].Name != "child.zip" || archives[1].Name != "parent.zip" {
			t.Fatalf("candidate order was not preserved: %+v", archives)
		}
		if err = validateMRAIdentityAndArchives(mraPath, "core", "game", archives, nil); err != nil {
			t.Fatalf("good later candidate did not cover bad earlier candidate: %v", err)
		}
		archives = append(archives, testMiSTerAsset(FixtureROMArchive, "undeclared.zip", child))
		if err = validateMRAIdentityAndArchives(mraPath, "core", "game", archives, nil); err == nil {
			t.Fatal("undeclared archive fixture accepted")
		}
	})

	t.Run("incomplete total coverage still fails", func(t *testing.T) {
		if err := os.Remove(filepath.Join(romRoot, "child.zip")); err != nil && !os.IsNotExist(err) {
			t.Fatal(err)
		}
		parent := testMiSTerZIPPayload(t, romRoot, "partial-data.zip", map[string][]byte{"p1.bin": p1})
		if err := os.Rename(parent.Path, filepath.Join(romRoot, "parent.zip")); err != nil {
			t.Fatal(err)
		}
		archives, _, err := resolveMiSTerROMFixtures(inventory, romRoot, assetRoot, "game")
		if err != nil {
			t.Fatal(err)
		}
		if err = validateMRAIdentityAndArchives(mraPath, "core", "game", archives, nil); err == nil {
			t.Fatal("missing overall member coverage accepted")
		}
	})
}

func TestResolveMiSTerROMFixturesUsesEffectivePartsAndInlineRAMWindow(t *testing.T) {
	root := t.TempDir()
	romRoot, assets := filepath.Join(root, "roms"), filepath.Join(root, "assets")
	if err := os.MkdirAll(romRoot, 0700); err != nil {
		t.Fatal(err)
	}
	if err := os.MkdirAll(assets, 0700); err != nil {
		t.Fatal(err)
	}
	base, override := []byte("base-rom"), []byte("override-rom")
	baseCRC := fmt.Sprintf("%08x", crc32.ChecksumIEEE(base))
	overrideCRC := fmt.Sprintf("%08x", crc32.ChecksumIEEE(override))
	mra := []byte(`<mame><setname>parts</setname><rbf>jtfixture</rbf>` +
		`<rom index="0" zip="base.zip"><part name="base.bin" crc="` + baseCRC + `"/>` +
		`<part name="override.bin" zip="override.zip" crc="` + overrideCRC + `"/></rom>` +
		`<rom index="2"><part offset="1" length="2">10 20 30 40</part></rom></mame>`)
	var inventory mraInventory
	if err := xml.Unmarshal(mra, &inventory); err != nil {
		t.Fatal(err)
	}
	mraPath := filepath.Join(root, "parts.mra")
	if err := os.WriteFile(mraPath, mra, 0600); err != nil {
		t.Fatal(err)
	}
	for name, data := range map[string]map[string][]byte{
		"base.zip":     {"base.bin": base},
		"override.zip": {"override.bin": override},
		"unused.zip":   {"unused.bin": []byte("unused")},
	} {
		zip := testMiSTerZIPPayload(t, romRoot, "payload-"+name, data)
		if err := os.Rename(zip.Path, filepath.Join(romRoot, name)); err != nil {
			t.Fatal(err)
		}
	}
	archives, ram, err := resolveMiSTerROMFixtures(inventory, romRoot, assets, "parts")
	if err != nil {
		t.Fatal(err)
	}
	if len(archives) != 2 || archives[0].Name != "base.zip" || archives[1].Name != "override.zip" {
		t.Fatalf("inventory did not retain only effective archive candidates: %+v", archives)
	}
	if len(ram) != 1 {
		t.Fatalf("inline default RAM fixture count=%d", len(ram))
	}
	ramData, err := os.ReadFile(ram[0].Path)
	if err != nil || string(ramData) != string([]byte{0x20, 0x30}) {
		t.Fatalf("inline default RAM window %x: %v", ramData, err)
	}
	if err = validateMRAIdentityAndArchives(mraPath, "fixture", "parts", archives, ram); err != nil {
		t.Fatalf("effective named-part override and inline RAM window rejected: %v", err)
	}
}

func TestPrepareMiSTerManualSelectionAndROMlessSession(t *testing.T) {
	root := t.TempDir()
	source := filepath.Join(root, "project")
	roms := filepath.Join(root, "roms")
	jtbin := filepath.Join(root, "jtbin")
	release := jtbin
	for _, dir := range []string{filepath.Join(source, "cores", "fixture", "cfg"), filepath.Join(release, "mister"), filepath.Join(release, "mra"), roms} {
		if err := os.MkdirAll(dir, 0700); err != nil {
			t.Fatal(err)
		}
	}
	pinJTFRAMEForSourceTest(t, source, "fixture", "JTFRAME_RATE=60.00\n")
	if err := os.WriteFile(filepath.Join(source, "cores", "fixture", "cfg", "mame2mra.toml"), nil, 0600); err != nil {
		t.Fatal(err)
	}
	rbf := filepath.Join(release, "mister", "jtfixture.rbf")
	if err := os.WriteFile(rbf, []byte("verified RBF"), 0600); err != nil {
		t.Fatal(err)
	}
	for set, body := range map[string]string{
		"empty": `<mame><name>ROMless</name><setname>empty</setname><rbf>jtfixture</rbf></mame>`,
		"parts": `<mame><name>Windowed</name><setname>parts</setname><rbf>jtfixture</rbf><rom index="0" zip="base.zip"><part name="base.bin" crc="` + fmt.Sprintf("%08x", crc32.ChecksumIEEE([]byte("base"))) + `"/><part name="override.bin" zip="override.zip" crc="` + fmt.Sprintf("%08x", crc32.ChecksumIEEE([]byte("override"))) + `"/></rom><rom index="2"><part offset="1" length="2">10 20 30 40</part></rom></mame>`,
	} {
		if err := os.WriteFile(filepath.Join(release, "mra", set+".mra"), []byte(body), 0600); err != nil {
			t.Fatal(err)
		}
	}
	for name, member := range map[string]string{"base.zip": "base.bin", "override.zip": "override.bin"} {
		value := []byte(strings.TrimSuffix(member, ".bin"))
		zip := testMiSTerZIPPayload(t, roms, "payload-"+name, map[string][]byte{member: value})
		if err := os.Rename(zip.Path, filepath.Join(roms, name)); err != nil {
			t.Fatal(err)
		}
	}
	t.Setenv("JTBIN", jtbin)
	mainSHA := strings.Repeat("c", 64)
	evidence := filepath.Join(root, "qualification.json")
	if err := os.WriteFile(evidence, []byte("{}"), 0600); err != nil {
		t.Fatal(err)
	}
	cfg := Config{Target: "mister", Source: source, ROMSource: roms,
		Boards:          []MiSTerBoardConfig{{ID: "board-a", Host: "192.0.2.1", User: "root", SSHConfig: filepath.Join(root, "ssh_config"), RemoteStagingRoot: "/media/fat/_Arcade"}},
		CaptureContract: &MiSTerCaptureContract{Generation: "fixture-generation", Convention: CaptureNativeNonRotatedRGB888, QualificationID: "fixture-qualification", QualificationEvidence: evidence, MainSHA256: mainSHA, CommandTimeoutSeconds: 2, LoadTimeoutSeconds: 2, CaptureTimeoutSeconds: 2, CleanupTimeoutSeconds: 2, MaxHoldMS: 100, ExpectedBridgeCount: 1}}
	manifest, err := PrepareMiSTerManualSelection(context.Background(), cfg, filepath.Join(root, "workspace"), []string{"fixture"}, []string{"empty", "parts"}, true)
	if err != nil {
		t.Fatal(err)
	}
	if len(manifest.Cores) != 1 || len(manifest.Cores[0].Games) != 2 {
		t.Fatalf("prepared selection: %+v", manifest.Cores)
	}
	packedPath := filepath.Join(root, "neutral.jtcab")
	if err = os.WriteFile(packedPath, testPackedCAB(t, 1, nil, 4000), 0600); err != nil {
		t.Fatal(err)
	}
	packer := filepath.Join(root, "cabinet_pack")
	if err = os.WriteFile(packer, []byte("#!/bin/sh\ncp '"+strings.ReplaceAll(packedPath, "'", "'\\''")+"' \"$2\"\n"), 0700); err != nil {
		t.Fatal(err)
	}
	for _, spec := range manifest.Cores[0].Games {
		if spec.PreparedHashes == nil {
			t.Fatalf("ROMless game %s has nil PreparedHashes", spec.Setname)
		}
		launchBytes, readErr := os.ReadFile(spec.MisterAssets.LaunchMRA.Path)
		if readErr != nil {
			t.Fatal(readErr)
		}
		if _, stem, parseErr := canonicalMRA(launchBytes); parseErr != nil || stem == "jtfixture" {
			t.Fatalf("launch MRA did not contain changed RBF stem: %q %v", stem, parseErr)
		}
		if spec.Setname == "parts" {
			if len(spec.MisterAssets.ROMArchives) != 2 || spec.MisterAssets.ROMArchives[1].Name != "override.zip" || len(spec.MisterAssets.DefaultRAM) != 1 {
				t.Fatalf("part override/inline RAM fixture was not retained: %+v", spec.MisterAssets)
			}
		}
		session, _, _, prepareErr := PrepareMiSTerSession(context.Background(), "fixture", spec, MiSTerSessionBuildOptions{SourceRoot: source, CabPacker: packer, Generation: cfg.CaptureContract.Generation, Convention: CaptureNativeNonRotatedRGB888, MainSHA256: mainSHA, MaxHoldMS: 100})
		if prepareErr != nil {
			t.Fatalf("complete prepared session for %s: %v", spec.Setname, prepareErr)
		}
		if err = validateMiSTerAssets("fixture", spec.Setname, spec, session); err != nil {
			t.Fatalf("asset validation for %s: %v", spec.Setname, err)
		}
	}
}

func TestMiSTerReleaseBuildCommitUsesSelectedWorkflowHistory(t *testing.T) {
	release := filepath.Join(t.TempDir(), "JTBIN")
	dir := filepath.Join(release, "mister")
	if err := os.MkdirAll(dir, 0700); err != nil {
		t.Fatal(err)
	}
	core, buildSHA := "flstory", strings.Repeat("a", 40)
	rbf := filepath.Join(dir, "jt"+core+".rbf")
	if err := os.WriteFile(rbf, []byte("rbf bytes"), 0600); err != nil {
		t.Fatal(err)
	}
	for _, args := range [][]string{{"init", "-q"}, {"config", "user.name", "JTFRAME test"}, {"config", "user.email", "test@example.invalid"}, {"add", "mister/jt" + core + ".rbf"}, {"commit", "-qm", "Compile all result jtcores/commit/" + buildSHA}} {
		cmd := exec.Command("git", append([]string{"-C", release}, args...)...)
		if out, err := cmd.CombinedOutput(); err != nil {
			t.Fatalf("git %v: %v: %s", args, err, out)
		}
	}
	got, err := MiSTerReleaseBuildCommit(context.Background(), release, []string{core})
	if err != nil || got != buildSHA {
		t.Fatalf("source commit %q: %v", got, err)
	}
	if _, err = MiSTerReleaseBuildCommit(context.Background(), release, []string{"flstory", "fixture"}); err == nil {
		t.Fatal("cores with different/missing workflow history were accepted")
	}
}

func TestPrepareMiSTerManualArchiveRejectsSiDiOnlyArtifact(t *testing.T) {
	archive := ManualArchive{Commit: strings.Repeat("a", 40), Path: filepath.Join(t.TempDir(), "aaaaaaa-sidi128.zip"), SHA256: strings.Repeat("b", 64)}
	if _, err := PrepareMiSTerManualArchive(nil, Config{}, t.TempDir(), t.TempDir(), archive, nil, nil); err == nil || !strings.Contains(err.Error(), "Compile all") {
		t.Fatalf("SiDi-only artifact accepted: %v", err)
	}
}

func TestMiSTerPackedCABPrivateMaterializationIsHashChecked(t *testing.T) {
	root := t.TempDir()
	data := []byte("packed cabinet bytes")
	digest := digestBytes(data)
	identity := strings.Repeat("c", 64)
	path, err := writeMiSTerInputCAB(root, identity, data, digest)
	if err != nil {
		t.Fatal(err)
	}
	got, err := os.ReadFile(path)
	if err != nil || string(got) != string(data) {
		t.Fatalf("CAB input %q: %v", got, err)
	}
	if _, err = writeMiSTerInputCAB(root, identity, []byte("different"), digest); err == nil {
		t.Fatal("CAB hash mismatch accepted")
	}
}

func TestRejectMiSTerResultUsesExactCoreAndSet(t *testing.T) {
	root := t.TempDir()
	if err := GuardCaptureTarget(root, "mister"); err != nil { t.Fatal(err) }
	for _, name := range []string{"alpha", "beta"} {
		game := filepath.Join(root, name, "shared")
		if err := os.MkdirAll(filepath.Join(game, "new"), 0700); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(filepath.Join(game, "new", "marker"), []byte(name), 0600); err != nil {
			t.Fatal(err)
		}
	}
	if err := RejectMiSTerResult(root, "alpha", "shared", "reviewed"); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(filepath.Join(root, "alpha", "shared", "new")); !os.IsNotExist(err) {
		t.Fatalf("selected new slot remains: %v", err)
	}
	if _, err := os.Stat(filepath.Join(root, "beta", "shared", "new", "marker")); err != nil {
		t.Fatalf("other core was changed: %v", err)
	}
}
