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
	"sort"
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
var regressionPublishTo string
var regressionRetryErrors bool
var regressionCore string
var regressionCores string
var regressionSetname string
var regressionCommit string
var regressionJTBin bool
var regressionBusy bool
var regressionAccept string
var regressionReject string
var regressionReason string
var regressionStatus bool

var regressionCmd = &cobra.Command{
	Use:   "regression",
	Short: "Capture a core or run a SiDi128 video regression batch",
	Long: `Discovers and prepares a successful Compile all or Compile SiDi128 build, then runs or resumes its SiDi128 regression.
Collects PNG frames in $JOTEGO/regression/<core>/<setname>/new for designer review.
Preparation uses the working project; diagnostics and resume state live under log/.
After a completed new capture is available, use jtutil mame-frames to validate
its exact ordered frames against MAME and promote a complete match to ref.

Use --core/--cores to capture selected cores, or add --setname for selected games.
Manual captures run fresh, compare approved refs, and replace new PNGs locally.
They do not publish GitHub reports or require campaign manifest/run selectors.

Examples:
  jtutil regression --core shouse
  jtutil regression --core shouse --setname splatter
  jtutil regression --core shouse --setname splatter --jtbin
  jtutil regression --commit 4401da8 --core 1943,gng

By default, manual captures generate MRAs in the working project and use its
release/sidi128 RBF. --jtbin reads existing MRA/RBF files from $JTBIN.
--commit pins both MRA and SiDi128 RBF to a local $JOTEGO/core-builds ZIP;
it accepts a resolvable 7-character SHA or full 40-character SHA.
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
	regressionCmd.Flags().StringVar(&regressionCores, "cores", "", "Comma-separated alias for --core")
	regressionCmd.Flags().StringVar(&regressionSetname, "setname", "", "Capture comma-separated selected games (default: all main games)")
	regressionCmd.Flags().StringVar(&regressionCommit, "commit", "", "Use a local $JOTEGO/core-builds archive for the specified jtcores commit")
	regressionCmd.Flags().StringVar(&regressionConfig, "config", filepath.Join(project_root(), ".jtutil-regression.yaml"), "Portable regression config YAML")
	regressionCmd.Flags().StringVar(&regressionManifest, "manifest", "", "Build-specific inventory manifest JSON")
	regressionCmd.Flags().StringVar(&regressionRunID, "run-id", "", "Pin a GitHub Actions run ID or unambiguous run number")
	regressionCmd.Flags().StringVar(&regressionPublishTo,"publish-to","github","Report destination: github or gitea (uses GITEA_SERVER_URL, GITEA_REPOSITORY, GITEA_TOKEN)")
	regressionCmd.Flags().BoolVar(&regressionNoPublish, "no-publish", false, "Do not publish an external regression summary")
	regressionCmd.Flags().BoolVar(&regressionRetryErrors, "retry-errors", false, "Rerun terminal per-game errors from a fresh ARC launch")
	regressionCmd.Flags().BoolVarP(&regressionBusy, "busy", "b", false, "Check whether a regression currently holds the shared lock")
	regressionCmd.Flags().StringVar(&regressionAccept, "accept", "", "Promote a setname's reviewed new/ or fail/ frames to ref")
	regressionCmd.Flags().StringVar(&regressionReject, "reject", "", "Remove a setname's pending new/ or fail/ frames")
	regressionCmd.Flags().StringVar(&regressionReason, "reason", "", "Single-line reason recorded with --reject")
	regressionCmd.Flags().BoolVar(&regressionStatus, "status", false, "Summarize the latest completed per-game regression checks")
	rootCmd.AddCommand(regressionCmd)
}

func run_regression_cmd(cmd *cobra.Command, args []string) (result_error error) {
	originalCore, originalSet := regressionCore, regressionSetname
	defer func(){ regressionCore, regressionSetname = originalCore, originalSet }()
	management := regressionBusy || regressionAccept != "" || regressionReject != "" || regressionStatus || cmd.Flags().Changed("accept") || cmd.Flags().Changed("reject") || cmd.Flags().Changed("reason")
	if management {
		if cmd.Flags().Changed("commit") || cmd.Flags().Changed("core") || cmd.Flags().Changed("cores") || cmd.Flags().Changed("setname") { return fmt.Errorf("management modes cannot be combined with capture selectors") }
		return run_regression_management(cmd)
	}
	parent := cmd.Context()
	if parent == nil { parent = context.Background() }
	ctx, stop := signal.NotifyContext(parent, os.Interrupt, syscall.SIGTERM)
	defer stop()
	cores, sets, err := parse_regression_lists(regressionCore, regressionCores, regressionSetname, cmd.Flags().Changed("core"), cmd.Flags().Changed("cores"))
	if err != nil { return err }
	if cmd.Flags().Changed("commit") && strings.TrimSpace(regressionCommit)=="" { return fmt.Errorf("--commit requires a nonempty commit SHA") }
	archiveMode := regressionCommit != ""
	if err=validate_explicit_regression_values(archiveMode, cmd.Flags().Changed("core"), cmd.Flags().Changed("cores"), cmd.Flags().Changed("setname"), regressionCore, regressionCores, regressionSetname); err!=nil{return err}
	if archiveMode && (regressionJTBin || regressionPoll || regressionManifest!="" || regressionRunID!="" || regressionRetryErrors || regressionMigrate!="" || regressionImport!="" || regressionBusy || regressionStatus || regressionAccept!="" || regressionReject!="" || regressionReason!="") { return fmt.Errorf("--commit cannot be combined with --jtbin, automatic selectors, or management modes") }
	if len(sets)>0 && len(cores)==0 && !archiveMode { return fmt.Errorf("--setname requires --core") }
	if len(cores)>0 { regressionCore=cores[0] }
	if len(sets)==1 { regressionSetname=sets[0] } else if len(sets)>1 { regressionSetname="" }
	manual := archiveMode
	if !archiveMode {
		manual, err = validate_regression_selection(regressionCore, regressionSetname, regressionManifest, regressionRunID, regressionRetryErrors, regressionJTBin)
		if err != nil { return err }
	}
	if regressionPoll && (manual || regressionRunID != "" || regressionManifest != "" || regressionRetryErrors) { return fmt.Errorf("--poll requires automatic discovery") }
	root := os.Getenv("JOTEGO")
	if root == "" { return fmt.Errorf("JOTEGO must name the private regression data directory") }
	data_root := filepath.Join(root,"regression")
	cfg, err := regression.ReadConfig(regressionConfig)
	if err != nil { return err }
	cfg.Source = project_root()
	cfg.NoPublish = regressionNoPublish || manual || regressionManifest!=""
	if regressionPublishTo!="github" && regressionPublishTo!="gitea" {return fmt.Errorf("--publish-to must be github or gitea")}
	cfg.ReportTarget=regressionPublishTo
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
		if b.Repository!="jotego/jtcores"||!regression.SupportedBuildWorkflow(b.Workflow)||b.Conclusion!="success"||b.Artifact==""||b.ArtifactSHA==""||b.ExpectedJobs>0&&b.ExpectedJobs!=b.SucceededJobs{return fmt.Errorf("manifest must identify a complete successful Compile all or Compile SiDi128 build")}
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
	var manualArchive regression.ManualArchive
	if manual {
		if archiveMode {
			manualArchive,err=regression.ResolveManualArchive(ctx,cfg.Source,filepath.Join(root,"core-builds"),regressionCommit)
			commit=manualArchive.Commit
			if err==nil { _,dirty,err=regression.ManualCommit(ctx,cfg.Source,regressionCore,false) }
		} else {
			for i, core := range cores {
				var candidate string; var coreDirty bool
				candidate,coreDirty,err=regression.ManualCommit(ctx,cfg.Source,core,regressionJTBin)
				if err!=nil { break }
				if i>0 && candidate!=commit { err=fmt.Errorf("selected manual cores have different source commits (%s and %s)",commit,candidate); break }
				commit=candidate; dirty=dirty||coreDirty
			}
		}
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
	if archiveMode && record.Progress.ArchiveSHA!="" && record.Progress.ArchiveSHA!=manualArchive.SHA256 { return fmt.Errorf("selected build archive differs from the archive pinned in this log") }
	if archiveMode { record.Progress.ArchiveSHA=manualArchive.SHA256 }
	if err=record.Write("Starting regression in "+cfg.Source);err!=nil{return err}
	if dirty {if err=record.Entry("",-1,"warning","dirty checkout; clean state recommended");err!=nil{return err}}
	work,err:=os.MkdirTemp("/tmp","jtutil-regression-run-")
	if err!=nil{return err};defer os.RemoveAll(work)
	publisher:=regression.GitHubPublisher{TempDir:work}
	gitea:=regression.GiteaPublisher{Server:os.Getenv("GITEA_SERVER_URL"),Repository:os.Getenv("GITEA_REPOSITORY"),Token:os.Getenv("GITEA_TOKEN")}
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
		if cfg.NoPublish {return nil}
		if regressionPublishTo=="gitea" {
			if e:=gitea.Preflight(report_build());e!=nil{return e}
			url,e:=gitea.Publish(record.Summary(report_build()),record.Progress.GiteaReportURL);if e!=nil{return e}
			record.Progress.GiteaReportURL=url
			record.Progress.GiteaReportComplete=record.Progress.AutomaticComplete
			return record.Save()
		}
		if record.Progress.ReportURL!="" {return nil}
		if e:=publisher.Preflight(report_build());e!=nil{return e}
		url,_,e:=publisher.Publish(record.Summary(report_build()));if e!=nil{return e}
		record.Progress.ReportURL=url
		return record.Save()
	}
	if !cfg.NoPublish && regressionPublishTo=="gitea" {
		// Publish an initial issue and refresh that same issue on interruption.
		defer func(){
			if result_error!=nil {
				if record.Progress.Status!="interrupted" || record.Progress.Error!=result_error.Error(){result_error=record.Failed(result_error)}
				if e:=publish();e!=nil{result_error=fmt.Errorf("%w; Gitea report: %v",result_error,e)}
			}
		}()
	}
	if !manual && regressionManifest=="" && record.Progress.AutomaticComplete && !regressionRetryErrors {return publish()}
	record.Progress.Status="preparing";record.Progress.Error=""
	if !cfg.NoPublish && regressionPublishTo=="gitea" {if err=publish();err!=nil{return err}}
	if err=record.Save();err!=nil{return err}
	if manual {
		if archiveMode {
			manifest,err=regression.PrepareManualArchive(ctx,cfg,work,work,manualArchive,cores,sets)
		} else if len(cores)>1 || len(sets)>1 {
			manifest,err=regression.PrepareManualSelection(ctx,cfg,work,work,cores,sets,regressionJTBin)
		} else {
			manifest,err=regression.PrepareManual(ctx,cfg,work,regressionCore,regressionSetname,regressionJTBin)
		}
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
		if !cfg.NoPublish && regressionPublishTo=="github" {if err=publisher.Preflight(manifest.Build);err!=nil{return err}}
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
	if !cfg.NoPublish && regressionPublishTo=="gitea" {
		record.Progress.Status="running"
		if err=publish();err!=nil{return err}
	}
	if err=regression.RunCommit(ctx,record,manifest,cfg,hardware,manual,regressionRetryErrors,regressionManifest!="");err!=nil{return err}
	if err=publish();err!=nil{return err}
	fmt.Fprintf(cmd.OutOrStdout(),"Regression complete. Log: %s\n",filepath.Join(data_root,"log",regression.LogKey(commit,dirty)+".log"))
	return nil
}

func run_regression_management(cmd *cobra.Command) error {
	selected := 0
	acceptSet, rejectSet := cmd.Flags().Changed("accept"), cmd.Flags().Changed("reject")
	for _, mode := range []bool{regressionBusy, acceptSet || regressionAccept != "", rejectSet || regressionReject != "", regressionStatus} { if mode { selected++ } }
	if selected != 1 { return fmt.Errorf("choose exactly one of --busy, --accept, --reject or --status") }
	if cmd.Flags().Changed("reason") && !rejectSet { return fmt.Errorf("--reason requires --reject") }
	if acceptSet && regressionAccept == "" { return &regression.CurationError{Code:6, Err:errors.New("--accept requires a nonempty setname")} }
	if rejectSet && regressionReject == "" { return fmt.Errorf("--reject requires a nonempty setname") }
	if regressionCore != "" || regressionCores != "" || regressionSetname != "" || regressionManifest != "" || regressionRunID != "" || regressionPoll || regressionJTBin || regressionRetryErrors || regressionMigrate != "" || regressionImport != "" {
		return fmt.Errorf("management flags cannot be combined with capture or campaign selectors")
	}
	root := os.Getenv("JOTEGO")
	if root == "" { return fmt.Errorf("JOTEGO must name the private regression data directory") }
	dataRoot := filepath.Join(root, "regression")
	if regressionBusy {
		busy, err := regression.RegressionBusy(dataRoot); if err != nil { return err }
		if busy { fmt.Fprintln(cmd.OutOrStdout(), "Regression in progress"); return nil }
		return &regression.CurationError{Code:1, Err:errors.New("no regression in progress")}
	}
	lock, err := regression.AcquireLock(dataRoot); if err != nil { return err }; defer regression.ReleaseLock(lock)
	if err = regression.InitializeLog(dataRoot); err != nil { return err }
	switch {
	case regressionAccept != "":
		err = regression.AcceptResult(dataRoot, regressionAccept)
		if err == nil { fmt.Fprintf(cmd.OutOrStdout(), "Accepted %s as ref\n", regressionAccept) }
	case regressionReject != "":
		err = regression.RejectResult(dataRoot, regressionReject, regressionReason)
		if err == nil { fmt.Fprintf(cmd.OutOrStdout(), "Rejected %s\n", regressionReject) }
	case regressionStatus:
		var status regression.CurationStatus
		status, err = regression.ReadCurationStatus(dataRoot)
		if err == nil {
			fmt.Fprintf(cmd.OutOrStdout(), "PASS: %d  FAIL: %d  NEW: %d  ERROR: %d  UNSUPPORTED: %d  ACCEPTED: %d  REJECTED: %d\n", status.Totals[regression.Pass], status.Totals[regression.Fail], status.Totals[regression.New], status.Totals[regression.Error], status.Totals[regression.Unsupported], status.Totals[regression.Outcome("accept")], status.Totals[regression.Outcome("reject")])
			cores := make([]string, 0, len(status.Failures)); for core := range status.Failures { cores = append(cores, core) }; sort.Strings(cores)
			for _, core := range cores { fmt.Fprintf(cmd.OutOrStdout(), "%s: %s\n", core, strings.Join(status.Failures[core], ", ")) }
		}
	}
	return err
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


func parse_regression_lists(coreArg, coresArg, setArg string, coreChanged, coresChanged bool) ([]string, []string, error) {
	parse := func(raw, flag string) ([]string,error) {
		if raw=="" { return nil,nil }
		parts:=strings.Split(raw,","); seen:=map[string]bool{}; out:=[]string{}
		for _,part:=range parts { value:=strings.TrimSpace(part); if value=="" || !safe_manual_regression_name(value) { return nil,fmt.Errorf("--%s contains an empty or unsafe name",flag) }; if !seen[value] {seen[value]=true;out=append(out,value)} }
		sort.Strings(out); return out,nil
	}
	coreValues,err:=parse(coreArg,"core");if err!=nil{return nil,nil,err}
	aliasValues,err:=parse(coresArg,"cores");if err!=nil{return nil,nil,err}
	if coreChanged&&coresChanged&&!equalRegressionLists(coreValues,aliasValues){return nil,nil,fmt.Errorf("--core and --cores specify different selections")}
	if len(aliasValues)>0 { coreValues=aliasValues }
	sets,err:=parse(setArg,"setname");if err!=nil{return nil,nil,err}
	return coreValues,sets,nil
}

func equalRegressionLists(a,b []string) bool { if len(a)!=len(b){return false}; for i:=range a{if a[i]!=b[i]{return false}};return true }

func validate_explicit_regression_values(commitMode, coreChanged, coresChanged, setChanged bool, core, cores, set string) error {
	if coreChanged && strings.TrimSpace(core)=="" || coresChanged && strings.TrimSpace(cores)=="" || setChanged && strings.TrimSpace(set)=="" {
		return fmt.Errorf("explicit --core, --cores and --setname values must be nonempty")
	}
	return nil
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
