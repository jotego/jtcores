/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */

package cmd

import (
	"encoding/hex"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/spf13/cobra"
	"jtutil/regression"
)

var regressionConfig string
var regressionManifest string
var regressionRunID string
var regressionNoPublish bool
var regressionRetryErrors bool
var regressionCore string
var regressionSetname string
var regressionJTBin bool

var regressionCmd = &cobra.Command{
	Use:   "regression",
	Short: "Capture a core or run a SiDi128 video regression batch",
	Long: `Discovers and prepares a successful compile_all build, then runs or resumes its SiDi128 regression.
Collects PNG frames in $JOTEGO/regression/<core>/<setname>/new for designer review.
Preparation uses the working project; diagnostics and resume state live under log/.

Use --core to capture that core's main games, or add --setname for one game.
Manual captures run fresh, compare approved refs, and replace new PNGs locally.
They do not publish GitHub reports or require campaign manifest/run selectors.

Examples:
  jtutil regression --core shouse
  jtutil regression --core shouse --setname splatter
  jtutil regression --core shouse --setname splatter --jtbin

By default, manual captures generate MRAs in the working project and use its
release/sidi128 RBF. --jtbin reads existing MRA/RBF files from $JTBIN.
Games marked debug in the working project's mame2mra.toml are excluded.`,
	Args: cobra.NoArgs,
	RunE: run_regression_cmd,
}

func init() {
	regressionCmd.Flags().BoolVar(&regressionJTBin,"jtbin",false,"Read manual capture MRA/RBF files from $JTBIN (requires --core)")
	regressionCmd.Flags().StringVar(&regressionCore, "core", "", "Capture one core locally using the working project's RBF and ROMs")
	regressionCmd.Flags().StringVar(&regressionSetname, "setname", "", "Capture one game of --core (default: all main games)")
	regressionCmd.Flags().StringVar(&regressionConfig, "config", filepath.Join(project_root(), ".jtutil-regression.yaml"), "Portable regression config YAML")
	regressionCmd.Flags().StringVar(&regressionManifest, "manifest", "", "Build-specific inventory manifest JSON")
	regressionCmd.Flags().StringVar(&regressionRunID, "run-id", "", "Pin a GitHub Actions run ID or run number")
	regressionCmd.Flags().BoolVar(&regressionNoPublish, "no-publish", false, "Do not publish GitHub summary (local pilot only)")
	regressionCmd.Flags().BoolVar(&regressionRetryErrors, "retry-errors", false, "Rerun terminal per-game errors from a fresh ARC launch")
	rootCmd.AddCommand(regressionCmd)
}

func run_regression_cmd(cmd *cobra.Command, args []string) error {
	manual, validationErr := validate_regression_selection(regressionCore, regressionSetname, regressionManifest, regressionRunID, regressionRetryErrors, regressionJTBin)
	if validationErr != nil { return validationErr }
	noPublish := regressionNoPublish || manual
	root := os.Getenv("JOTEGO")
	if root == "" {
		return fmt.Errorf("JOTEGO must name the private regression data directory")
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
			return fmt.Errorf("result root must be JOTEGO/regression (%s)", rootAbs)
		}
	}
	config.Source = project_root()
	var manifest regression.Manifest
	// Reject obsolete debug/skip inventories before locking or touching any
	// campaign log, launch snapshot, manifest or resume state.
	if regressionManifest != "" {
		manifestBytes, readErr := os.ReadFile(regressionManifest)
		if readErr != nil { return readErr }
		if e = json.Unmarshal(manifestBytes,&manifest); e != nil { return fmt.Errorf("parse manifest: %w",e) }
		if e = regression.ValidateManifestEligibility(config.Source,manifest); e != nil { return e }
	}
	if regressionRetryErrors {
		info,err:=os.Stat(filepath.Join(dataRoot,"log"))
		if err!=nil || !info.IsDir() {return fmt.Errorf("resume log root is unavailable; refusing to create it")}
	}
	lock, e := regression.AcquireLock(dataRoot,regressionRetryErrors)
	if e != nil {
		return e
	}
	defer regression.ReleaseLock(lock)
	var launchStarts map[string]time.Time
	if !manual {
		launchStarts, e = regression.SnapshotLaunchStarts(dataRoot, regressionRunID)
		if e != nil { return fmt.Errorf("verify and preserve prior launch manifest: %w", e) }
	}
	resume_journal:=regressionRetryErrors
	if regressionManifest == "" {
		if manual { manifest, e = regression.PrepareManual(cmd.Context(), config, dataRoot, regressionCore, regressionSetname, regressionJTBin) } else { manifest, e = regression.Prepare(cmd.Context(), config, dataRoot, regressionRunID) }
		if e != nil {
			return fmt.Errorf("prepare regression build and inventory: %w", e)
		}
		if manual && regression.HasResumeState(dataRoot,manifest.RunID) { return fmt.Errorf("manual capture session already has state; refusing to resume it") }
		resume_journal=regressionRetryErrors || regression.HasResumeState(dataRoot,manifest.RunID)
		if resume_journal {
			if err:=regression.RequireResumeJournal(dataRoot,manifest.RunID,manifest.Build);err!=nil {return err}
		}
		manifestPath := filepath.Join(dataRoot, "log", manifest.RunID, "manifest.json")
		if !resume_journal {if e=os.MkdirAll(filepath.Dir(manifestPath),0750);e!=nil{return e}}
		manifestBytes, marshalErr := json.MarshalIndent(manifest, "", "  ")
		if marshalErr != nil {
			return marshalErr
		}
		if resume_journal {e=regression.WriteExistingFile(manifestPath,append(manifestBytes,'\n'),0640)} else {e=os.WriteFile(manifestPath,append(manifestBytes,'\n'),0640)}
		if e!=nil{return e}
		if manual {
			provenance, readErr := os.ReadFile(filepath.Join(config.Source,".cache","jtutil-regression","manual",manifest.RunID,"manual-preparation.json"))
			if readErr != nil { return fmt.Errorf("read manual preparation provenance: %w",readErr) }
			if err := os.WriteFile(filepath.Join(filepath.Dir(manifestPath),"manual-preparation.json"),provenance,0640); err != nil { return fmt.Errorf("record manual preparation provenance: %w",err) }
		}
	}
	if regressionManifest != "" && regressionRunID != "" {
		manifest.RunID = regressionRunID
	}
	if manifest.RunID == "" || len(manifest.Cores) == 0 {
		return fmt.Errorf("manifest must have run_id and at least one core")
	}
	if !safe_regression_component(manifest.RunID) {
		return fmt.Errorf("manifest contains unsafe run id")
	}
	if !manual && (manifest.Build.Repository != "jotego/jtcores" || manifest.Build.Workflow != "compile-all.yaml" || manifest.Build.Conclusion != "success" || manifest.Build.Attempt == "" || manifest.Build.SHA == "" || manifest.Build.Artifact == "" || manifest.Build.ArtifactSHA == "" || manifest.Build.ExpectedJobs > 0 && manifest.Build.SucceededJobs != manifest.Build.ExpectedJobs) {
		return fmt.Errorf("manifest build identity is incomplete or not a complete successful compile_all artifact")
	}
	resume_journal=regressionRetryErrors || regression.HasResumeState(dataRoot,manifest.RunID)
	if resume_journal {if err:=regression.RequireResumeJournal(dataRoot,manifest.RunID,manifest.Build);err!=nil {return err}}
	if _, err := hex.DecodeString(config.FirmwareSHA256); config.FirmwareSHA256 != "" && (err != nil || len(config.FirmwareSHA256) != 64) {
		return fmt.Errorf("firmware-sha256 must be a 64-character hexadecimal digest")
	}
	if manifest.Source != "" && filepath.Clean(manifest.Source) != filepath.Clean(config.Source) {
		return fmt.Errorf("manifest belongs to project %s; current project is %s", manifest.Source, config.Source)
	}
	publisher := regression.GitHubPublisher{TempDir: filepath.Join(dataRoot, "log", manifest.RunID, "publication")}
	// Automated preparation means this is a full campaign: validate the GitHub
	// destination before any board operation, even when report publication is
	// intentionally deferred for review. Explicit-manifest no-publish remains
	// available for local pilots.
	if !manual && (!noPublish || regressionManifest == "") {
		if e = publisher.Preflight(manifest.Build); e != nil {
			return e
		}
	}
	if config.Host == "" {
		return fmt.Errorf("config host is required")
	}
	if config.CabPacker == "" {
		config.CabPacker = filepath.Join(config.Source, ".cache", "jtutil-regression", "cab-pack", "cabinet_pack")
	}
	hardware := &regression.FTPHardware{Host: config.Host, Netrc: config.Netrc, ControlHelper: config.ControlHelper, CabPacker: config.CabPacker, Curl: config.Curl,
		JTFrame: filepath.Join(config.Source, "modules", "jtframe"), CabCache: filepath.Join(config.Source, ".cache", "jtutil-regression", "cab-pack", manifest.Build.SHA),
		PendingUploadDirsPath: filepath.Join(dataRoot, "log", "upload-directories.json")}
	defer hardware.ReleaseCore()
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
		globalProfile = filepath.Join(config.Source, "modules", "jtframe", "bin", "reg.yaml")
	}
	all := regression.PendingInventory(manifest.Cores)
	started := regression.RestoreCampaignStart(
		filepath.Join(dataRoot, "log", manifest.RunID, "summary.json"),
		filepath.Join(dataRoot, "log", manifest.RunID, "state"), manifest.Build, time.Now().UTC(), launchStarts)
	var operationalError string
	makeSummary := func(status string) regression.Summary {
		s := regression.Summary{RunID: manifest.RunID, Build: manifest.Build, Started: started, Finished: time.Now().UTC(), Status: status, Games: all,
			OperationalError: operationalError,
			Config:           map[string]any{"manual": manual, "jtbin": regressionJTBin, "source": config.Source, "project_sha": manifest.ProjectSHA, "no_publish": noPublish, "board_host": config.Host, "firmware": config.Firmware, "firmware_sha256": config.FirmwareSHA256, "capture_tool_sha256": config.CaptureToolSHA256, "global_profile": globalProfile}, Coverage: map[string]int{},
			Resume: map[string]any{"status": status}, Publication: map[string]any{"status": "not-requested"}}
		for _, result := range all {
			s.Coverage[string(result.Outcome)]++
		}
		s.Duration = s.Finished.Sub(s.Started)
		return s
	}
	writeSummary := func(status string) error {
		return regression.WriteSummary(filepath.Join(dataRoot, "log", manifest.RunID), makeSummary(status),resume_journal)
	}
	finishReport := func(status string) error {
		summary := makeSummary(status)
		if noPublish {
			summary.Status = "publication-pending"
			return regression.WriteSummary(filepath.Join(dataRoot, "log", manifest.RunID), summary,resume_journal)
		}
		url, publication, publishErr := publisher.Publish(summary)
		if publishErr != nil {
			summary.Status = "publication-pending"
			summary.Publication = map[string]any{"status": "error", "message": publishErr.Error()}
			_ = regression.WriteSummary(filepath.Join(dataRoot, "log", manifest.RunID), summary,resume_journal)
			return publishErr
		}
		summary.ReportURL = url
		summary.Publication = publication
		pubBytes, _ := json.MarshalIndent(publication, "", "  ")
		pubPath := filepath.Join(dataRoot, "log", manifest.RunID, "state", "publication.json")
		if resume_journal {
			if err:=regression.WriteExistingFile(pubPath,append(pubBytes,'\n'),0640);err!=nil{return err}
		} else {
			if err:=os.MkdirAll(filepath.Dir(pubPath),0750);err!=nil{return err}
			if err:=os.WriteFile(pubPath,append(pubBytes,'\n'),0640);err!=nil{return err}
		}
		return regression.WriteSummary(filepath.Join(dataRoot, "log", manifest.RunID), summary,resume_journal)
	}
	var resume_build []regression.BuildIdentity
	if resume_journal {resume_build=append(resume_build,manifest.Build)}
	campaign_log,e:=regression.NewEventLog(dataRoot,manifest.RunID,"",resume_build...)
	if e!=nil{return e}
	defer campaign_log.Close()
	for _, core := range manifest.Cores {
		if !safe_regression_component(core.Core) {
			return fmt.Errorf("manifest contains an unsafe core name")
		}
		statePath := filepath.Join(dataRoot, "log", manifest.RunID, "state", core.Core+".json")
		state := &regression.State{RunID: manifest.RunID, Build: manifest.Build, Core: core.Core}
		if previous, err := regression.ReadState(statePath); err == nil {
			state = previous
		} else if !os.IsNotExist(err) {
			return err
		}
		log:=campaign_log
		log.SetCore(core.Core)
		var err error
		batch := &regression.Batch{Root: dataRoot, CorePath: config.Source, Core: core.Core, RunID: manifest.RunID, Build: manifest.Build, ProjectSHA: manifest.ProjectSHA,
			State: state, StatePath: statePath, Log: log, Hardware: hardware, GlobalProfile: globalProfile, Games: core.Games,
			Firmware: config.Firmware, FirmwareSHA256: config.FirmwareSHA256, CaptureToolSHA256: config.CaptureToolSHA256, RetryErrors: regressionRetryErrors,Resume:resume_journal}
		err = batch.Run()
		if release_error:=hardware.ReleaseCore();release_error!=nil {
			_ = log.Write(regression.Event{Stage:"core-cleanup",Outcome:regression.Error,Message:release_error.Error()})
			if err==nil { err=release_error } else { err=fmt.Errorf("%w; release core: %v",err,release_error) }
		}
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
	if noPublish && !manual {
		finalStatus = "publication-pending"
	}
	if !noPublish && finalStatus == "complete" {
		if e = finishReport(finalStatus); e != nil {
			return fmt.Errorf("GitHub report publication failed (hardware outcomes are saved): %w", e)
		}
		return nil
	}
	if err := regression.WriteSummary(filepath.Join(dataRoot, "log", manifest.RunID), makeSummary(finalStatus),resume_journal); err != nil { return err }
	if manual {
		for _, result := range all { fmt.Fprintf(cmd.OutOrStdout(),"%s/%s: %s (%s)\n",result.Core,result.Setname,result.Outcome,result.Message) }
		fmt.Fprintf(cmd.OutOrStdout(),"Log: %s\n",filepath.Join(dataRoot,"log",manifest.RunID))
	}
	return nil
}

// Manual selection starts a fresh local capture session; campaign selectors
// deliberately remain exclusive so a manual recapture cannot resume a batch.
func validate_regression_selection(core, setname, manifest, runID string, retry, useJTBin bool) (bool,error) {
	if core == "" {
		if useJTBin { return false,fmt.Errorf("--jtbin requires --core") }
		if setname != "" { return false, fmt.Errorf("--setname requires --core") }
		return false,nil
	}
	if !safe_manual_regression_name(core) || setname != "" && !safe_manual_regression_name(setname) { return false,fmt.Errorf("--core and --setname must be safe core/game names (letters, digits, underscore or hyphen)") }
	if manifest != "" || runID != "" || retry { return false,fmt.Errorf("--core starts a fresh manual capture; do not combine it with --manifest, --run-id or --retry-errors") }
	return true,nil
}

func safe_manual_regression_name(name string) bool {
	if name == "" { return false }
	for _, c := range name { if !(c >= 'a' && c <= 'z' || c >= 'A' && c <= 'Z' || c >= '0' && c <= '9' || c == '_' || c == '-') { return false } }
	return true
}

func safe_regression_component(value string) bool {
	return value != "" && value != "." && value != ".." && !strings.ContainsAny(value, "/\\")
}

func project_root() string {
	root := os.Getenv("JTROOT")
	if root == "" { root, _ = os.Getwd() }
	root, _ = filepath.Abs(root)
	return root
}
