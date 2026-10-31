/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */

package cmd

import (
	"context"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"os/signal"
	"syscall"
	"path/filepath"
	"strings"
	"time"

	"github.com/spf13/cobra"
	"jtutil/regression"
)

var regressionImport string
var regressionMigrate string
var regressionPoll bool
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
	regressionCmd.Flags().StringVar(&regressionImport,"import-progress","","Import verified results from an archived legacy campaign")
	regressionCmd.Flags().MarkHidden("import-progress")
	regressionCmd.Flags().StringVar(&regressionMigrate,"migrate-logs","","Convert old logs and archive them outside regression/log")
	regressionCmd.Flags().MarkHidden("migrate-logs")
	regressionCmd.Flags().BoolVar(&regressionPoll, "poll", false, "Poll once; an active batch or no eligible build is a successful no-op")
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

func run_regression_cmd(cmd *cobra.Command, args []string) (result_error error) {
	parent := cmd.Context()
	if parent == nil { parent = context.Background() }
	ctx, stop := signal.NotifyContext(parent, os.Interrupt, syscall.SIGTERM)
	defer stop()
	manual, err := validate_regression_selection(regressionCore, regressionSetname, regressionManifest, regressionRunID, regressionRetryErrors, regressionJTBin)
	if err != nil { return err }
	if regressionPoll && (manual || regressionRunID != "" || regressionManifest != "" || regressionRetryErrors) { return fmt.Errorf("--poll requires automatic discovery") }
	root := os.Getenv("JOTEGO")
	if root == "" { return fmt.Errorf("JOTEGO must name the private regression data directory") }
	data_root := filepath.Join(root,"regression")
	cfg, err := regression.ReadConfig(regressionConfig)
	if err != nil { return err }
	cfg.Source = project_root()
	cfg.NoPublish = regressionNoPublish || manual || regressionManifest!=""
	if cfg.Root != "" {
		configured, e := filepath.Abs(cfg.Root); if e != nil { return e }
		expected, e := filepath.Abs(data_root); if e != nil { return e }
		if configured != expected { return fmt.Errorf("result root must be JOTEGO/regression (%s)",expected) }
	}
	var manifest regression.Manifest
	if regressionManifest != "" {
		data,e:=os.ReadFile(regressionManifest);if e!=nil{return e}
		if e=json.Unmarshal(data,&manifest);e!=nil{return e}
		if e=regression.ValidateManifestEligibility(cfg.Source,manifest);e!=nil{return e}
		if len(manifest.Cores)==0{return fmt.Errorf("manifest contains no cores")}
		for _,core:=range manifest.Cores{if len(core.Games)==0{return fmt.Errorf("manifest core %s contains no games",core.Core)}}
		b:=manifest.Build
		if b.Repository!="jotego/jtcores"||b.Workflow!="compile-all.yaml"||b.Conclusion!="success"||b.Artifact==""||b.ArtifactSHA==""||b.ExpectedJobs>0&&b.ExpectedJobs!=b.SucceededJobs{return fmt.Errorf("manifest must identify a complete successful compile_all build")}
	}
	lock,err:=regression.AcquireLock(data_root)
	if regressionPoll && errors.Is(err,regression.ErrBoardBusy){fmt.Fprintln(cmd.OutOrStdout(),err);return nil}
	if err!=nil{return err};defer regression.ReleaseLock(lock)
	if err=regression.InitializeLog(data_root);err!=nil{return err}
	if regressionMigrate!="" || regressionImport!="" {
		if manual||regressionPoll||regressionRunID!=""||regressionManifest!=""{return fmt.Errorf("log migration cannot be combined with capture selection")}
		if cfg.GlobalProfile==""{cfg.GlobalProfile=filepath.Join(cfg.Source,"modules","jtframe","bin","reg.yaml")}
		if regressionImport!="" { return regression.ImportProgress(data_root,regressionImport,cfg) }
		return regression.MigrateLogs(data_root,regressionMigrate,cfg)
	}
	var record *regression.CommitLog
	defer func(){
		if result_error!=nil {
			if record!=nil {
				if record.Progress.Status!="interrupted" || record.Progress.Error!=result_error.Error(){result_error=record.Failed(result_error)}
			} else {
				message:=regression.FormatLogEntry(time.Now(),"",-1,"error",result_error.Error())
				if e:=os.WriteFile(filepath.Join(data_root,"log","poll.log"),[]byte(message),0640);e!=nil{result_error=fmt.Errorf("%w; log error: %v",result_error,e)}
			}
		}
		if record!=nil {if e:=record.Close();e!=nil&&result_error==nil{result_error=e}}
	}()
	commit,dirty:="",false
	if manual {
		commit,dirty,err=regression.ManualCommit(ctx,cfg.Source,regressionCore,regressionJTBin)
		if err!=nil{return err}
		if dirty {fmt.Fprintln(cmd.ErrOrStderr(),"Warning: jtcores checkout is dirty; a clean checkout is recommended. Recording this development run with the dirty label.")}
	} else {
		if regressionManifest=="" {manifest.Build,err=regression.DiscoverBuild(ctx,cfg,data_root,regressionRunID)}
		if regressionPoll && errors.Is(err,regression.ErrNoEligibleBuild){fmt.Fprintln(cmd.OutOrStdout(),err);return nil}
		if err!=nil{return err}
		commit=manifest.Build.SHA
	}
	record,err=regression.OpenCommitLog(data_root,commit,dirty)
	if err!=nil{return err}
	if err=record.Write("Starting regression in "+cfg.Source);err!=nil{return err}
	if dirty {if err=record.Entry("",-1,"warning","dirty checkout; clean state recommended");err!=nil{return err}}
	work,err:=os.MkdirTemp("/tmp","jtutil-regression-run-")
	if err!=nil{return err};defer os.RemoveAll(work)
	publisher:=regression.GitHubPublisher{TempDir:work}
	if !manual&&record.Progress.ReportPR==nil {
		pr:=0
		if manifest.Build.Event=="pull_request"||manifest.Build.Event=="workflow_dispatch"&&manifest.Build.Ref!="master"{pr=manifest.Build.PR}
		record.Progress.ReportPR=&pr
	}
	report_build:=func()regression.BuildIdentity{
		build:=regression.BuildIdentity{Repository:"jotego/jtcores",SHA:commit,Ref:"master",Event:"push"}
		if record.Progress.ReportPR!=nil&&*record.Progress.ReportPR>0{build.PR=*record.Progress.ReportPR;build.Event="pull_request";build.Ref="PR"}
		return build
	}
	publish:=func()error{
		if cfg.NoPublish || record.Progress.ReportURL!="" {return nil}
		if e:=publisher.Preflight(report_build());e!=nil{return e}
		url,_,e:=publisher.Publish(record.Summary(report_build()));if e!=nil{return e}
		record.Progress.ReportURL=url
		return record.Save()
	}
	if !manual && regressionManifest=="" && record.Progress.AutomaticComplete && !regressionRetryErrors {return publish()}
	record.Progress.Status="preparing";record.Progress.Error=""
	if err=record.Save();err!=nil{return err}
	if manual {
		manifest,err=regression.PrepareManual(ctx,cfg,work,regressionCore,regressionSetname,regressionJTBin)
		manifest.Build.SHA=commit
	} else if regressionManifest=="" {
		manifest.Build.ArtifactSHA=record.Progress.ArchiveSHA
		manifest,err=regression.PrepareBuild(ctx,cfg,work,manifest.Build)
	}
	if err!=nil{return err}
	if manifest.Source!="" && filepath.Clean(manifest.Source)!=filepath.Clean(cfg.Source){return fmt.Errorf("manifest belongs to another working project")}
	if !manual {
		if manifest.Build.Conclusion!="success" || manifest.Build.Repository!="jotego/jtcores" {return fmt.Errorf("a successful jtcores build is required")}
		record.Progress.ArchiveSHA=manifest.Build.ArtifactSHA
		if err=publisher.Preflight(manifest.Build);err!=nil{return err}
	}
	if cfg.Host=="" {return fmt.Errorf("config host is required")}
	if cfg.GlobalProfile=="" {cfg.GlobalProfile=filepath.Join(cfg.Source,"modules","jtframe","bin","reg.yaml")}
	hardware:=&regression.FTPHardware{Host:cfg.Host,Netrc:cfg.Netrc,ControlHelper:cfg.ControlHelper,CabPacker:cfg.CabPacker,Curl:cfg.Curl,
		JTFrame:filepath.Join(cfg.Source,"modules","jtframe"),PendingUploadDirsPath:filepath.Join(data_root,"log","upload-directories.json")}
	defer hardware.ReleaseCore()
	if cfg.TimeoutSeconds>0 {hardware.Timeout=time.Duration(cfg.TimeoutSeconds)*time.Second}
	actual_exporter,err:=hardware.PrepareCabPacker(cfg.Source);if err!=nil{return err}
	if cfg.CabExporterSHA256!=""&&!strings.EqualFold(cfg.CabExporterSHA256,actual_exporter){return fmt.Errorf("CAB exporter does not match configured checksum")}
	tool_identity,err:=regression.HashFiles(map[string]string{"ftp-control.py":cfg.ControlHelper,"cabinet_pack":hardware.CabPacker});if err!=nil{return err}
	if cfg.CaptureToolSHA256!=""&&!strings.EqualFold(cfg.CaptureToolSHA256,tool_identity){return fmt.Errorf("capture tools do not match configured checksum")}
	cfg.CaptureToolSHA256=tool_identity
	if digest,e:=hex.DecodeString(cfg.FirmwareSHA256);e!=nil||len(digest)!=32{return fmt.Errorf("firmware-sha256 must be a 64-character hexadecimal digest")}
	if err=hardware.Preflight();err!=nil{return err}
	if err=regression.RunCommit(ctx,record,manifest,cfg,hardware,manual,regressionRetryErrors,regressionManifest!="");err!=nil{return err}
	if err=publish();err!=nil{return err}
	fmt.Fprintf(cmd.OutOrStdout(),"Regression complete. Log: %s\n",filepath.Join(data_root,"log",regression.LogKey(commit,dirty)+".log"))
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
