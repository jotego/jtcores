/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */

package regression

import "testing"

func TestPreparedSessionCloneOwnsMutableInputs(t *testing.T) {
	source := preparedSessionFixture()
	worker := source.Clone()
	worker.Checkpoints[0] = 900
	worker.Fixtures[0].SHA256 = "worker-change"
	worker.Profile.Options["dipsw"].(map[string]interface{})["banks"].([]interface{})[0] = 99
	worker.Profile.Options["typed"].(map[interface{}]interface{})["list"].([]int)[0] = 88
	worker.Profile.Options["array"].([1][]int)[0][0] = 77
	if source.Checkpoints[0] != 100 || source.Fixtures[0].SHA256 == "worker-change" {
		t.Fatal("worker mutation changed coordinator-owned slices")
	}
	if source.Profile.Options["dipsw"].(map[string]interface{})["banks"].([]interface{})[0] != 1 {
		t.Fatal("worker mutation changed nested coordinator-owned profile data")
	}
	if source.Profile.Options["typed"].(map[interface{}]interface{})["list"].([]int)[0] != 3 {
		t.Fatal("worker mutation changed nested typed map/slice")
	}
	if source.Profile.Options["array"].([1][]int)[0][0] != 5 {
		t.Fatal("worker mutation changed nested slice inside an array")
	}
}

func TestPreparedSessionPortableIdentityExcludesPaths(t *testing.T) {
	base := preparedSessionFixture()
	first, err := base.PortableIdentity()
	if err != nil {
		t.Fatal(err)
	}
	secondSession := base.Clone()
	secondSession.Paths = SessionPaths{
		OriginalMRA: "/tmp/board-b/original.mra",
		LaunchMRA:   "/media/fat/launch-unique.mra",
		StagingDir:  "/tmp/attempt-b",
	}
	secondSession.Profile.Inputs = "/different/checkout/reg.cab"
	second, err := secondSession.PortableIdentity()
	if err != nil {
		t.Fatal(err)
	}
	if first != second {
		t.Fatalf("path-only staging difference changed portable identity: %s != %s", first, second)
	}
	ordered := secondSession.Clone()
	ordered.Fixtures = []FixtureDigest{
		{Role: FixtureDefaultRAM, SHA256: "9999999999999999999999999999999999999999999999999999999999999999"},
		{Role: FixtureROMArchive, SHA256: "dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd"},
	}
	orderedID, err := ordered.PortableIdentity()
	if err != nil {
		t.Fatal(err)
	}
	ordered.Fixtures[0], ordered.Fixtures[1] = ordered.Fixtures[1], ordered.Fixtures[0]
	permutedID, err := ordered.PortableIdentity()
	if err != nil {
		t.Fatal(err)
	}
	if orderedID != permutedID {
		t.Fatal("fixture declaration order changed portable identity")
	}
	changed := secondSession.Clone()
	changed.NativeVideoStatusSeed.SHA256 = "0000000000000000000000000000000000000000000000000000000000000000"
	third, err := changed.PortableIdentity()
	if err != nil {
		t.Fatal(err)
	}
	if third == first {
		t.Fatal("native status seed change did not affect portable identity")
	}
	changed = secondSession.Clone()
	changed.Convention = "rotated-rgb888-v1"
	fourth, err := changed.PortableIdentity()
	if err != nil {
		t.Fatal(err)
	}
	if fourth == first {
		t.Fatal("capture convention change did not affect portable identity")
	}
}

func TestPreparedSessionPortableIdentityExcludesLaunchPathDerivative(t *testing.T) {
	first := preparedSessionFixture()
	second := first.Clone()
	first.LaunchMRA.SHA256 = "1111111111111111111111111111111111111111111111111111111111111111"
	second.LaunchMRA.SHA256 = "2222222222222222222222222222222222222222222222222222222222222222"
	first.Paths.LaunchMRA = "/media/fat/run-a/circusc.mra"
	second.Paths.LaunchMRA = "/media/fat/run-b/circusc.mra"
	if err := first.Validate(); err != nil {
		t.Fatal(err)
	}
	if err := second.Validate(); err != nil {
		t.Fatal(err)
	}
	firstIdentity, err := first.PortableIdentity()
	if err != nil {
		t.Fatal(err)
	}
	secondIdentity, err := second.PortableIdentity()
	if err != nil {
		t.Fatal(err)
	}
	if firstIdentity != secondIdentity {
		t.Fatal("attempt-local launch MRA path derivative changed portable identity")
	}
	// Canonical MRA content remains part of portable identity.
	second.OriginalMRA.SHA256 = "3333333333333333333333333333333333333333333333333333333333333333"
	secondIdentity, err = second.PortableIdentity()
	if err != nil {
		t.Fatal(err)
	}
	if firstIdentity == secondIdentity {
		t.Fatal("canonical original MRA change did not affect portable identity")
	}
}

func TestPreparedSessionValidation(t *testing.T) {
	session := preparedSessionFixture()
	if err := session.Validate(); err != nil {
		t.Fatalf("valid prepared session rejected: %v", err)
	}
	cases := []struct {
		name string
		edit func(*PreparedSession)
	}{
		{"wrong native status seed", func(p *PreparedSession) { p.NativeVideoStatusSeed.SHA256 = "0" + p.NativeVideoStatusSeed.SHA256[1:] }},
		{"wrong capture mode", func(p *PreparedSession) { p.Convention = "rotated-rgb888-v1" }},
		{"wrong CAB frame budget", func(p *PreparedSession) { p.CAB.TotalFrames-- }},
		{"unordered checkpoint", func(p *PreparedSession) { p.Checkpoints = []uint32{100, 100} }},
		{"wrong MRA role", func(p *PreparedSession) { p.LaunchMRA.Role = FixtureOriginalMRA }},
		{"attempt-local fixture in canonical inputs", func(p *PreparedSession) { p.Fixtures = append(p.Fixtures, p.LaunchMRA) }},
		{"invalid fixture digest", func(p *PreparedSession) { p.Fixtures[0].SHA256 = "not-a-sha256" }},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			bad := session.Clone()
			tc.edit(&bad)
			if err := bad.Validate(); err == nil {
				t.Fatal("invalid session accepted")
			}
		})
	}
}

func TestNativeVideoStatusSeedIsExplicitAndStable(t *testing.T) {
	seed := CanonicalNativeVideoStatusSeed()
	if seed[0] != 0x04 {
		t.Fatalf("native status seed byte0=%02x, want 04", seed[0])
	}
	for i, value := range seed[1:] {
		if value != 0 {
			t.Fatalf("native status seed byte%d=%02x, want zero", i+1, value)
		}
	}
	fixture := NativeVideoStatusSeedFixture()
	if fixture.Role != FixtureNativeVideoStatusSeed || len(fixture.SHA256) != 64 {
		t.Fatalf("invalid native status seed fixture identity: %+v", fixture)
	}
}

func TestAttemptKeySeparatesBoardAndRetryNonce(t *testing.T) {
	base := AttemptKey{Board: "mister-home", SessionID: "run-42", Nonce: "attempt-1"}
	otherBoard := base
	otherBoard.Board = "mister2-home"
	retry := base
	retry.Nonce = "attempt-2"
	if base == otherBoard || base == retry || otherBoard == retry {
		t.Fatal("board and retry identity must distinguish attempts")
	}
}

func TestSessionCaptureCloneDetachesWorkerOutput(t *testing.T) {
	worker := SessionCapture{
		PNGPaths: []string{"/tmp/attempt/frame.png"},
		Events:   []SessionEvent{{Stage: "copy", Fields: map[string]string{"slot": "1"}}},
		Receipt:  CaptureReceipt{Images: []ImageReceipt{{RequestedFrame: 100, PNGPath: "/tmp/attempt/frame.png"}}},
	}
	coordinator := worker.Clone()
	coordinator.PNGPaths[0] = "/tmp/other/frame.png"
	coordinator.Events[0].Fields["slot"] = "2"
	coordinator.Receipt.Images[0].PNGPath = "/tmp/other/frame.png"
	if worker.PNGPaths[0] != "/tmp/attempt/frame.png" || worker.Events[0].Fields["slot"] != "1" || worker.Receipt.Images[0].PNGPath != "/tmp/attempt/frame.png" {
		t.Fatal("coordinator mutation changed worker-owned capture result")
	}
}

func TestSessionCaptureEnvelopeBoundsAndAttemptBinding(t *testing.T) {
	key := AttemptKey{Board: "board-a", SessionID: "session-a", Nonce: "nonce-a"}
	capture := SessionCapture{Key: key, Receipt: CaptureReceipt{SessionID: key.SessionID}}
	if err := capture.ValidateEnvelope(key); err != nil {
		t.Fatalf("valid empty envelope rejected: %v", err)
	}
	wrong := key
	wrong.Nonce = "late-result"
	if err := capture.ValidateEnvelope(wrong); err == nil {
		t.Fatal("stale worker attempt accepted")
	}
	capture.Events = make([]SessionEvent, MaxSessionEvents+1)
	if err := capture.ValidateEnvelope(key); err == nil {
		t.Fatal("unbounded event list accepted")
	}
	capture.Events = []SessionEvent{{Fields: make(map[string]string, MaxSessionEventFields+1)}}
	for i := 0; i <= MaxSessionEventFields; i++ {
		capture.Events[0].Fields[string(rune('a'+i))] = "v"
	}
	if err := capture.ValidateEnvelope(key); err == nil {
		t.Fatal("event with too many fields accepted")
	}
}

func preparedSessionFixture() PreparedSession {
	return PreparedSession{
		Core:    "circus",
		Setname: "circusc",
		Profile: Profile{Setname: "circusc", Video: 4000, Startup: 500, Inputs: "/source/reg.cab",
			Options: map[string]interface{}{"dipsw": map[string]interface{}{"banks": []interface{}{1, 2}},
				"typed": map[interface{}]interface{}{"list": []int{3, 4}},
				"array": [1][]int{{5, 6}}}},
		OriginalMRA:           FixtureDigest{Role: FixtureOriginalMRA, SHA256: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"},
		LaunchMRA:             FixtureDigest{Role: FixtureLaunchMRA, SHA256: "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"},
		RBF:                   FixtureDigest{Role: FixtureRBF, SHA256: "cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc"},
		NativeVideoStatusSeed: NativeVideoStatusSeedFixture(),
		Fixtures:              []FixtureDigest{{Role: FixtureROMArchive, SHA256: "dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd"}},
		CAB: CABIdentity{SourceSHA256: "eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee",
			EffectiveSHA256: "ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff",
			PackedSHA256:    "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
			PayloadCRC32:    0, ExporterVersion: "cabinet_pack/test", TotalFrames: 4000},
		Checkpoints: []uint32{100, 200, 4000},
		Generation:  "mister-capture-v1",
		Convention:  CaptureNativeNonRotatedRGB888,
	}
}
