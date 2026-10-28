/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */

package regression

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"encoding/xml"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"time"
)

// Outcome is the durable result for one main-game test.
type Outcome string

const (
	Pass        Outcome = "pass"
	New         Outcome = "new"
	Fail        Outcome = "fail"
	Error       Outcome = "error"
	Unsupported Outcome = "unsupported"
	Pending     Outcome = "pending"
)

type Event struct {
	Time    time.Time `json:"time"`
	RunID   string    `json:"run_id"`
	Core    string    `json:"core,omitempty"`
	Setname string    `json:"setname,omitempty"`
	Stage   string    `json:"stage"`
	Outcome Outcome   `json:"outcome,omitempty"`
	Message string    `json:"message,omitempty"`
	Fields  any       `json:"fields,omitempty"`
}

type GameResult struct {
	Core         string        `json:"core,omitempty"`
	TestIdentity string        `json:"test_identity,omitempty"`
	Setname      string        `json:"setname"`
	RecordError  string        `json:"record_error,omitempty"`
	Outcome      Outcome       `json:"outcome"`
	Stage        string        `json:"stage,omitempty"`
	Message      string        `json:"message,omitempty"`
	Duration     time.Duration `json:"duration_ns,omitempty"`
	Started      time.Time     `json:"started,omitempty"`
	Finished     time.Time     `json:"finished,omitempty"`
	Attention    bool          `json:"attention"`
}

type BuildIdentity struct {
	Repository      string `json:"repository"`
	Workflow        string `json:"workflow"`
	WorkflowID      int64  `json:"workflow_id,omitempty"`
	RunID           string `json:"run_id"`
	RunNumber       int64  `json:"run_number,omitempty"`
	Attempt         string `json:"attempt"`
	SHA             string `json:"sha"`
	Ref             string `json:"ref"`
	Event           string `json:"event"`
	PR              int    `json:"pull_request,omitempty"`
	Artifact        string `json:"artifact"`
	ArtifactID      int64  `json:"artifact_id,omitempty"`
	ArtifactAPIHash string `json:"artifact_api_sha256,omitempty"`
	ArtifactSHA     string `json:"artifact_sha256,omitempty"`
	Conclusion      string `json:"conclusion"`
	ExpectedJobs    int    `json:"expected_jobs,omitempty"`
	SucceededJobs   int    `json:"succeeded_jobs,omitempty"`
}

type Summary struct {
	RunID            string         `json:"run_id"`
	Core             string         `json:"core"`
	Build            BuildIdentity  `json:"build"`
	Started          time.Time      `json:"started"`
	Finished         time.Time      `json:"finished,omitempty"`
	Duration         time.Duration  `json:"duration_ns,omitempty"`
	Status           string         `json:"status"`
	OperationalError string         `json:"operational_error,omitempty"`
	Config           map[string]any `json:"config"`
	Games            []GameResult   `json:"games"`
	Coverage         map[string]int `json:"coverage"`
	Resume           map[string]any `json:"resume"`
	Publication      map[string]any `json:"publication"`
	ReportURL        string         `json:"report_url,omitempty"`
}

type EventLog struct {
	mu               sync.Mutex
	RunID, Core, Dir string
	file             *os.File
}

func NewEventLog(root, runID, core string) (*EventLog, error) {
	dir := filepath.Join(root, "log", runID)
	if e := os.MkdirAll(dir, 0750); e != nil {
		return nil, e
	}
	f, e := os.OpenFile(filepath.Join(dir, "events.jsonl"), os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0640)
	if e != nil {
		return nil, e
	}
	return &EventLog{RunID: runID, Core: core, Dir: dir, file: f}, nil
}

func (l *EventLog) Write(event Event) error {
	l.mu.Lock()
	defer l.mu.Unlock()
	if event.Time.IsZero() {
		event.Time = time.Now().UTC()
	}
	if event.RunID == "" {
		event.RunID = l.RunID
	}
	if event.Core == "" {
		event.Core = l.Core
	}
	enc := json.NewEncoder(l.file)
	if e := enc.Encode(event); e != nil {
		return e
	}
	return l.file.Sync()
}

func (l *EventLog) Close() error { return l.file.Close() }

func WriteSummary(dir string, summary Summary) error {
	if e := os.MkdirAll(dir, 0750); e != nil {
		return e
	}
	data, e := json.MarshalIndent(summary, "", "  ")
	if e != nil {
		return e
	}
	if e = atomic_write(filepath.Join(dir, "summary.json"), append(data, '\n'), 0640); e != nil {
		return e
	}
	return WriteJUnit(filepath.Join(dir, "junit.xml"), summary)
}

type junitSuite struct {
	XMLName  xml.Name    `xml:"testsuite"`
	Name     string      `xml:"name,attr"`
	Tests    int         `xml:"tests,attr"`
	Failures int         `xml:"failures,attr"`
	Errors   int         `xml:"errors,attr"`
	Skipped  int         `xml:"skipped,attr"`
	Time     float64     `xml:"time,attr"`
	Cases    []junitCase `xml:"testcase"`
}
type junitCase struct {
	Name      string       `xml:"name,attr"`
	Classname string       `xml:"classname,attr"`
	Time      float64      `xml:"time,attr"`
	Failure   *junitDetail `xml:"failure,omitempty"`
	Error     *junitDetail `xml:"error,omitempty"`
	Skipped   *junitDetail `xml:"skipped,omitempty"`
}
type junitDetail struct {
	Message string `xml:"message,attr"`
	Text    string `xml:"chardata"`
}

func WriteJUnit(filename string, summary Summary) error {
	suite := junitSuite{Name: "jtutil regression " + summary.Core}
	for _, game := range summary.Games {
		if game.Outcome == Pending {
			continue
		}
		class := game.Core
		if class == "" {
			class = summary.Core
		}
		c := junitCase{Name: game.Setname, Classname: class, Time: game.Duration.Seconds()}
		suite.Tests++
		switch game.Outcome {
		case Fail:
			suite.Failures++
			c.Failure = &junitDetail{Message: "video mismatch", Text: game.Message}
		case Error:
			suite.Errors++
			c.Error = &junitDetail{Message: game.Stage, Text: game.Message}
		case New:
			suite.Skipped++
			c.Skipped = &junitDetail{Message: "missing approved reference", Text: "complete capture stored for manual validation under new/"}
		case Unsupported:
			suite.Skipped++
			c.Skipped = &junitDetail{Message: "unsupported on SiDi128", Text: game.Message}
		}
		suite.Cases = append(suite.Cases, c)
	}
	suite.Time = summary.Duration.Seconds()
	out, e := xml.MarshalIndent(suite, "", "  ")
	if e != nil {
		return e
	}
	out = append([]byte(xml.Header), append(out, '\n')...)
	return atomic_write(filename, out, 0640)
}

// PendingInventory seeds a complete manifest view before execution. This lets
// an interrupted multi-core run account for unvisited titles without claiming
// that they ran; WriteJUnit deliberately omits these pending records.
func PendingInventory(cores []CoreManifest) []GameResult {
	results := make([]GameResult, 0)
	for _, core := range cores {
		for _, game := range core.Games {
			results = append(results, GameResult{Core: core.Core, Setname: game.Setname, Outcome: Pending})
		}
	}
	return results
}

// ReplaceCoreResults replaces a core's seeded pending entries with its durable
// current state, preserving pending games and all not-yet-visited cores.
func ReplaceCoreResults(all []GameResult, core string, games map[string]GameResult) []GameResult {
	byName := make(map[string]GameResult, len(games))
	for name, result := range games {
		result.Core = core
		result.Setname = name
		byName[name] = result
	}
	seen := make(map[string]bool, len(all))
	merged := make([]GameResult, 0, len(all)+len(games))
	for _, result := range all {
		if result.Core == core {
			if current, ok := byName[result.Setname]; ok {
				merged = append(merged, current)
				seen[result.Setname] = true
			} else {
				// Batch.Run may fail before it initializes state for every title.
				// Keep the manifest's pending entry so the interrupted summary is
				// still complete without claiming that title ran.
				merged = append(merged, result)
				seen[result.Setname] = true
			}
			continue
		}
		merged = append(merged, result)
	}
	for name, result := range byName {
		if !seen[name] {
			merged = append(merged, result)
		}
	}
	return merged
}

// RestoreCampaignStart keeps the original start time across an interrupted or
// publication-only retry. Legacy runs without a summary can recover it from
// the earliest durable game start in per-core state files.
func RestoreCampaignStart(summaryPath, stateDir string, build BuildIdentity, fallback time.Time, launchSnapshots ...map[string]time.Time) time.Time {
	started := verifiedLaunchStart(summaryPath, build)
	if len(launchSnapshots) > 0 {
		if launchStart := launchSnapshots[0][buildIdentityKey(build)]; !launchStart.IsZero() && (started.IsZero() || launchStart.Before(started)) {
			started = launchStart
		}
	}
	if data, err := os.ReadFile(summaryPath); err == nil {
		var summary Summary
		if json.Unmarshal(data, &summary) == nil && sameResumeBuild(summary.Build, build) && !summary.Started.IsZero() {
			if started.IsZero() || summary.Started.Before(started) {
				started = summary.Started
			}
		}
	}
	entries, err := os.ReadDir(stateDir)
	if err == nil {
		for _, entry := range entries {
			if entry.IsDir() || !strings.HasSuffix(entry.Name(), ".json") || entry.Name() == "publication.json" {
				continue
			}
			state, err := ReadState(filepath.Join(stateDir, entry.Name()))
			if err != nil || !sameResumeBuild(state.Build, build) {
				continue
			}
			for _, result := range state.Games {
				if !result.Started.IsZero() && (started.IsZero() || result.Started.Before(started)) {
					started = result.Started
				}
			}
		}
	}
	if !started.IsZero() {
		return started
	}
	return fallback
}

// SnapshotLaunchStarts must run before automatic preparation rewrites a
// manifest with report-only provenance such as a newly resolved PR number.
// It preserves the exact manifest bytes authenticated by launch.json so later
// resumes can still account for the original process start time.
func SnapshotLaunchStarts(dataRoot, runSelector string) (map[string]time.Time, error) {
	starts := make(map[string]time.Time)
	logRoot := filepath.Join(dataRoot, "log")
	entries, err := os.ReadDir(logRoot)
	if os.IsNotExist(err) {
		return starts, nil
	}
	if err != nil {
		return nil, err
	}
	for _, entry := range entries {
		if !entry.IsDir() {
			continue
		}
		logDir := filepath.Join(logRoot, entry.Name())
		launchData, readErr := os.ReadFile(filepath.Join(logDir, "launch.json"))
		if readErr != nil {
			continue
		}
		var launch struct {
			RunID   string `json:"run_id"`
			Process struct {
				StartUTC time.Time `json:"os_start_time_utc"`
			} `json:"process"`
			Inputs struct {
				Manifest       string `json:"manifest"`
				ManifestSHA256 string `json:"manifest_sha256"`
			} `json:"inputs"`
		}
		if json.Unmarshal(launchData, &launch) != nil || launch.RunID != entry.Name() || launch.Process.StartUTC.IsZero() || launch.Inputs.Manifest == "" || len(launch.Inputs.ManifestSHA256) != 64 {
			continue
		}
		manifestPath := launch.Inputs.Manifest
		if !filepath.IsAbs(manifestPath) {
			manifestPath = filepath.Join(dataRoot, manifestPath)
		}
		manifestPath, err = filepath.Abs(manifestPath)
		if err != nil || !insideDirectory(dataRoot, manifestPath) {
			continue
		}
		snapshotPath := filepath.Join(logDir, "launch-manifest.json")
		manifestBytes, manifest, err := readLaunchManifest(snapshotPath, launch.Inputs.ManifestSHA256)
		if err != nil {
			return nil, fmt.Errorf("verify preserved launch manifest for %s: %w", launch.RunID, err)
		}
		if manifestBytes == nil {
			manifestBytes, manifest, err = readLaunchManifest(manifestPath, launch.Inputs.ManifestSHA256)
		}
		if err != nil {
			return nil, fmt.Errorf("verify launch manifest for %s: %w", launch.RunID, err)
		}
		if manifestBytes == nil {
			// Automatic preparation can enrich only the PR association after the
			// original launch. Reconstruct that exact prior manifest and accept it
			// only when the launch-recorded SHA256 matches byte for byte.
			currentBytes, currentErr := os.ReadFile(manifestPath)
			if currentErr == nil {
				var current Manifest
				if json.Unmarshal(currentBytes, &current) == nil && current.RunID == launch.RunID && current.Build.PR > 0 {
					reconstructed := current
					reconstructed.Build.PR = 0
					encoded, marshalErr := json.MarshalIndent(reconstructed, "", "  ")
					if marshalErr == nil {
						encoded = append(encoded, '\n')
						digest := sha256.Sum256(encoded)
						if strings.EqualFold(hex.EncodeToString(digest[:]), launch.Inputs.ManifestSHA256) {
							manifestBytes, manifest = encoded, reconstructed
						}
					}
				}
			}
		}
		if manifestBytes == nil || manifest.RunID != launch.RunID {
			if runSelector != "" && (strings.HasPrefix(launch.RunID, runSelector+"-attempt-") || launch.RunID == runSelector) {
				return nil, fmt.Errorf("cannot authenticate original launch manifest for selected run %s", launch.RunID)
			}
			continue
		}
		if runSelector != "" && manifest.Build.RunID != runSelector && fmt.Sprint(manifest.Build.RunNumber) != runSelector && launch.RunID != runSelector {
			continue
		}
		if err = preserveLaunchManifest(snapshotPath, manifestBytes, launch.Inputs.ManifestSHA256); err != nil {
			return nil, fmt.Errorf("preserve launch manifest for %s: %w", launch.RunID, err)
		}
		key := buildIdentityKey(manifest.Build)
		if previous := starts[key]; previous.IsZero() || launch.Process.StartUTC.Before(previous) {
			starts[key] = launch.Process.StartUTC
		}
	}
	return starts, nil
}

func readLaunchManifest(filename, expectedSHA string) ([]byte, Manifest, error) {
	var manifest Manifest
	data, err := os.ReadFile(filename)
	if os.IsNotExist(err) {
		return nil, manifest, nil
	}
	if err != nil {
		return nil, manifest, err
	}
	digest := sha256.Sum256(data)
	if !strings.EqualFold(hex.EncodeToString(digest[:]), expectedSHA) {
		return nil, manifest, nil
	}
	if err = json.Unmarshal(data, &manifest); err != nil {
		return nil, Manifest{}, err
	}
	return data, manifest, nil
}

func preserveLaunchManifest(filename string, data []byte, expectedSHA string) error {
	if _, err := os.Stat(filename); err == nil {
		existing, manifest, readErr := readLaunchManifest(filename, expectedSHA)
		if readErr != nil {
			return readErr
		}
		if existing == nil || manifest.RunID == "" {
			return fmt.Errorf("existing preserved manifest does not match launch digest")
		}
		return nil
	} else if !os.IsNotExist(err) {
		return err
	}
	if err := os.MkdirAll(filepath.Dir(filename), 0750); err != nil {
		return err
	}
	file, err := os.OpenFile(filename, os.O_CREATE|os.O_EXCL|os.O_WRONLY, 0640)
	if os.IsExist(err) {
		verified, manifest, verifyErr := readLaunchManifest(filename, expectedSHA)
		if verifyErr != nil {
			return verifyErr
		}
		if verified == nil || manifest.RunID == "" {
			return fmt.Errorf("concurrent preserved manifest does not match launch digest")
		}
		return nil
	}
	if err != nil {
		return err
	}
	if _, err = file.Write(data); err != nil {
		_ = file.Close()
		return err
	}
	if err = file.Sync(); err != nil {
		_ = file.Close()
		return err
	}
	return file.Close()
}

func insideDirectory(parent, filename string) bool {
	parent, errA := filepath.Abs(parent)
	filename, errB := filepath.Abs(filename)
	if errA != nil || errB != nil {
		return false
	}
	rel, err := filepath.Rel(parent, filename)
	return err == nil && rel != ".." && !strings.HasPrefix(rel, ".."+string(os.PathSeparator))
}

func buildIdentityKey(build BuildIdentity) string {
	data, _ := json.Marshal(definitionBuild(build))
	digest := sha256.Sum256(data)
	return hex.EncodeToString(digest[:])
}

func verifiedLaunchStart(summaryPath string, build BuildIdentity) time.Time {
	launchPath := filepath.Join(filepath.Dir(summaryPath), "launch.json")
	data, err := os.ReadFile(launchPath)
	if err != nil {
		return time.Time{}
	}
	var launch struct {
		RunID   string `json:"run_id"`
		Process struct {
			StartUTC time.Time `json:"os_start_time_utc"`
		} `json:"process"`
		Inputs struct {
			Manifest       string `json:"manifest"`
			ManifestSHA256 string `json:"manifest_sha256"`
		} `json:"inputs"`
	}
	if json.Unmarshal(data, &launch) != nil || launch.RunID == "" || launch.Process.StartUTC.IsZero() || launch.Inputs.Manifest == "" || len(launch.Inputs.ManifestSHA256) != 64 {
		return time.Time{}
	}
	runDir := filepath.Base(filepath.Dir(summaryPath))
	if launch.RunID != runDir {
		return time.Time{}
	}
	dataRoot := filepath.Dir(filepath.Dir(filepath.Dir(summaryPath)))
	manifestPath := launch.Inputs.Manifest
	if !filepath.IsAbs(manifestPath) {
		manifestPath = filepath.Join(dataRoot, manifestPath)
	}
	manifestPath, err = filepath.Abs(manifestPath)
	if err != nil {
		return time.Time{}
	}
	relative, err := filepath.Rel(dataRoot, manifestPath)
	if err != nil || relative == ".." || strings.HasPrefix(relative, ".."+string(os.PathSeparator)) {
		return time.Time{}
	}
	hash, err := FileSHA256(manifestPath)
	if err != nil || !strings.EqualFold(hash, launch.Inputs.ManifestSHA256) {
		return time.Time{}
	}
	manifestData, err := os.ReadFile(manifestPath)
	if err != nil {
		return time.Time{}
	}
	var manifest Manifest
	if json.Unmarshal(manifestData, &manifest) != nil || manifest.RunID != launch.RunID || !sameResumeBuild(manifest.Build, build) {
		return time.Time{}
	}
	return launch.Process.StartUTC
}

func atomic_write(filename string, data []byte, mode os.FileMode) error {
	if e := os.MkdirAll(filepath.Dir(filename), 0750); e != nil {
		return e
	}
	tmp := filename + ".tmp"
	f, e := os.OpenFile(tmp, os.O_CREATE|os.O_TRUNC|os.O_WRONLY, mode)
	if e != nil {
		return e
	}
	if _, e = f.Write(data); e != nil {
		f.Close()
		return e
	}
	if e = f.Sync(); e != nil {
		f.Close()
		return e
	}
	if e = f.Close(); e != nil {
		return e
	}
	if e = os.Rename(tmp, filename); e != nil {
		return fmt.Errorf("replace %s: %w", filename, e)
	}
	return nil
}
