/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */

package cmd

import (
	"encoding/hex"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"

	"github.com/spf13/cobra"
	"jtutil/regression"
)

var regressionConfig string
var regressionManifest string
var regressionRunID string
var regressionInitialBaseline bool
var regressionNoPublish bool
var regressionRetryErrors bool

var regressionCmd = &cobra.Command{
	Use:   "regression",
	Short: "Run or resume a SiDi128 video regression batch",
	Long: `Discovers and prepares a successful compile_all build, then runs or resumes its SiDi128 regression.
All durable state, logs, and result folders are stored below $JOTEGO/regression.
Use --initial-baseline only for the explicitly authorized initial baseline run.`,
	Args: cobra.NoArgs,
	RunE: run_regression_cmd,
}

func init() {
	regressionCmd.Flags().StringVar(&regressionConfig, "config", "", "Portable regression config YAML")
	regressionCmd.Flags().StringVar(&regressionManifest, "manifest", "", "Build-specific inventory manifest JSON")
	regressionCmd.Flags().StringVar(&regressionRunID, "run-id", "", "Pin a GitHub Actions run ID or run number")
	regressionCmd.Flags().BoolVar(&regressionInitialBaseline, "initial-baseline", false, "Create missing approved refs for initial build #676 only")
	regressionCmd.Flags().BoolVar(&regressionNoPublish, "no-publish", false, "Do not publish GitHub summary (local pilot only)")
	regressionCmd.Flags().BoolVar(&regressionRetryErrors, "retry-errors", false, "Rerun terminal per-game errors from a fresh ARC launch")
	rootCmd.AddCommand(regressionCmd)
}

func run_regression_cmd(cmd *cobra.Command, args []string) error {
	root := os.Getenv("JOTEGO")
	if root == "" {
		return fmt.Errorf("JOTEGO must name the private regression data directory")
	}
	if regressionConfig == "" {
		regressionConfig = filepath.Join(root, "regression", "config.yaml")
	}
	config, e := regression.ReadConfig(regressionConfig)
	if e != nil {
		return fmt.Errorf("parse config: %w", e)
	}
	dataRoot := filepath.Join(root, "regression")
	if config.Root != "" {
		rootAbs, err := filepath.Abs(dataRoot)
		if err != nil {
			return err
		}
		configured, err := filepath.Abs(config.Root)
		if err != nil {
			return err
		}
		if configured != rootAbs {
			return fmt.Errorf("all persistent data must remain under JOTEGO/regression (%s)", rootAbs)
		}
	}
	lock, e := regression.AcquireLock(dataRoot)
	if e != nil {
		return e
	}
	defer regression.ReleaseLock(lock)
	launchStarts, e := regression.SnapshotLaunchStarts(dataRoot, regressionRunID)
	if e != nil {
		return fmt.Errorf("verify and preserve prior launch manifest: %w", e)
	}
	if config.Source == "" {
		config.Source = os.Getenv("JTROOT")
	}
	if config.Source == "" {
		return fmt.Errorf("config source or JTROOT is required")
	}
	var manifest regression.Manifest
	if regressionManifest == "" {
		manifest, e = regression.Prepare(cmd.Context(), config, dataRoot, regressionRunID)
		if e != nil {
			return fmt.Errorf("prepare regression build and inventory: %w", e)
		}
		manifestPath := filepath.Join(dataRoot, "builds", manifest.Build.RunID, "manifest.json")
		if e = os.MkdirAll(filepath.Dir(manifestPath), 0750); e != nil {
			return e
		}
		manifestBytes, marshalErr := json.MarshalIndent(manifest, "", "  ")
		if marshalErr != nil {
			return marshalErr
		}
		if e = os.WriteFile(manifestPath, append(manifestBytes, '\n'), 0640); e != nil {
			return e
		}
	} else {
		manifestBytes, readErr := os.ReadFile(regressionManifest)
		if readErr != nil {
			return readErr
		}
		if e = json.Unmarshal(manifestBytes, &manifest); e != nil {
			return fmt.Errorf("parse manifest: %w", e)
		}
	}
	if regressionManifest != "" && regressionRunID != "" {
		manifest.RunID = regressionRunID
	}
	if regressionInitialBaseline && regressionManifest != "" {
		return fmt.Errorf("--initial-baseline requires automatic artifact and complete-inventory verification; supplied manifests are pilot-only")
	}
	if manifest.RunID == "" || len(manifest.Cores) == 0 {
		return fmt.Errorf("manifest must have run_id and at least one core")
	}
	if !safe_regression_component(manifest.RunID) {
		return fmt.Errorf("manifest contains unsafe run id")
	}
	if manifest.Build.Repository != "jotego/jtcores" || manifest.Build.Workflow != "compile-all.yaml" || manifest.Build.Conclusion != "success" || manifest.Build.Attempt == "" || manifest.Build.SHA == "" || manifest.Build.Artifact == "" || manifest.Build.ArtifactSHA == "" || manifest.Build.ExpectedJobs > 0 && manifest.Build.SucceededJobs != manifest.Build.ExpectedJobs {
		return fmt.Errorf("manifest build identity is incomplete or not a complete successful compile_all artifact")
	}
	if _, err := hex.DecodeString(config.FirmwareSHA256); config.FirmwareSHA256 != "" && (err != nil || len(config.FirmwareSHA256) != 64) {
		return fmt.Errorf("firmware-sha256 must be a 64-character hexadecimal digest")
	}
	if manifest.Source != "" {
		config.Source = manifest.Source
	}
	if manifest.Build.SHA != "" {
		out, err := exec.Command("git", "-C", config.Source, "rev-parse", "HEAD").Output()
		if err != nil {
			return fmt.Errorf("verify source checkout: %w", err)
		}
		if strings.TrimSpace(string(out)) != manifest.Build.SHA {
			return fmt.Errorf("source checkout is %s; manifest requires %s", strings.TrimSpace(string(out)), manifest.Build.SHA)
		}
	}
	publisher := regression.GitHubPublisher{TempDir: filepath.Join(dataRoot, "work", "publication")}
	// Automated preparation means this is a full campaign: validate the GitHub
	// destination before any board operation, even when report publication is
	// intentionally deferred for review. Explicit-manifest no-publish remains
	// available for local pilots.
	if !regressionNoPublish || regressionManifest == "" || regressionInitialBaseline {
		if e = publisher.Preflight(manifest.Build); e != nil {
			return e
		}
	}
	if regressionInitialBaseline && (manifest.Build.RunID != "40655576158" || manifest.Build.SHA != "a405f1b955a06f10f75a5aafe2d7080d631e062e") {
		return fmt.Errorf("--initial-baseline is authorized only for compile_all #676 at a405f1b")
	}
	if config.Host == "" {
		return fmt.Errorf("config host is required")
	}
	if config.CabPacker == "" {
		config.CabPacker = filepath.Join(dataRoot, "cache", "cab-pack", "cabinet_pack")
	}
	hardware := &regression.FTPHardware{Host: config.Host, Netrc: config.Netrc, LoadHelper: config.LoadHelper, ControlHelper: config.ControlHelper, CabPacker: config.CabPacker, Curl: config.Curl,
		JTFrame: filepath.Join(config.Source, "modules", "jtframe"), CabCache: filepath.Join(dataRoot, "cache", "cab-pack", manifest.Build.SHA),
		PendingUploadDirsPath: filepath.Join(dataRoot, "state", "upload-directories.json")}
	if config.TimeoutSeconds > 0 {
		hardware.Timeout = time.Duration(config.TimeoutSeconds) * time.Second
	}
	actualExporterSHA, e := hardware.PrepareCabPacker(config.Source)
	if e != nil {
		return fmt.Errorf("prepare frozen CAB exporter: %w", e)
	}
	if config.CabExporterSHA256 == "" || !strings.EqualFold(config.CabExporterSHA256, actualExporterSHA) {
		return fmt.Errorf("CAB exporter SHA256 %s does not match configured frozen identity %s", actualExporterSHA, config.CabExporterSHA256)
	}
	toolIdentity, e := regression.HashFiles(map[string]string{"ftp-control.py": config.ControlHelper, "cabinet_pack": hardware.CabPacker})
	if e != nil {
		return fmt.Errorf("hash capture helper and CAB exporter: %w", e)
	}
	if config.CaptureToolSHA256 != "" && !strings.EqualFold(config.CaptureToolSHA256, toolIdentity) {
		return fmt.Errorf("capture tool identity %s does not match configured frozen identity %s", toolIdentity, config.CaptureToolSHA256)
	}
	config.CaptureToolSHA256 = toolIdentity
	if config.FirmwareSHA256 == "" {
		return fmt.Errorf("config firmware-sha256 is required; use the digest of the verified flashed firmware binary")
	}
	if e = hardware.Preflight(); e != nil {
		return fmt.Errorf("SiDi128 preflight failed: %w", e)
	}
	globalProfile := config.GlobalProfile
	if globalProfile == "" {
		globalProfile = filepath.Join(dataRoot, "reg.yaml")
		if _, err := os.Stat(globalProfile); os.IsNotExist(err) {
			if err = os.MkdirAll(dataRoot, 0750); err != nil {
				return err
			}
			if err = os.WriteFile(globalProfile, []byte("video: 4000\nstart-up: 500\n"), 0640); err != nil {
				return err
			}
		}
	}
	all := regression.PendingInventory(manifest.Cores)
	started := regression.RestoreCampaignStart(
		filepath.Join(dataRoot, "log", manifest.RunID, "summary.json"),
		filepath.Join(dataRoot, "state", manifest.RunID), manifest.Build, time.Now().UTC(), launchStarts)
	var operationalError string
	makeSummary := func(status string) regression.Summary {
		s := regression.Summary{RunID: manifest.RunID, Build: manifest.Build, Started: started, Finished: time.Now().UTC(), Status: status, Games: all,
			OperationalError: operationalError,
			Config:           map[string]any{"source": config.Source, "initial_baseline": regressionInitialBaseline, "no_publish": regressionNoPublish, "board_host": config.Host, "firmware": config.Firmware, "firmware_sha256": config.FirmwareSHA256, "capture_tool_sha256": config.CaptureToolSHA256, "global_profile": globalProfile}, Coverage: map[string]int{},
			Resume: map[string]any{"status": status}, Publication: map[string]any{"status": "not-requested"}}
		for _, result := range all {
			s.Coverage[string(result.Outcome)]++
		}
		s.Duration = s.Finished.Sub(s.Started)
		return s
	}
	writeSummary := func(status string) error {
		return regression.WriteSummary(filepath.Join(dataRoot, "log", manifest.RunID), makeSummary(status))
	}
	finishReport := func(status string) error {
		summary := makeSummary(status)
		if regressionNoPublish {
			summary.Status = "publication-pending"
			return regression.WriteSummary(filepath.Join(dataRoot, "log", manifest.RunID), summary)
		}
		url, publication, publishErr := publisher.Publish(summary)
		if publishErr != nil {
			summary.Status = "publication-pending"
			summary.Publication = map[string]any{"status": "error", "message": publishErr.Error()}
			_ = regression.WriteSummary(filepath.Join(dataRoot, "log", manifest.RunID), summary)
			return publishErr
		}
		summary.ReportURL = url
		summary.Publication = publication
		pubBytes, _ := json.MarshalIndent(publication, "", "  ")
		pubPath := filepath.Join(dataRoot, "state", manifest.RunID, "publication.json")
		if err := os.MkdirAll(filepath.Dir(pubPath), 0750); err != nil {
			return err
		}
		if err := os.WriteFile(pubPath, append(pubBytes, '\n'), 0640); err != nil {
			return err
		}
		return regression.WriteSummary(filepath.Join(dataRoot, "log", manifest.RunID), summary)
	}
	for _, core := range manifest.Cores {
		if !safe_regression_component(core.Core) {
			return fmt.Errorf("manifest contains an unsafe core name")
		}
		statePath := filepath.Join(dataRoot, "state", manifest.RunID, core.Core+".json")
		state := &regression.State{RunID: manifest.RunID, Build: manifest.Build, Core: core.Core}
		if previous, err := regression.ReadState(statePath); err == nil {
			state = previous
		} else if !os.IsNotExist(err) {
			return err
		}
		log, err := regression.NewEventLog(dataRoot, manifest.RunID, core.Core)
		if err != nil {
			operationalError = err.Error()
			return err
		}
		batch := &regression.Batch{Root: dataRoot, CorePath: config.Source, Core: core.Core, RunID: manifest.RunID, Build: manifest.Build,
			State: state, StatePath: statePath, Log: log, Hardware: hardware, GlobalProfile: globalProfile, Games: core.Games, Baseline: regressionInitialBaseline,
			Firmware: config.Firmware, FirmwareSHA256: config.FirmwareSHA256, CaptureToolSHA256: config.CaptureToolSHA256, RetryErrors: regressionRetryErrors}
		err = batch.Run()
		_ = log.Close()
		all = regression.ReplaceCoreResults(all, core.Core, state.Games)
		if err != nil {
			operationalError = err.Error()
			_ = writeSummary("interrupted")
			// Keep interrupted state local. Resume must finish the durable ledger
			// before a single terminal report is created, avoiding stale GitHub bodies.
			return err
		}
	}
	finalStatus := "complete"
	if regressionNoPublish {
		finalStatus = "publication-pending"
	}
	if !regressionNoPublish && finalStatus == "complete" {
		if e = finishReport(finalStatus); e != nil {
			return fmt.Errorf("GitHub report publication failed (hardware outcomes are saved): %w", e)
		}
		return nil
	}
	return regression.WriteSummary(filepath.Join(dataRoot, "log", manifest.RunID), makeSummary(finalStatus))
}

func safe_regression_component(value string) bool {
	return value != "" && value != "." && value != ".." && !strings.ContainsAny(value, "/\\")
}
