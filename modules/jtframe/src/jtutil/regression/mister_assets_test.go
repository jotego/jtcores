/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */

package regression

import (
	"archive/zip"
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/xml"
	"fmt"
	"hash/crc32"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)

func TestMiSTerMRAArchivesPreservePluralRoleAndName(t *testing.T) {
	root := t.TempDir()
	mra := filepath.Join(root, "original.mra")
	romCRC := fmt.Sprintf("%08x", crc32.ChecksumIEEE([]byte("rom")))
	data := []byte(`<mame><name>1943</name><setname>1943</setname><rbf>jt1943</rbf><rom index="0" zip="base.zip"><part name="p1.bin" crc="` + romCRC + `"/></rom><rom index="1" zip="sound.zip"><part name="s1.bin"/></rom></mame>`)
	if err := os.WriteFile(mra, data, 0600); err != nil {
		t.Fatal(err)
	}
	base := testMiSTerZIP(t, root, "cached-a.zip", "p1.bin")
	sound := testMiSTerZIP(t, root, "cached-b.zip", "s1.bin")
	archives := []MiSTerAssetFile{testMiSTerAsset(FixtureROMArchive, "base.zip", base), testMiSTerAsset(FixtureROMArchive, "sound.zip", sound)}
	if err := validateMRAIdentityAndArchives(mra, "1943", "1943", archives, nil); err != nil {
		t.Fatal(err)
	}
	badCRC := bytes.Replace(data, []byte(romCRC), []byte("12345678"), 1)
	badMRA := filepath.Join(root, "bad-crc.mra")
	if err := os.WriteFile(badMRA, badCRC, 0600); err != nil {
		t.Fatal(err)
	}
	if err := validateMRAIdentityAndArchives(badMRA, "1943", "1943", archives, nil); err == nil {
		t.Fatal("wrong ZIP member bytes accepted for declared MRA CRC")
	}
	for name, bad := range map[string][]MiSTerAssetFile{
		"missing":                {archives[0]},
		"extra":                  append(append([]MiSTerAssetFile(nil), archives...), testMiSTerAsset(FixtureROMArchive, "extra.zip", base)),
		"duplicate logical name": {archives[0], archives[0]},
		"wrong role":             {{Role: FixtureDefaultRAM, Name: "sound.zip", Path: sound.Path, SHA256: sound.SHA256}, archives[0]},
		"wrong digest":           {{Role: FixtureROMArchive, Name: "base.zip", Path: base.Path, SHA256: strings.Repeat("0", 64)}, archives[1]},
	} {
		t.Run(name, func(t *testing.T) {
			if err := validateMRAIdentityAndArchives(mra, "1943", "1943", bad, nil); err == nil {
				t.Fatal("invalid archive fixture set accepted")
			}
		})
	}
}

func TestMiSTerMRASplitZIPDeclarationsAndRepeatedReferences(t *testing.T) {
	root := t.TempDir()
	mra := filepath.Join(root, "split.mra")
	p1, p2, p3 := []byte("rom-one"), []byte("rom-two"), []byte("rom-three")
	crc1 := fmt.Sprintf("%08x", crc32.ChecksumIEEE(p1))
	crc2 := fmt.Sprintf("%08x", crc32.ChecksumIEEE(p2))
	crc3 := fmt.Sprintf("%08x", crc32.ChecksumIEEE(p3))
	data := []byte(`<mame><setname>1943</setname><rbf>jt1943</rbf><rom index="0" zip="base.zip|parent.zip"><part name="p1.bin" crc="` + crc1 + `"/><part name="p2.bin" crc="` + crc2 + `"/></rom><rom index="1" zip="base.zip|parent.zip"><part name="p3.bin" crc="` + crc3 + `"/></rom></mame>`)
	if err := os.WriteFile(mra, data, 0600); err != nil {
		t.Fatal(err)
	}
	base := testMiSTerZIPPayload(t, root, "opaque-a.zip", map[string][]byte{"p1.bin": p1})
	parent := testMiSTerZIPPayload(t, root, "opaque-b.zip", map[string][]byte{"p2.bin": p2, "p3.bin": p3})
	archives := []MiSTerAssetFile{testMiSTerAsset(FixtureROMArchive, "base.zip", base), testMiSTerAsset(FixtureROMArchive, "parent.zip", parent)}
	if err := validateMRAIdentityAndArchives(mra, "1943", "1943", archives, nil); err != nil {
		t.Fatalf("ordered split declaration or repeated archive reference rejected: %v", err)
	}
	mergedParent := testMiSTerZIPPayload(t, root, "opaque-merged.zip", map[string][]byte{
		"p1.bin": p1, "p2.bin": p2, "p3.bin": p3,
	})
	if err := validateMRAIdentityAndArchives(mra, "1943", "1943", []MiSTerAssetFile{
		testMiSTerAsset(FixtureROMArchive, "parent.zip", mergedParent),
	}, nil); err != nil {
		t.Fatalf("merged parent did not satisfy missing child candidates: %v", err)
	}
	badEarlier := testMiSTerZIPPayload(t, root, "opaque-bad-earlier.zip", map[string][]byte{
		"p1.bin": []byte("wrong"), "p2.bin": p2, "p3.bin": p3,
	})
	if err := validateMRAIdentityAndArchives(mra, "1943", "1943", []MiSTerAssetFile{
		testMiSTerAsset(FixtureROMArchive, "base.zip", badEarlier),
		testMiSTerAsset(FixtureROMArchive, "parent.zip", mergedParent),
	}, nil); err != nil {
		t.Fatalf("later matching candidate did not recover from earlier CRC mismatch: %v", err)
	}
	corruptPath := filepath.Join(root, "opaque-corrupt.zip")
	if err := os.WriteFile(corruptPath, []byte("not a ZIP archive"), 0600); err != nil {
		t.Fatal(err)
	}
	if err := validateMRAIdentityAndArchives(mra, "1943", "1943", []MiSTerAssetFile{
		testMiSTerAsset(FixtureROMArchive, "base.zip", assetFixture{Path: corruptPath, SHA256: mustFileSHAForAssets(t, corruptPath)}),
		testMiSTerAsset(FixtureROMArchive, "parent.zip", mergedParent),
	}, nil); err != nil {
		t.Fatalf("later matching candidate did not recover from unusable earlier archive: %v", err)
	}
	for name, bad := range map[string][]MiSTerAssetFile{
		"missing parent archive":            {archives[0]},
		"wrong logical archive":             {archives[0], testMiSTerAsset(FixtureROMArchive, "wrong.zip", parent)},
		"member absent from all candidates": {archives[0], testMiSTerAsset(FixtureROMArchive, "parent.zip", testMiSTerZIPPayload(t, root, "opaque-empty.zip", map[string][]byte{"other.bin": []byte("unmatched payload")}))},
		"bad declared CRC":                  {archives[0], testMiSTerAsset(FixtureROMArchive, "parent.zip", testMiSTerZIPPayload(t, root, "opaque-bad.zip", map[string][]byte{"p2.bin": []byte("wrong-two"), "p3.bin": p3}))},
	} {
		t.Run(name, func(t *testing.T) {
			if err := validateMRAIdentityAndArchives(mra, "1943", "1943", bad, nil); err == nil {
				t.Fatal("invalid split archive fixtures accepted")
			}
		})
	}
}

func TestMiSTerArchiveReadsUseEffectiveNamedPartCandidates(t *testing.T) {
	root := t.TempDir()
	baseData, overrideData := []byte("base rom part"), []byte("override rom part")
	baseCRC := fmt.Sprintf("%08x", crc32.ChecksumIEEE(baseData))
	overrideCRC := fmt.Sprintf("%08x", crc32.ChecksumIEEE(overrideData))
	mraPath := filepath.Join(root, "effective.mra")
	mra := []byte(`<mame><setname>game</setname><rbf>jtcore</rbf>` +
		`<rom index="0" zip="base.zip"><part name="base.bin" crc="` + baseCRC + `"/><part name="override.bin" zip="override.zip" crc="` + overrideCRC + `"/><part zip="unused-part.zip">01 02 FF</part></rom>` +
		`<rom index="1" zip="unused-rom.zip"><part>04 05 FE</part></rom></mame>`)
	if err := os.WriteFile(mraPath, mra, 0600); err != nil {
		t.Fatal(err)
	}
	base := testMiSTerZIPPayload(t, root, "base-data.zip", map[string][]byte{"base.bin": baseData})
	override := testMiSTerZIPPayload(t, root, "override-data.zip", map[string][]byte{"override.bin": overrideData})
	archives := []MiSTerAssetFile{
		testMiSTerAsset(FixtureROMArchive, "base.zip", base),
		testMiSTerAsset(FixtureROMArchive, "override.zip", override),
	}
	if err := validateMRAIdentityAndArchives(mraPath, "core", "game", archives, nil); err != nil {
		t.Fatalf("ROM default/part override with inline data was not accepted: %v", err)
	}
	var inventory mraInventory
	if err := xml.Unmarshal(mra, &inventory); err != nil {
		t.Fatal(err)
	}
	reads, err := effectiveMRAArchiveReads(inventory)
	if err != nil {
		t.Fatal(err)
	}
	if len(reads) != 2 || strings.Join(reads[0].candidates, "|") != "base.zip" || strings.Join(reads[1].candidates, "|") != "override.zip" {
		t.Fatalf("effective candidate context mismatch: %+v", reads)
	}
}

func TestMiSTerNamedPartWithoutEffectiveArchiveCandidatesRejects(t *testing.T) {
	root := t.TempDir()
	filename := filepath.Join(root, "missing.mra")
	data := []byte(`<mame><setname>game</setname><rbf>jtcore</rbf><rom index="0"><part name="missing.bin"/></rom></mame>`)
	if err := os.WriteFile(filename, data, 0600); err != nil {
		t.Fatal(err)
	}
	if err := validateMRAIdentityAndArchives(filename, "core", "game", nil, nil); err == nil || !strings.Contains(err.Error(), "no effective ZIP candidates") {
		t.Fatalf("named part without candidates should fail closed, got %v", err)
	}
}

func TestMiSTerMRAPartReadWindowsAndDefaultRAM(t *testing.T) {
	root := t.TempDir()
	full := []byte{0x10, 0x20, 0x30, 0x40}
	crc := fmt.Sprintf("%08x", crc32.ChecksumIEEE(full))
	archive := testMiSTerZIPPayload(t, root, "opaque.zip", map[string][]byte{"slice.bin": full, "ram.bin": full})
	archives := []MiSTerAssetFile{testMiSTerAsset(FixtureROMArchive, "base.zip", archive)}
	for name, partAttrs := range map[string]string{
		"hex-length-clamped": `offset="0x1" length="0x20"`,
		"offset-and-length":  `offset="1" length="2"`,
		"zero-length-rest":   `offset="0x2" length="0"`,
		"no-length-rest":     `offset="0x1"`,
	} {
		t.Run(name, func(t *testing.T) {
			mra := filepath.Join(root, name+".mra")
			part := `<part name="slice.bin" crc="` + crc + `" ` + partAttrs + `/>`
			if err := os.WriteFile(mra, []byte(`<mame><setname>1943</setname><rbf>jt1943</rbf><rom index="0" zip="base.zip">`+part+`</rom></mame>`), 0600); err != nil {
				t.Fatal(err)
			}
			if err := validateMRAIdentityAndArchives(mra, "1943", "1943", archives, nil); err != nil {
				t.Fatalf("Main-legal read window rejected: %v", err)
			}
		})
	}
	for name, attrs := range map[string]string{"outside": `offset="0x100"`, "malformed offset": `offset="nope"`, "malformed length": `length="-1"`} {
		t.Run(name, func(t *testing.T) {
			mra := filepath.Join(root, strings.ReplaceAll(name, " ", "-")+"-bad.mra")
			if err := os.WriteFile(mra, []byte(`<mame><setname>1943</setname><rbf>jt1943</rbf><rom index="0" zip="base.zip"><part name="slice.bin" `+attrs+`/></rom></mame>`), 0600); err != nil {
				t.Fatal(err)
			}
			if err := validateMRAIdentityAndArchives(mra, "1943", "1943", archives, nil); err == nil {
				t.Fatal("unusable or malformed read window accepted")
			}
		})
	}
	repeated := filepath.Join(root, "repeated.mra")
	repeatedMRA := `<mame><setname>1943</setname><rbf>jt1943</rbf><rom index="0" zip="base.zip"><part name="slice.bin" crc="` + crc + `" offset="0" length="1"/><part name="slice.bin" crc="` + crc + `" offset="2" length="1"/></rom></mame>`
	if err := os.WriteFile(repeated, []byte(repeatedMRA), 0600); err != nil {
		t.Fatal(err)
	}
	if err := validateMRAIdentityAndArchives(repeated, "1943", "1943", archives, nil); err != nil {
		t.Fatalf("repeated member slices rejected: %v", err)
	}
	ramMRA := filepath.Join(root, "ram-slice.mra")
	ramPart := `<rom index="2" zip="base.zip"><part name="ram.bin" crc="` + crc + `" offset="1" length="0x2"/></rom>`
	if err := os.WriteFile(ramMRA, []byte(`<mame><setname>1943</setname><rbf>jt1943</rbf>`+ramPart+`</mame>`), 0600); err != nil {
		t.Fatal(err)
	}
	ramPath := filepath.Join(root, "1943.RAM")
	if err := os.WriteFile(ramPath, full[1:3], 0600); err != nil {
		t.Fatal(err)
	}
	ramFixture := []MiSTerAssetFile{testMiSTerAsset(FixtureDefaultRAM, "1943.RAM", assetFixture{Path: ramPath, SHA256: mustFileSHAForAssets(t, ramPath)})}
	if err := validateMRAIdentityAndArchives(ramMRA, "1943", "1943", archives, ramFixture); err != nil {
		t.Fatalf("default RAM read window rejected: %v", err)
	}
}

func TestMiSTerMRARequiresDeclaredDefaultRAM(t *testing.T) {
	root := t.TempDir()
	mra := filepath.Join(root, "ram.mra")
	if err := os.WriteFile(mra, []byte(`<mame><setname>flstory</setname><rbf>jtflstory</rbf><rom index="2"><part>01 02 A0</part></rom></mame>`), 0600); err != nil {
		t.Fatal(err)
	}
	ramPath := filepath.Join(root, "FLSTORY.RAM")
	if err := os.WriteFile(ramPath, []byte{0x01, 0x02, 0xa0}, 0600); err != nil {
		t.Fatal(err)
	}
	ram := []MiSTerAssetFile{testMiSTerAsset(FixtureDefaultRAM, "FLSTORY.RAM", assetFixture{Path: ramPath, SHA256: mustFileSHAForAssets(t, ramPath)})}
	if err := validateMRAIdentityAndArchives(mra, "flstory", "flstory", nil, ram); err != nil {
		t.Fatal(err)
	}
	if err := validateMRAIdentityAndArchives(mra, "flstory", "flstory", nil, nil); err == nil {
		t.Fatal("missing MRA default RAM accepted")
	}
	wrong := append([]MiSTerAssetFile(nil), ram...)
	wrong[0].Name = "OTHER.RAM"
	if err := validateMRAIdentityAndArchives(mra, "flstory", "flstory", nil, wrong); err == nil {
		t.Fatal("wrong logical RAM name accepted")
	}
}

func TestMiSTerNativeStatusProofUsesExactSelectedSetConfigPath(t *testing.T) {
	proof := MiSTerNativeStatusProof{MainSHA256: strings.Repeat("c", 64), ExpectedCoreName: "circusc", NativeStatusPath: "/media/fat/config/circusc.CFG"}
	if err := validateNativeStatusProof(proof, "circusc"); err != nil {
		t.Fatal(err)
	}
	for _, path := range []string{"/media/fat/config/circus.CFG", "/media/fat/config/circusc_v52.CFG", "/media/fat/config/../circusc.CFG"} {
		wrong := proof
		wrong.NativeStatusPath = path
		if err := validateNativeStatusProof(wrong, "circusc"); err == nil {
			t.Fatalf("wrong native status path %q accepted", path)
		}
	}
	versioned := proof
	versioned.ConfigVersion = 52
	versioned.NativeStatusPath = "/media/fat/config/circusc_v52.CFG"
	if err := validateNativeStatusProof(versioned, "circusc"); err != nil {
		t.Fatalf("source-derived versioned Main config path rejected: %v", err)
	}
	if err := validateNativeStatusProof(proof, "circus"); err == nil {
		t.Fatal("native status path for another selected set accepted")
	}
}

func TestPrepareMiSTerSessionUsesResolvedProfileAndExporter(t *testing.T) {
	root := t.TempDir()
	pinJTFRAMEForSourceTest(t, root, "circus", "JTFRAME_RATE=60.60\n")
	rbf := filepath.Join(root, "jtflstory.rbf")
	if err := os.WriteFile(rbf, []byte("rbf"), 0600); err != nil {
		t.Fatal(err)
	}
	mra := filepath.Join(root, "circus.mra")
	if err := os.WriteFile(mra, []byte(`<mame><name>Circus Charlie</name><setname>circusc</setname><rbf>jtcircus</rbf></mame>`), 0600); err != nil {
		t.Fatal(err)
	}
	proof := MiSTerNativeStatusProof{MainSHA256: strings.Repeat("c", 64), ExpectedCoreName: "circusc", NativeStatusPath: "/media/fat/config/circusc.CFG"}
	mraSHA := mustFileSHAForAssets(t, mra)
	assets := &MiSTerGameAssets{OriginalMRA: MiSTerAssetFile{Role: FixtureOriginalMRA, Name: "circus.mra", Path: mra, SHA256: mraSHA}, LaunchMRA: MiSTerAssetFile{Role: FixtureLaunchMRA, Name: "circus.mra", Path: mra, SHA256: mraSHA}, NativeStatus: proof}
	packed := testPackedCAB(t, 1, nil, 4000)
	packedPath := filepath.Join(root, "exported.jtcab")
	if err := os.WriteFile(packedPath, packed, 0600); err != nil {
		t.Fatal(err)
	}
	packer := filepath.Join(root, "cabinet_pack")
	script := "#!/bin/sh\ncp '" + strings.ReplaceAll(packedPath, "'", "'\\''") + "' \"$2\"\n"
	if err := os.WriteFile(packer, []byte(script), 0700); err != nil {
		t.Fatal(err)
	}
	cacheRBF := filepath.Join(root, "sha-cache-name.bin")
	if err := os.WriteFile(cacheRBF, []byte("rbf"), 0600); err != nil {
		t.Fatal(err)
	}
	spec := GameSpec{Setname: "circusc", RBF: cacheRBF, Profile: Profile{Setname: "circusc", Video: 4000, Startup: 500}, MisterAssets: assets}
	session, gotCAB, plan, err := PrepareMiSTerSession(context.Background(), "circus", spec, MiSTerSessionBuildOptions{SourceRoot: root, CabPacker: packer, Generation: "main-capture-v1", Convention: CaptureNativeNonRotatedRGB888, MainSHA256: proof.MainSHA256, MaxHoldMS: 100})
	if err != nil {
		t.Fatal(err)
	}
	if session.Core != "circus" || session.Setname != "circusc" || session.Checkpoints[0] != 500 || len(gotCAB) != len(packed) || len(plan) == 0 {
		t.Fatalf("unexpected prepared session or payloads: %+v", session)
	}
	if assets.NativeStatus.NativeStatusPath != "/media/fat/config/circusc.CFG" {
		t.Fatalf("preparation changed caller native status path: %q", assets.NativeStatus.NativeStatusPath)
	}
	if spec.MisterAssets.NativeStatus.NativeStatusPath != "/media/fat/config/circusc.CFG" {
		t.Fatal("preparation mutated caller-owned MisterAssets")
	}
	invalidSpec := spec
	invalidAssets := *assets
	invalidSpec.MisterAssets = &invalidAssets
	invalidAssets.NativeStatus.NativeStatusPath = "circusc.CFG"
	if err = validateMiSTerAssets("circus", "circusc", invalidSpec, session); err == nil {
		t.Fatal("prepared handoff accepted basename instead of exact absolute native config path")
	}
}

func TestExportMiSTerCABPreservesDIPCoinResetOrder(t *testing.T) {
	if _, err := exec.LookPath("c++"); err != nil {
		t.Skip("C++ compiler unavailable for cabinet_pack cross-check")
	}
	source, err := filepath.Abs(filepath.Join("..", "..", "..", "..", ".."))
	if err != nil {
		t.Fatal(err)
	}
	packer, err := build_mame_cab_packer(context.Background(), source)
	if err != nil {
		t.Fatal(err)
	}
	root := t.TempDir()
	cabSource := filepath.Join(root, "ordered.cab")
	input := []byte("100 coin\n1 reset\n3900\n")
	if err = os.WriteFile(cabSource, input, 0600); err != nil {
		t.Fatal(err)
	}
	candidate := mame_candidate{core: "flstory", set: "flstory", profile: Profile{Setname: "flstory", Video: 4002, Startup: 500, Options: map[string]interface{}{"dipsw": "aa"}}, cab_source: cabSource, cab_digest: assetSHA(input)}
	work := filepath.Join(root, "work")
	if err = os.Mkdir(work, 0700); err != nil {
		t.Fatal(err)
	}
	script, packed, err := exportMiSTerCAB(context.Background(), candidate, packer, work)
	if err != nil {
		t.Fatal(err)
	}
	if script.Version != 2 || len(script.Runs) != 4 || !script.Runs[0].HasDIPSW || script.Runs[0].DIPSW != 0xaa || script.Runs[1].Inputs&1 == 0 || script.Runs[2].Inputs&0x001000 == 0 {
		t.Fatalf("exported MiSTer CAB changed DIP/coin/reset order: %+v", script)
	}
	effective, err := os.ReadFile(filepath.Join(work, "profile-inputs.cab"))
	if err != nil {
		t.Fatal(err)
	}
	if string(effective) != "dipsw=aa\n100 coin\n1 reset\n3900\n" {
		t.Fatalf("effective CAB input order changed: %q", effective)
	}
	header, err := inspectPackedCAB(packed)
	if err != nil {
		t.Fatal(err)
	}
	entries, err := CapturePlanEntries(candidate.profile.Video, candidate.profile.Startup, 100, 1000)
	if err != nil {
		t.Fatal(err)
	}
	plan, err := EncodeCapturePlan(packed, entries)
	if err != nil {
		t.Fatal(err)
	}
	decoded, err := decodePreparedCapturePlan(plan, header, func() []uint32 {
		checkpoints := make([]uint32, len(entries))
		for i, e := range entries {
			checkpoints[i] = e.Checkpoint
		}
		return checkpoints
	}())
	if err != nil || decoded.PackedCABPayloadCRC32 != header.payloadCRC32 || decoded.TotalFrames != uint32(candidate.profile.Video) {
		t.Fatalf("JTCP does not bind exact DIP/reset CAB: plan=%+v err=%v", decoded, err)
	}
}

func TestMiSTerConfigStrictSafetyAndLegacyRead(t *testing.T) {
	root := t.TempDir()
	legacy := filepath.Join(root, "legacy.yaml")
	if err := os.WriteFile(legacy, []byte("root: /tmp/regression\nsource: /tmp/jtcores\n"), 0600); err != nil {
		t.Fatal(err)
	}
	if _, err := ReadConfig(legacy); err != nil {
		t.Fatalf("legacy board-free config rejected: %v", err)
	}
	base := "target: mister\nboards:\n  - id: board-a\n    host: 192.0.2.1\n    user: jt\n    ssh-config: /home/jt/.ssh/config\n    remote-staging-root: /tmp/regression\ncapture-contract:\n  generation: main-v1\n  convention: native-non-rotated-rgb888-v1\n  qualification-id: q1\n  qualification-evidence: /evidence/q1.json\n  main-sha256: " + strings.Repeat("a", 64) + "\n  command-timeout-seconds: 30\n  load-timeout-seconds: 60\n  capture-timeout-seconds: 120\n  cleanup-timeout-seconds: 30\n  max-hold-ms: 1000\n  expected-bridge-count: 2\n"
	good := filepath.Join(root, "mister.yaml")
	if err := os.WriteFile(good, []byte(base), 0600); err != nil {
		t.Fatal(err)
	}
	cfg, err := ReadConfig(good)
	if err != nil {
		t.Fatal(err)
	}
	if err = cfg.ValidateMiSTerRun(); err != nil {
		t.Fatal(err)
	}
	for name, body := range map[string]string{
		"unknown nested field":      strings.Replace(base, "    host:", "    secret: nope\n    host:", 1),
		"unsafe root":               strings.Replace(base, "/tmp/regression", "/tmp/../etc", 1),
		"duplicate normalized host": strings.Replace(base, "\ncapture-contract:", "\n  - id: board-b\n    host: 192.0.2.1\n    user: jt\n    ssh-config: /home/jt/.ssh/config\n    remote-staging-root: /tmp/other\ncapture-contract:", 1),
	} {
		t.Run(name, func(t *testing.T) {
			filename := filepath.Join(root, "bad.yaml")
			if err := os.WriteFile(filename, []byte(body), 0600); err != nil {
				t.Fatal(err)
			}
			if _, err := ReadConfig(filename); err == nil {
				t.Fatal("invalid MiSTer config accepted")
			}
		})
	}
}

func testMiSTerAsset(role FixtureRole, name string, file assetFixture) MiSTerAssetFile {
	return MiSTerAssetFile{Role: role, Name: name, Path: file.Path, SHA256: file.SHA256}
}

type assetFixture struct{ Path, SHA256 string }

func testMiSTerZIP(t *testing.T, root, cacheName, member string) assetFixture {
	return testMiSTerZIPPayload(t, root, cacheName, map[string][]byte{member: []byte("rom")})
}

func testMiSTerZIPPayload(t *testing.T, root, cacheName string, members map[string][]byte) assetFixture {
	t.Helper()
	filename := filepath.Join(root, cacheName)
	out, err := os.Create(filename)
	if err != nil {
		t.Fatal(err)
	}
	w := zip.NewWriter(out)
	for member, contents := range members {
		entry, createErr := w.Create(member)
		if createErr != nil {
			t.Fatal(createErr)
		}
		if _, err = entry.Write(contents); err != nil {
			t.Fatal(err)
		}
	}
	if err = w.Close(); err != nil {
		t.Fatal(err)
	}
	if err = out.Close(); err != nil {
		t.Fatal(err)
	}
	return assetFixture{Path: filename, SHA256: mustFileSHAForAssets(t, filename)}
}

func mustFileSHAForAssets(t *testing.T, filename string) string {
	t.Helper()
	digest, err := FileSHA256(filename)
	if err != nil {
		t.Fatal(err)
	}
	return digest
}
func assetSHA(data []byte) string {
	digest := sha256.Sum256(data)
	return hex.EncodeToString(digest[:])
}

func TestMiSTerZIPMemberLookupMatchesMainCRCThenPathOrder(t *testing.T) {
	root := t.TempDir()
	filename := filepath.Join(root, "nested.zip")
	file, err := os.Create(filename)
	if err != nil {
		t.Fatal(err)
	}
	writer := zip.NewWriter(file)
	for name, data := range map[string][]byte{
		"tmp/build/circusc/":           nil,
		"rom.bin":                      []byte("wrong-name-bytes"),
		"tmp/build/circusc/actual.bin": []byte("crc-selected-by-main"),
	} {
		entry, createErr := writer.Create(name)
		if createErr != nil {
			t.Fatal(createErr)
		}
		if _, createErr = entry.Write(data); createErr != nil {
			t.Fatal(createErr)
		}
	}
	if err = writer.Close(); err != nil {
		t.Fatal(err)
	}
	if err = file.Close(); err != nil {
		t.Fatal(err)
	}
	asset := MiSTerAssetFile{Role: FixtureROMArchive, Name: "nested.zip", Path: filename}
	asset.SHA256, err = FileSHA256(filename)
	if err != nil {
		t.Fatal(err)
	}
	selected := []byte("crc-selected-by-main")
	part := mraPart{Name: "rom.bin", CRC: fmt.Sprintf("%08x", crc32.ChecksumIEEE(selected))}
	got, err := readMRAArchivePart([]MiSTerAssetFile{asset}, "nested.zip", part)
	if err != nil || string(got) != string(selected) {
		t.Fatalf("CRC lookup did not precede literal-name fallback: %q %v", got, err)
	}
	if err = validateZipMembers(filename); err != nil {
		t.Fatalf("safe nested directory entry rejected: %v", err)
	}
	wrong := part
	wrong.CRC = "deadbeef"
	if _, err = readMRAArchivePart([]MiSTerAssetFile{asset}, "nested.zip", wrong); err == nil {
		t.Fatal("wrong nonzero MRA CRC accepted through literal-name fallback")
	}
	zero := mraPart{Name: "rom.bin", CRC: "00000000"}
	got, err = readMRAArchivePart([]MiSTerAssetFile{asset}, "nested.zip", zero)
	if err != nil || string(got) != "wrong-name-bytes" {
		t.Fatalf("zero CRC did not fall back to the literal path: %q %v", got, err)
	}
	nameFallback := []byte("literal-name-fallback")
	fallbackZIP := testMiSTerZIPPayload(t, root, "fallback.zip", map[string][]byte{"rom.bin": nameFallback})
	fallbackPart := mraPart{Name: "rom.bin", CRC: fmt.Sprintf("%08x", crc32.ChecksumIEEE(nameFallback))}
	got, err = readMRAArchivePart([]MiSTerAssetFile{testMiSTerAsset(FixtureROMArchive, "fallback.zip", fallbackZIP)}, "fallback.zip", fallbackPart)
	if err != nil || string(got) != string(nameFallback) {
		t.Fatalf("literal-name fallback after CRC search failed: %q %v", got, err)
	}
	traversalZIP := testMiSTerZIPPayload(t, root, "traversal.zip", map[string][]byte{"../escape/": nil, "ok.bin": []byte("ok")})
	if err = validateZipMembers(traversalZIP.Path); err == nil {
		t.Fatal("traversal directory member accepted")
	}
}
