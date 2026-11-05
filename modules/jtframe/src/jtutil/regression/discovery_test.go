/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */

package regression

import (
	"archive/zip"
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"encoding/xml"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestDiscoverBuildOldestCompleteAttemptAndReconsidersArtifactlessRun(t *testing.T) {
	old := ghCommand
	defer func() { ghCommand = old }()
	sha1 := strings.Repeat("1", 40)
	sha2 := strings.Repeat("2", 40)
	ghCommand = func(_ context.Context, args ...string) ([]byte, error) {
		joined := strings.Join(args, " ")
        if strings.Contains(joined,"workflows/compile-sidi128.yaml/runs") { return []byte(`[{"workflow_runs":[]}]`),nil }
		switch {
		case strings.Contains(joined, "workflows/compile-all.yaml/runs?per_page=100"):
			return []byte(fmt.Sprintf(`[{"workflow_runs":[
{"id":11,"name":"Compile all","workflow_id":195,"run_number":10,"run_attempt":1,"status":"completed","conclusion":"success","head_sha":"%s","head_branch":"old","event":"push","created_at":"2026-10-01T00:00:00Z"},
{"id":12,"name":"Compile all","workflow_id":195,"run_number":11,"run_attempt":2,"status":"in_progress","conclusion":"","head_sha":"%s","head_branch":"pending","event":"pull_request","created_at":"2026-10-02T00:00:00Z"},
{"id":13,"name":"Compile all","workflow_id":195,"run_number":12,"run_attempt":1,"status":"completed","conclusion":"success","head_sha":"%s","head_branch":"ready","event":"pull_request","created_at":"2026-10-03T00:00:00Z"}
]}]`, sha1, sha2, sha2)), nil
		case strings.HasPrefix(joined, "run view 11"):
			return []byte(fmt.Sprintf(`{"databaseId":11,"workflowName":"Compile all","workflowDatabaseId":195,"number":10,"attempt":1,"status":"completed","conclusion":"success","headSha":"%s","headBranch":"old","event":"push","jobs":[{"status":"completed","conclusion":"success"}]}`, sha1)), nil
		case strings.Contains(joined, "actions/runs/11/artifacts"):
			return []byte(`{"total_count":0,"artifacts":[]}`), nil
		case strings.HasPrefix(joined, "run view 13"):
			return []byte(fmt.Sprintf(`{"databaseId":13,"workflowName":"Compile all","workflowDatabaseId":195,"number":12,"attempt":1,"status":"completed","conclusion":"success","headSha":"%s","headBranch":"ready","event":"pull_request","pullRequests":[{"number":169}],"jobs":[{"status":"completed","conclusion":"success"},{"status":"completed","conclusion":"success"}]}`, sha2)), nil
		case strings.Contains(joined, "actions/runs/13/artifacts"):
			return []byte(`{"total_count":1,"artifacts":[{"id":1300,"name":"2222222.zip","expired":false,"digest":"sha256:abcd"}]}`), nil
		case strings.Contains(joined, "repos/jotego/jtcores/actions/runs/13"):
			return []byte(`{"pull_requests":[{"number":169}]}`), nil
		default:
			return nil, fmt.Errorf("unexpected gh command: %s", joined)
		}
	}
	got, err := discoverBuild(context.Background(), "jotego/jtcores", "")
	if err != nil {
		t.Fatal(err)
	}
	if got.RunID != "13" || got.Attempt != "1" || got.SHA != sha2 || got.PR != 169 || got.Artifact != "2222222.zip" || got.ArtifactID != 1300 || got.ExpectedJobs != 2 || got.SucceededJobs != 2 {
		t.Fatalf("wrong selected build: %+v", got)
	}
}

func TestGetEligibleRunListsArtifactsByRunAndKeepsAttemptMetadata(t *testing.T) {
	old := ghCommand
	defer func() { ghCommand = old }()
	const runID int64 = 40655576158
	const sourceSHA = "a405f1b955a06f10f75a5aafe2d7080d631e062e"
	job := `{"status":"completed","conclusion":"success"}`
	jobs := strings.TrimSuffix(strings.Repeat(job+",", 279), ",")
	ghCommand = func(_ context.Context, args ...string) ([]byte, error) {
		joined := strings.Join(args, " ")
        if strings.Contains(joined,"workflows/compile-sidi128.yaml/runs") { return []byte(`[{"workflow_runs":[]}]`),nil }
		switch {
		case strings.HasPrefix(joined, "run view 40655576158"):
			return []byte(fmt.Sprintf(`{"databaseId":40655576158,"workflowName":"Compile all","workflowDatabaseId":195081922,"number":676,"attempt":1,"status":"completed","conclusion":"success","headSha":"%s","headBranch":"jtcores-166","event":"workflow_dispatch","jobs":[%s]}`, sourceSHA, jobs)), nil
		case strings.Contains(joined, "repos/jotego/jtcores/actions/runs/40655576158/artifacts"):
			if strings.Contains(joined, "/attempts/") {
				t.Fatalf("artifact listing must not use a nonexistent attempt-specific endpoint: %s", joined)
			}
			return []byte(`{"total_count":1,"artifacts":[{"id":12807547611,"name":"a405f1b.zip","expired":false,"digest":"sha256:1d8319f3077299eebc33c2cf1bdda8212dd17704664430b8ac2deefce0a42839"}]}`), nil
		case strings.Contains(joined, "repos/jotego/jtcores/commits/"+sourceSHA+"/pulls"):
			return []byte(fmt.Sprintf(`[{"number":1689,"head":{"ref":"jtcores-166","sha":"%s"}}]`, sourceSHA)), nil
		case strings.Contains(joined, "repos/jotego/jtcores/actions/runs/40655576158"):
			return []byte(`{"pull_requests":[]}`), nil
		default:
			return nil, fmt.Errorf("unexpected gh command: %s", joined)
		}
	}
	got, err := getEligibleRun(context.Background(), "jotego/jtcores", runID)
	if err != nil {
		t.Fatal(err)
	}
	if got.RunID != "40655576158" || got.RunNumber != 676 || got.Attempt != "1" || got.ArtifactID != 12807547611 || got.Artifact != "a405f1b.zip" || got.ArtifactAPIHash != "1d8319f3077299eebc33c2cf1bdda8212dd17704664430b8ac2deefce0a42839" || got.ExpectedJobs != 279 || got.SucceededJobs != 279 {
		t.Fatalf("wrong selected run/artifact identity: %+v", got)
	}
}

func TestDispatchedPRAssociationLookupErrorsFailClosed(t *testing.T) {
	old := ghCommand
	defer func() { ghCommand = old }()
	const sourceSHA = "a405f1b955a06f10f75a5aafe2d7080d631e062e"
	for _, lookup := range []struct {
		name string
		body []byte
		err  error
		want string
	}{
		{name: "transient API failure", err: fmt.Errorf("temporary GitHub API 503"), want: "temporary GitHub API 503"},
		{name: "malformed JSON", body: []byte("not-json"), want: "decode commit PR association"},
	} {
		t.Run(lookup.name, func(t *testing.T) {
			ghCommand = func(_ context.Context, args ...string) ([]byte, error) {
				joined := strings.Join(args, " ")
        if strings.Contains(joined,"workflows/compile-sidi128.yaml/runs") { return []byte(`[{"workflow_runs":[]}]`),nil }
				switch {
				case strings.HasPrefix(joined, "run view 40655576158"):
					return []byte(fmt.Sprintf(`{"databaseId":40655576158,"workflowName":"Compile all","workflowDatabaseId":195081922,"number":676,"attempt":1,"status":"completed","conclusion":"success","headSha":"%s","headBranch":"jtcores-166","event":"workflow_dispatch","jobs":[{"status":"completed","conclusion":"success"}]}`, sourceSHA)), nil
				case strings.Contains(joined, "actions/runs/40655576158/artifacts"):
					return []byte(`{"total_count":1,"artifacts":[{"id":12807547611,"name":"a405f1b.zip","expired":false,"digest":"sha256:1d8319f3077299eebc33c2cf1bdda8212dd17704664430b8ac2deefce0a42839"}]}`), nil
				case strings.Contains(joined, "repos/jotego/jtcores/actions/runs/40655576158"):
					return []byte(`{"pull_requests":[]}`), nil
				case strings.Contains(joined, "repos/jotego/jtcores/commits/"+sourceSHA+"/pulls"):
					return lookup.body, lookup.err
				default:
					return nil, fmt.Errorf("unexpected gh command: %s", joined)
				}
			}
			if _, err := getEligibleRun(context.Background(), "jotego/jtcores", 40655576158); err == nil || !strings.Contains(err.Error(), lookup.want) {
				t.Fatalf("PR lookup error must fail build preparation closed, got %v", err)
			}
		})
	}
}

func TestPinnedRunNumberFallbackOnlyOnRunIDNotFound(t *testing.T) {
	old := ghCommand
	defer func() { ghCommand = old }()
	listCalls := 0
	ghCommand = func(_ context.Context, args ...string) ([]byte, error) {
		joined := strings.Join(args, " ")
        if strings.Contains(joined,"workflows/compile-sidi128.yaml/runs") { return []byte(`[{"workflow_runs":[]}]`),nil }
		switch {
		case strings.HasPrefix(joined, "run view 40655576158"):
			return nil, fmt.Errorf("gh run view: HTTP 403: forbidden")
		case strings.Contains(joined, "workflows/compile-all.yaml/runs"):
			listCalls++
			return []byte(`[]`), nil
		default:
			return nil, fmt.Errorf("unexpected gh request: %s", joined)
		}
	}
	_, err := discoverBuild(context.Background(), "jotego/jtcores", "40655576158")
	if err == nil || !strings.Contains(err.Error(), "HTTP 403") {
		t.Fatalf("expected original database-ID API error, got %v", err)
	}
	if listCalls != 0 {
		t.Fatalf("valid database-ID API error was incorrectly reinterpreted as run number (%d list calls)", listCalls)
	}
}

func TestPinnedRunNumberFallbackUsesLookupOnlyAfter404(t *testing.T) {
	old := ghCommand
	defer func() { ghCommand = old }()
	const sha = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
	var sawNumberLookup, sawArtifactList bool
	ghCommand = func(_ context.Context, args ...string) ([]byte, error) {
		joined := strings.Join(args, " ")
        if strings.Contains(joined,"workflows/compile-sidi128.yaml/runs") { return []byte(`[{"workflow_runs":[]}]`),nil }
		switch {
		case strings.HasPrefix(joined, "run view 676"):
			return nil, fmt.Errorf("gh run view: HTTP 404: Not Found")
		case strings.Contains(joined, "workflows/compile-all.yaml/runs"):
			sawNumberLookup = true
			return []byte(fmt.Sprintf(`[{"workflow_runs":[{"id":406,"name":"Compile all","workflow_id":195,"run_number":676,"run_attempt":2,"status":"completed","conclusion":"success","head_sha":"%s","head_branch":"release","event":"push","created_at":"2026-10-27T00:00:00Z"}]}]`, sha)), nil
		case strings.HasPrefix(joined, "run view 406"):
			return []byte(fmt.Sprintf(`{"databaseId":406,"workflowName":"Compile all","workflowDatabaseId":195,"number":676,"attempt":2,"status":"completed","conclusion":"success","headSha":"%s","headBranch":"release","event":"push","jobs":[{"status":"completed","conclusion":"success"}]}`, sha)), nil
		case strings.Contains(joined, "repos/jotego/jtcores/actions/runs/406/artifacts"):
			sawArtifactList = true
			return []byte(`{"total_count":1,"artifacts":[{"id":987,"name":"aaaaaaa.zip","expired":false,"digest":"sha256:feed"}]}`), nil
		case strings.Contains(joined, "repos/jotego/jtcores/actions/runs/406"):
			return []byte(`{"pull_requests":[]}`), nil
		default:
			return nil, fmt.Errorf("unexpected gh request: %s", joined)
		}
	}
	got, err := discoverBuild(context.Background(), "jotego/jtcores", "676")
	if err != nil {
		t.Fatal(err)
	}
	if !sawNumberLookup || !sawArtifactList || got.RunID != "406" || got.RunNumber != 676 || got.Attempt != "2" || got.ArtifactID != 987 {
		t.Fatalf("run-number selector did not resolve exact run/attempt/artifact: %+v lookup=%v artifacts=%v", got, sawNumberLookup, sawArtifactList)
	}
}

func TestDiscoverBuildRejectsFailedOrIncompletePinnedRun(t *testing.T) {
	old := ghCommand
	defer func() { ghCommand = old }()
	ghCommand = func(_ context.Context, args ...string) ([]byte, error) {
		if strings.HasPrefix(strings.Join(args, " "), "run view") {
			return []byte(`{"databaseId":4,"workflowName":"Compile all","workflowDatabaseId":8,"number":4,"attempt":1,"status":"completed","conclusion":"success","headSha":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","jobs":[{"status":"completed","conclusion":"success"},{"status":"in_progress","conclusion":""}]}`), nil
		}
		return nil, fmt.Errorf("unexpected gh request")
	}
	if _, err := getEligibleRun(context.Background(), "jotego/jtcores", 4); err == nil || !strings.Contains(err.Error(), "incomplete or failed job") {
		t.Fatalf("expected incomplete job rejection, got %v", err)
	}
}

func TestProcessedLedgerIsAttemptSpecific(t *testing.T) {
	root := t.TempDir()
	dir := filepath.Join(root, "log", "406-attempt-1")
	if err := os.MkdirAll(dir, 0750); err != nil {
		t.Fatal(err)
	}
	summary := struct {
		RunID  string        `json:"run_id"`
		Status string        `json:"status"`
		Build  BuildIdentity `json:"build"`
	}{RunID: "406", Status: "complete", Build: BuildIdentity{RunID: "406", Attempt: "1"}}
	data, err := json.Marshal(summary)
	if err != nil {
		t.Fatal(err)
	}
	if err = os.WriteFile(filepath.Join(dir, "summary.json"), data, 0640); err != nil {
		t.Fatal(err)
	}
	if !buildAlreadyComplete(root, "406", "1") {
		t.Fatal("completed attempt was not found in ledger")
	}
	if buildAlreadyComplete(root, "406", "2") {
		t.Fatal("a later attempt must remain eligible")
	}
}

func TestExtractRBFTreeSelectsOnlySiDi128Target(t *testing.T) {
	root := t.TempDir()
	archive := filepath.Join(root, "build.zip")
	file, err := os.Create(archive)
	if err != nil {
		t.Fatal(err)
	}
	w := zip.NewWriter(file)
	for name, body := range map[string]string{"release/sidi/jtfoo.rbf": "sidi", "release/sidi128/jtfoo.rbf": "sidi128"} {
		entry, e := w.Create(name)
		if e != nil {
			t.Fatal(e)
		}
		if _, e = entry.Write([]byte(body)); e != nil {
			t.Fatal(e)
		}
	}
	if err = w.Close(); err != nil {
		t.Fatal(err)
	}
	if err = file.Close(); err != nil {
		t.Fatal(err)
	}
	digest := sha256.Sum256([]byte("sidi128"))
	source := filepath.Join(root, "project")
	rbfs, err := extract_build_archive(archive, source)
	dir := filepath.Join(source, "release", "sidi128")
	if err != nil {
		t.Fatal(err)
	}
	got, err := os.ReadFile(filepath.Join(dir, "jtfoo.rbf"))
	if err != nil {
		t.Fatal(err)
	}
	if rbfs["jtfoo.rbf"] != hex.EncodeToString(digest[:]) { t.Fatal("wrong RBF identity") }
	if string(got) != "sidi128" {
		t.Fatalf("selected wrong target RBF: %q", got)
	}
}

func TestExtractRBFTreeRejectsSiDiOnlyArtifact(t *testing.T) {
	root := t.TempDir()
	archive := filepath.Join(root, "build.zip")
	file, err := os.Create(archive)
	if err != nil {
		t.Fatal(err)
	}
	w := zip.NewWriter(file)
	entry, err := w.Create("release/sidi/jtfoo.rbf")
	if err != nil {
		t.Fatal(err)
	}
	_, _ = entry.Write([]byte("wrong target"))
	_ = w.Close()
	_ = file.Close()
	if _, err = extract_build_archive(archive, filepath.Join(root, "project")); err == nil || !strings.Contains(err.Error(), "no release/sidi128") {
		t.Fatalf("expected strict target rejection, got %v", err)
	}
}

func TestPrepareArtifactDownloadsExactArtifactIDAndChecksBothIdentities(t *testing.T) {
	old := ghArtifactDownload
	defer func() { ghArtifactDownload = old }()
	root := t.TempDir()
	inner := filepath.Join(root, "inner.zip")
	writeZip(t, inner, map[string]string{"release/sidi/jtfoo.rbf": "wrong", "release/sidi128/jtfoo.rbf": "correct"})
	wrapper := filepath.Join(root, "service.zip")
	writeZip(t, wrapper, map[string]string{"a405f1b.zip": readString(t, inner)})
	apiHash, err := fileSHA256(wrapper)
	if err != nil {
		t.Fatal(err)
	}
	ghArtifactDownload = func(_ context.Context, repo string, id int64, destination string) error {
		if repo != "jotego/jtcores" || id != 765 {
			t.Fatalf("wrong artifact identity: %s %d", repo, id)
		}
		return copyFile(wrapper, destination)
	}
	id := BuildIdentity{Repository: "jotego/jtcores", RunID: "456", RunNumber: 77, Attempt: "2", SHA: "a405f1b"+strings.Repeat("a", 33), Artifact: "a405f1b.zip", ArtifactID: 765, ArtifactAPIHash: apiHash}
	buildDir := filepath.Join(root, "data", "builds", id.RunID)
	artifact, rbfs, err := prepareArtifact(context.Background(), Config{Source:filepath.Join(root,"project"),BuildsDir:filepath.Join(root,"store")}, buildDir, id)
	if err != nil {
		t.Fatal(err)
	}
	payloadHash, err := fileSHA256(artifact)
	if err != nil {
		t.Fatal(err)
	}
	manifest, err := os.ReadFile(filepath.Join(buildDir, "build-manifest.json"))
	if err != nil {
		t.Fatal(err)
	}
	var stored struct {
		RunID           string `json:"run_id"`
		Attempt         string `json:"attempt"`
		SHA             string `json:"source_sha"`
		ArtifactID      int64  `json:"artifact_id"`
		ArtifactSHA     string `json:"artifact_sha256"`
		ArtifactAPIHash string `json:"artifact_api_sha256"`
	}
	if err = json.Unmarshal(manifest, &stored); err != nil {
		t.Fatal(err)
	}
	if stored.RunID != id.RunID || stored.Attempt != id.Attempt || stored.SHA != id.SHA || stored.ArtifactID != id.ArtifactID || stored.ArtifactSHA != payloadHash || stored.ArtifactAPIHash != apiHash {
		t.Fatalf("wrong cached identity: %+v", stored)
	}
	got, err := os.ReadFile(filepath.Join(rbfs, "jtfoo.rbf"))
	if err != nil {
		t.Fatal(err)
	}
	if string(got) != "correct" {
		t.Fatalf("wrong target RBF selected: %q", got)
	}
}

func TestMainOnlyInventoryFailsClosedWhenSupportedCoreProducesNoMRA(t *testing.T) {
	old := jtframeMRACommand
	defer func() { jtframeMRACommand = old }()
	jtframeMRACommand = func(context.Context, string, string, string, bool) ([]byte, error) {
		return []byte("simulated project parse failure"), fmt.Errorf("exit 1")
	}
	root := t.TempDir()
	source := filepath.Join(root, "source")
	core := filepath.Join(source, "cores", "fake", "cfg")
	if err := os.MkdirAll(core, 0750); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(core, "mame2mra.toml"), []byte("[parse]\n"), 0640); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(core, "macros.def"), []byte("JTFRAME_BUTTONS=2\n"), 0640); err != nil {
		t.Fatal(err)
	}
	rbf := filepath.Join(root, "release", "sidi128")
	if err := os.MkdirAll(rbf, 0750); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(rbf, "jtfake.rbf"), []byte("rbf"), 0640); err != nil {
		t.Fatal(err)
	}
	// An old artifact-fallback MRA must never be mistaken for output from the
	// current working-project core command.
	stale := filepath.Join(root, "fixtures", "mainonly-mra", "artifact")
	if err := os.MkdirAll(stale, 0750); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(stale, "stale.mra"), []byte(`<misterromdescription><setname>stale</setname><rbf>jtfake</rbf></misterromdescription>`), 0640); err != nil {
		t.Fatal(err)
	}
	// Even a same-core MRA created just before the command is stale unless
	// that command emits it. The live project's unrelated outputs survive.
	live_mra := filepath.Join(source, "release", "mra")
	if err := os.MkdirAll(live_mra, 0750); err != nil { t.Fatal(err) }
	stale_live := filepath.Join(live_mra, "stale-current-core.mra")
	unrelated := filepath.Join(live_mra, "other.mra")
	for path, contents := range map[string]string{stale_live:`<mra><setname>stale</setname><rbf>jtfake</rbf></mra>`, unrelated:`<mra><setname>other</setname><rbf>jtother</rbf></mra>`} {
		if err := os.WriteFile(path, []byte(contents), 0600); err != nil { t.Fatal(err) }
	}
	artifact := filepath.Join(root, "artifact.zip")
	writeZip(t, artifact, map[string]string{})
	_, _, err := mainGameInventory(context.Background(), source, rbf, filepath.Join(root, "fixtures"), artifact, BuildIdentity{}, Config{ROMSource: filepath.Join(root, "missing-roms")})
	if err == nil || !strings.Contains(err.Error(), "no project MRA titles were generated for supported RBF cores fake") {
		t.Fatalf("incomplete core inventory must fail closed, got %v", err)
	}
	if _, err := os.Stat(stale_live); err != nil { t.Fatalf("existing same-core MRA removed: %v", err) }
	if _, err := os.Stat(unrelated); err != nil { t.Fatalf("unrelated MRA removed: %v", err) }
}

func TestMRAAllPartsIncludesNestedInterleave(t *testing.T) {
	var m mraInventory
	data := []byte(`<misterromdescription><setname>x</setname><rbf>jtx</rbf><rom index="0" zip="x.zip"><part name="direct.bin" crc="00000001"/><interleave output="16"><part name="nested.bin" crc="00000002"/></interleave></rom></misterromdescription>`)
	if err := xml.Unmarshal(data, &m); err != nil {
		t.Fatal(err)
	}
	if len(m.ROM) != 1 || len(m.ROM[0].AllParts()) != 2 {
		t.Fatalf("nested MRA parts missing: %+v", m.ROM)
	}
}

func TestReviewedMRAExitRequiresExactKnownDiagnostics(t *testing.T) {
	known := "exit status 1: Warning: Game sjryuko (in JTS16B) uses 23 buttons but JTFRAME_BUTTONS is set to 5\ns16b: ROM region \"soundcpu:key\" does not match any MAME region in applicable sets: aliensyn, altbeast, aurail, bayroute, bullet, cotton, ddux, dunkshot, eswat, exctleag, fantzn2x, fpoint, goldnaxe, mvp, passsht, riotcity, ryukyu, sjryuko, sonicbom, suprleag, timescan, toryumon, tturfu, wb3, wrestwar"
	if code, ok := reviewedMRAExit("s16b", known); !ok || code != "post-emission-unused-region-soundcpu-key" {
		t.Fatalf("known reviewed lint should classify as warning, code=%q ok=%v", code, ok)
	}
	unknown := known + "\ns16b: unrelated ROM region \"other:key\" does not match any MAME region"
	if _, ok := reviewedMRAExit("s16b", unknown); ok {
		t.Fatal("unknown additional region failure must not be downgraded")
	}
	if _, ok := reviewedMRAExit("s16b", known+"\nmissing macro foo"); ok {
		t.Fatal("unrelated diagnostic line must not be downgraded")
	}
	if _, ok := reviewedMRAExit("s16b", strings.Replace(known, "exit status 1:", "exit status 2:", 1)); ok {
		t.Fatal("nonstandard command exit must remain an error")
	}
}

func TestSameMainMRAIdentityPreservesXMLChildOrderAndIgnoresOnlyAsmMD5(t *testing.T) {
	root := t.TempDir()
	partFirst := `<mra><setname>test</setname><rbf>jttest</rbf><rom index="0" zip="game.zip" asm_md5="source"><part name="main.bin" crc="12345678"/><interleave output="16"><part name="second.bin" crc="87654321" map="01"/></interleave></rom></mra>`
	asmOnlyChange := strings.Replace(partFirst, `asm_md5="source"`, `asm_md5="artifact"`, 1)
	orderChanged := `<mra><setname>test</setname><rbf>jttest</rbf><rom index="0" zip="game.zip" asm_md5="artifact"><interleave output="16"><part name="second.bin" crc="87654321" map="01"/></interleave><part name="main.bin" crc="12345678"/></rom></mra>`
	a := filepath.Join(root, "a.mra")
	b := filepath.Join(root, "b.mra")
	c := filepath.Join(root, "c.mra")
	for path, contents := range map[string]string{a: partFirst, b: asmOnlyChange, c: orderChanged} {
		if err := os.WriteFile(path, []byte(contents), 0640); err != nil {
			t.Fatal(err)
		}
	}
	if err := sameMainMRAIdentity(a, b); err != nil {
		t.Fatalf("asm_md5 is the only permitted volatile index-0 field: %v", err)
	}
	if err := sameMainMRAIdentity(a, c); err == nil {
		t.Fatal("reordered direct/interleave children must block warning downgrade")
	}
}

func TestInventoryReconciliationJustifiesSourceOnlyExtrasAndAlternateMappings(t *testing.T) {
	artifact := []InventoryTuple{{Core: "arblst", Setname: "arbalest", RBF: "jtarblst"}, {Core: "arblst", Setname: "metafox", RBF: "jtarblst"}}
	source := []InventoryTuple{{Core: "cal50", Setname: "arbalest", RBF: "jtcal50"}, {Core: "cal50", Setname: "metafox", RBF: "jtcal50"}, {Core: "moo", Setname: "bucky", RBF: "jtmoo"}, {Core: "moo", Setname: "moomesa", RBF: "jtmoo"}}
	why := justifySourceOnly(source, artifact)
	if len(why) != 4 || !strings.Contains(why[tupleKey(source[0])], "maps the same setname") || !strings.Contains(why[tupleKey(source[2])], "source-only setname bucky") {
		t.Fatalf("source-only tuples lack auditable reasons: %+v", why)
	}
	names, alternate := classifySourceOnly(source, artifact)
	if len(names) != 2 || len(alternate) != 2 || uniqueSetnameCount(source) != 4 || uniqueSetnameCount(artifact) != 2 {
		t.Fatalf("bad reconciliation summary names=%v alternate=%v", names, alternate)
	}
}

func TestGeneratedMRATupleSeparatesSameSetAcrossCores(t *testing.T) {
	root := t.TempDir()
	writeMRA := func(filename, rbf string) {
		t.Helper()
		data := fmt.Sprintf(`<misterromdescription><setname>arbalest</setname><rbf>%s</rbf></misterromdescription>`, rbf)
		if err := os.WriteFile(filepath.Join(root, filename), []byte(data), 0640); err != nil {
			t.Fatal(err)
		}
	}
	writeMRA("cal50.mra", "jtcal50")
	writeMRA("arblst.mra", "jtarblst")
	if err := generatedMRATuple(root, "cal50", "arbalest", "jtcal50"); err != nil {
		t.Fatal(err)
	}
	if err := generatedMRATuple(root, "arblst", "arbalest", "jtarblst"); err != nil {
		t.Fatal(err)
	}
	if err := generatedMRATuple(root, "cal50", "arbalest", "jtarblst"); err == nil {
		t.Fatal("wrong core/RBF tuple accepted for duplicate setname")
	}
}

func TestStandardROMRejectsSameSetOverwrittenByAnotherCore(t *testing.T) {
	root := t.TempDir()
	mraRoot := filepath.Join(root, "release", "mra")
	if err := os.MkdirAll(mraRoot, 0750); err != nil {
		t.Fatal(err)
	}
	if err := os.MkdirAll(filepath.Join(root, "rom"), 0750); err != nil {
		t.Fatal(err)
	}
	writeTupleMRA := func(rbf string) {
		t.Helper()
		data := fmt.Sprintf(`<misterromdescription><setname>arbalest</setname><rbf>%s</rbf></misterromdescription>`, rbf)
		if err := os.WriteFile(filepath.Join(mraRoot, "arbalest.mra"), []byte(data), 0640); err != nil {
			t.Fatal(err)
		}
	}
	romPath := filepath.Join(root, "rom", "arbalest.rom")
	writeTupleMRA("jtcal50")
	if err := os.WriteFile(romPath, []byte("cal50 ROM"), 0640); err != nil {
		t.Fatal(err)
	}
	calROM, err := generatedROMForTuple(root, "cal50", "arbalest", "jtcal50")
	if err != nil {
		t.Fatal(err)
	}
	digest, err := fileSHA256(calROM)
	if err != nil { t.Fatal(err) }
	game := GameSpec{ROMs: []string{calROM}, PreparedHashes: map[string]string{calROM:digest}}
	writeTupleMRA("jtarblst")
	if err = os.WriteFile(romPath, []byte("arblst ROM"), 0640); err != nil {
		t.Fatal(err)
	}
	if _, err = generatedROMForTuple(root, "cal50", "arbalest", "jtcal50"); err == nil {
		t.Fatal("stale flat ROM accepted with a different generated MRA tuple")
	}
	arbROM, err := generatedROMForTuple(root, "arblst", "arbalest", "jtarblst")
	if err != nil {
		t.Fatal(err)
	}
	if arbROM != romPath { t.Fatalf("nonstandard ROM path: %s", arbROM) }
	if err = verify_prepared_files(game); err == nil {
		t.Fatal("accepted prepared ROM overwritten by another core")
	}
}

func writeZip(t *testing.T, path string, entries map[string]string) {
	t.Helper()
	f, err := os.Create(path)
	if err != nil {
		t.Fatal(err)
	}
	w := zip.NewWriter(f)
	for name, source := range entries {
		entry, e := w.Create(name)
		if e != nil {
			t.Fatal(e)
		}
		var content []byte
		if info, e := os.Stat(source); e == nil && info.Mode().IsRegular() {
			content, e = os.ReadFile(source)
			if e != nil {
				t.Fatal(e)
			}
		} else {
			content = []byte(source)
		}
		if _, e = entry.Write(content); e != nil {
			t.Fatal(e)
		}
	}
	if err = w.Close(); err != nil {
		t.Fatal(err)
	}
	if err = f.Close(); err != nil {
		t.Fatal(err)
	}
}

func readString(t *testing.T, path string) string {
	t.Helper()
	data, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	return string(data)
}
