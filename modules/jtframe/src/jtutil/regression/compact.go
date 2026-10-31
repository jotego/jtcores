/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */
package regression

import (
    "context"
    "encoding/json"
    "fmt"
    "os"
    "path/filepath"
    "os/exec"
    "regexp"
    "sort"
    "strings"
    "time"
)

const log_readme = `# Regression execution records

This directory belongs exclusively to jtutil regression.

AI agents: do not store experiments, investigations, scripts, plans, screenshots,
firmware logs or other task artifacts here. Use /nobackup/tasks/<task-name>/.
Do not create ad hoc subdirectories or edit progress files during a run.

Each RBF source commit has two files, named with the same seven-character hash
as the build ZIP (manual dirty checkouts add -dirty):
- <commit>.json: current results and progress used to resume an interrupted run.
- <commit>.log: readable execution results, warnings and errors.
Text columns are date, time, core/setname, runtime, verdict and optional details.
Frame differences show differing/compared frames; startup frames are excluded.
Timestamps use local time with a space between the date and time. JSON timestamps
also retain the UTC offset. Older UTC progress files remain readable.

lock serializes manual and scheduled regressions. upload-directories.json tracks
owned board files awaiting cleanup. poll.log contains the latest discovery/setup
error before a build is selected. No new run files are created by an idle poll.

Images are in ../<core>/<game>/{ref,new,fail}. Temporary preparation and capture
files are in /tmp and are removed. Only a designer may approve references.
Each ../<core>/<game>/log keeps completed checks: local date/time, short commit,
verdict and reference CRC32 (-------- when no reference exists).
Deleting a commit's JSON forgets its progress and permits testing it again.
`

type Progress struct {
    Commit string `json:"commit"`
    Dirty bool `json:"dirty,omitempty"`
    Status string `json:"status"`
    AutomaticComplete bool `json:"automatic_complete,omitempty"`
    ProjectCommit string `json:"project_commit,omitempty"`
    Started time.Time `json:"started"`
    Updated time.Time `json:"updated"`
    Current string `json:"current,omitempty"`
    Error string `json:"error,omitempty"`
    ArchiveSHA string `json:"archive_sha256,omitempty"`
    RBFs map[string]string `json:"rbfs,omitempty"`
    Games map[string]ProgressGame `json:"games"`
    ReportURL string `json:"report_url,omitempty"`
    ReportPR *int `json:"report_pr,omitempty"`
}

type ProgressGame struct {
    Result Outcome `json:"result"`
    Input string `json:"input,omitempty"`
    Output string `json:"output,omitempty"`
    Seconds float64 `json:"seconds,omitempty"`
    Stage string `json:"stage,omitempty"`
    Message string `json:"message,omitempty"`
}

type CommitLog struct {
    Root string
    Progress *Progress
    file *os.File
}

func InitializeLog(root string) error {
    dir:=filepath.Join(root,"log")
    if err:=os.MkdirAll(dir,0750);err!=nil{return err}
    if err:=shorten_log_names(dir);err!=nil{return err}
    return os.WriteFile(filepath.Join(dir,"README.md"),[]byte(log_readme),0640)
}

func OpenCommitLog(root,commit string,dirty ...bool)(*CommitLog,error) {
    is_dirty:=len(dirty)>0&&dirty[0]
    key:=LogKey(commit,is_dirty)
    if !valid_commit(commit){return nil,fmt.Errorf("RBF commit must be a full 40-character git SHA")}
    progress_key:=commit;if is_dirty{progress_key+="-dirty"}
    progress,err:=ReadProgress(root,progress_key)
    if os.IsNotExist(err){progress=&Progress{Commit:commit,Dirty:is_dirty,Started:time.Now(),Games:map[string]ProgressGame{},RBFs:map[string]string{}}}else if err!=nil{return nil,err}
    file,err:=os.OpenFile(filepath.Join(root,"log",key+".log"),os.O_CREATE|os.O_APPEND|os.O_WRONLY,0640)
    if err!=nil{return nil,err}
    return &CommitLog{Root:root,Progress:progress,file:file},nil
}

func ReadProgress(root,key string)(*Progress,error) {
    commit:=strings.TrimSuffix(key,"-dirty")
    if !valid_commit(commit){return nil,fmt.Errorf("invalid RBF commit %q",commit)}
    short_key:=LogKey(commit,strings.HasSuffix(key,"-dirty"))
    data,err:=os.ReadFile(filepath.Join(root,"log",short_key+".json"))
    if os.IsNotExist(err){data,err=os.ReadFile(filepath.Join(root,"log",key+".json"))}
    if err!=nil{return nil,err}
    var progress Progress
    if err=json.Unmarshal(data,&progress);err!=nil{return nil,fmt.Errorf("read commit progress: %w",err)}
    if progress.Commit!=commit || LogKey(progress.Commit,progress.Dirty)!=short_key || progress.Games==nil{return nil,fmt.Errorf("invalid progress for commit %s (short filename collision or invalid state)",commit)}
    if progress.AutomaticComplete && len(progress.Games)==0{return nil,fmt.Errorf("completed progress has no games")}
    for key,game:=range progress.Games{
        core,set,ok:=strings.Cut(key,"/")
        if !ok||!safeComponent(core)||!safeComponent(set){return nil,fmt.Errorf("invalid progress game %q",key)}
        switch game.Result{case Pass,New,Fail,Error,Unsupported:case Pending:if progress.AutomaticComplete{return nil,fmt.Errorf("completed progress contains pending games")};default:return nil,fmt.Errorf("invalid result for %s",key)}
    }
    if progress.Current!=""{if _,ok:=progress.Games[progress.Current];!ok{return nil,fmt.Errorf("current game is outside progress inventory")}}
    if progress.RBFs==nil{progress.RBFs=map[string]string{}}
    return &progress,nil
}

func (l *CommitLog) Save() error {
    l.Progress.Updated=time.Now()
    data,err:=json.MarshalIndent(l.Progress,"","  ");if err!=nil{return err}
    return atomic_write(filepath.Join(l.Root,"log",LogKey(l.Progress.Commit,l.Progress.Dirty)+".json"),append(data,'\n'),0640)
}

func (l *CommitLog) Write(message string) error {
    return l.Entry("",-1,"info",message)
}

func (l *CommitLog) Entry(game string,seconds float64,verdict,message string) error {
    _,err:=fmt.Fprint(l.file,FormatLogEntry(time.Now(),game,seconds,verdict,message))
    if err!=nil{return err};return l.file.Sync()
}
func (l *CommitLog) Close() error {return l.file.Close()}

func (l *CommitLog) Failed(err error) error {
    l.Progress.Status="interrupted"
    l.Progress.Error=bounded_message(err.Error())
    if save_error:=l.Save();save_error!=nil{return fmt.Errorf("%w; save progress: %v",err,save_error)}
    if log_error:=l.Entry(l.Progress.Current,-1,"error",l.Progress.Error);log_error!=nil{return fmt.Errorf("%w; write log: %v",err,log_error)}
    return err
}

func valid_commit(commit string) bool {
    if len(commit)!=40{return false}
    for _,c:=range commit{if !(c>='0'&&c<='9'||c>='a'&&c<='f'){return false}}
    return true
}

func commit_complete(root,commit string,local_only bool) bool {
    progress,err:=ReadProgress(root,commit)
    return err==nil && progress.AutomaticComplete && (local_only || progress.ReportURL!="")
}

func bounded_message(message string) string {
    if len(message)>16384{return message[:16384]+" [truncated]"};return message
}

func LogKey(commit string,dirty bool) string {
    if len(commit)>7{commit=commit[:7]}
    if dirty{return commit+"-dirty"};return commit
}

// Called under the command's board lock, before opening any log file.
func shorten_log_names(dir string) error {
    entries,err:=os.ReadDir(dir);if err!=nil{return err}
    moves:=map[string]string{}
    owners:=map[string]string{}
    for _,entry:=range entries{
        if entry.IsDir()||filepath.Ext(entry.Name())!=".json"{continue}
        key:=strings.TrimSuffix(entry.Name(),".json")
        prefix:=strings.TrimSuffix(key,"-dirty")
        if len(prefix)!=7||!valid_commit(prefix+strings.Repeat("0",33)){continue}
        data,e:=os.ReadFile(filepath.Join(dir,entry.Name()));if e!=nil{return e}
        var progress Progress
        if e=json.Unmarshal(data,&progress);e!=nil{return e}
        if !valid_commit(progress.Commit)||LogKey(progress.Commit,progress.Dirty)!=key{return fmt.Errorf("invalid commit in %s",entry.Name())}
        owners[key]=progress.Commit
    }
    for _,entry:=range entries{
        extension:=filepath.Ext(entry.Name())
        if entry.IsDir()||extension!=".json"&&extension!=".log"{continue}
        key:=strings.TrimSuffix(entry.Name(),extension)
        commit:=strings.TrimSuffix(key,"-dirty")
        if !valid_commit(commit){continue}
        short_key:=LogKey(commit,strings.HasSuffix(key,"-dirty"))
        if owner:=owners[short_key];owner!=""&&owner!=commit{return fmt.Errorf("short log filename collision: %s",short_key)}
        owners[short_key]=commit
        destination:=filepath.Join(dir,short_key+extension)
        if _,exists:=moves[destination];exists{return fmt.Errorf("short log filename collision: %s",destination)}
        if _,e:=os.Stat(destination);e==nil{return fmt.Errorf("short log filename already exists: %s",destination)}else if !os.IsNotExist(e){return e}
        moves[destination]=filepath.Join(dir,entry.Name())
    }
    for destination,source:=range moves{
        if err=os.Rename(source,destination);err!=nil{return err}
    }
    return nil
}

// Manual identity follows the developer checkout, or the release commit that
// last supplied this RBF in JTBIN. Do not confuse JTBIN's own SHA with jtcores.
func ManualCommit(ctx context.Context,source,core string,use_jtbin bool)(string,bool,error) {
    if !use_jtbin {
        commit,err:=gitHead(ctx,source);if err!=nil{return "",false,err}
        out,err:=exec.CommandContext(ctx,"git","-C",source,"status","--porcelain","--untracked-files=normal").Output()
        return commit,len(strings.TrimSpace(string(out)))>0,err
    }
    release:=os.Getenv("JTBIN")
    if release==""{return "",false,fmt.Errorf("JTBIN is required")}
    out,err:=exec.CommandContext(ctx,"git","-C",release,"log","-1","--format=%B","--","sidi128/jt"+core+".rbf").Output()
    if err!=nil{return "",false,fmt.Errorf("read JTBIN release history: %w",err)}
    match:=regexp.MustCompile(`jtcores/commit/([0-9a-f]{40})`).FindSubmatch(out)
    if len(match)!=2{return "",false,fmt.Errorf("JTBIN RBF commit message does not identify a jtcores source commit")}
    return string(match[1]),false,nil
}

// RunCommit keeps one compact result per game. Existing capture/comparison code
// writes its detailed working receipts only below a disposable /tmp directory.
func RunCommit(ctx context.Context,log *CommitLog,manifest Manifest,cfg Config,hardware Hardware,manual,retry bool,partial ...bool) error {
    progress:=log.Progress
    was_complete:=progress.AutomaticComplete
    full:=!manual && !(len(partial)>0&&partial[0])
    if full {
        selected:=map[string]bool{}
        for _,core:=range manifest.Cores{for _,game:=range core.Games{selected[core.Core+"/"+game.Setname]=true}}
        for key:=range progress.Games{if !selected[key]{delete(progress.Games,key)}}
    }
    progress.Status="running";progress.Error="";progress.Current="";progress.ProjectCommit=manifest.ProjectSHA
    progress.AutomaticComplete=false
    for _,core:=range manifest.Cores{for _,game:=range core.Games{
        key:=core.Core+"/"+game.Setname
        if _,ok:=progress.Games[key];!ok{progress.Games[key]=ProgressGame{Result:Pending}}
        if game.RBF!="" {
            hash,err:=FileSHA256(game.RBF);if err!=nil{return log.Failed(err)}
            name:=filepath.Base(game.RBF)
            if old:=progress.RBFs[name];old!=""&&old!=hash&&!manual{return log.Failed(fmt.Errorf("RBF %s changed for commit %s",name,progress.Commit))}
            progress.RBFs[name]=hash
        }
    }}
    if err:=log.Save();err!=nil{return err}
    for _,core:=range manifest.Cores{
        batch:=&Batch{Context:ctx,Root:log.Root,CorePath:cfg.Source,Core:core.Core,RunID:progress.Commit,
            Build:BuildIdentity{SHA:progress.Commit},ProjectSHA:manifest.ProjectSHA,Hardware:hardware,
            GlobalProfile:cfg.GlobalProfile,Firmware:cfg.Firmware,FirmwareSHA256:cfg.FirmwareSHA256,CaptureToolSHA256:cfg.CaptureToolSHA256}
        batch.Log=&EventLog{Sink:func(event Event)error{
            if event.Outcome!=Error && !strings.Contains(event.Stage,"warning"){return nil}
            verdict:="warning";if event.Outcome==Error{verdict="error"}
            return log.Entry(core.Core+"/"+event.Setname,-1,verdict,event.Stage+": "+bounded_message(event.Message))
        }}
        for _,game:=range core.Games{
            if err:=ctx.Err();err!=nil{return log.Failed(err)}
            key:=core.Core+"/"+game.Setname
            fingerprint,err:=CompactFingerprint(cfg,progress.Commit,core.Core,game)
            if err!=nil{return log.Failed(err)}
            previous:=progress.Games[key]
            if !manual && previous.Result!=Pending && previous.Result!="" && !(retry&&previous.Result==Error) {
                if previous.Input==fingerprint {
                    digest,output_error:=result_digest(log.Root,core.Core,game.Setname,previous.Result)
                    if output_error==nil && digest==previous.Output{continue}
                    if err=log.Entry(key,-1,"repeat","result images missing or changed");err!=nil{return err}
                } else {
                    if err=log.Entry(key,-1,"repeat","inputs changed");err!=nil{return err}
                }
            }
            progress.Current=key;progress.Games[key]=ProgressGame{Result:Pending,Input:fingerprint}
            if err=log.Save();err!=nil{return err}
            if err=log.Entry(key,-1,"started","");err!=nil{return err}
            work,err:=os.MkdirTemp("/tmp","jtutil-regression-records-");if err!=nil{return log.Failed(err)}
            batch.DiagnosticsRoot=work
            result:=batch.runGame(game)
            cleanup_error:=os.RemoveAll(work)
            if cleanup_error!=nil{return log.Failed(cleanup_error)}
            if result.RecordError!=""{return log.Failed(fmt.Errorf("%s: %s",key,result.RecordError))}
            if result.Stage=="board"{return log.Failed(fmt.Errorf("%s: %s",key,result.Message))}
            digest,err:=result_digest(log.Root,core.Core,game.Setname,result.Outcome)
            if err!=nil{return log.Failed(err)}
            item:=ProgressGame{Result:result.Outcome,Input:fingerprint,Output:digest,Seconds:result.Duration.Seconds()}
            if result.Outcome==Error||result.Outcome==Fail{item.Stage=result.Stage;item.Message=bounded_message(result.Message)}
            if err=log.append_game_history(core.Core,game.Setname,result);err!=nil{return log.Failed(err)}
            progress.Games[key]=item;progress.Current=""
            if err=log.Save();err!=nil{return err}
            if err=log.Entry(key,item.Seconds,string(result.Outcome),item.Message);err!=nil{return err}
        }
        if releaser,ok:=hardware.(interface{ReleaseCore()error});ok{
            if err:=releaser.ReleaseCore();err!=nil{return log.Failed(err)}
        }
    }
    progress.Status="complete";progress.Current=""
    if full||was_complete{
        progress.AutomaticComplete=true
        for _,game:=range progress.Games{if game.Result==Pending{progress.AutomaticComplete=false}}
    }
    if err:=log.Save();err!=nil{return err}
    return log.Entry("",-1,"complete","")
}

func CompactFingerprint(cfg Config,commit,core string,game GameSpec)(string,error) {
    // MRA metadata and preparation diagnostics are not board inputs. The actual
    // ARC/RBF/ROM/CAB bytes and profiles are hashed by gameSpecIdentity below.
    game.PreparedHashes=nil
    game.PreparationWarnings=nil
    return compact_legacy_fingerprint(cfg,commit,core,game)
}

func compact_legacy_fingerprint(cfg Config,commit,core string,game GameSpec)(string,error) {
    batch:=&Batch{Core:core,CorePath:cfg.Source,Build:BuildIdentity{SHA:commit},GlobalProfile:cfg.GlobalProfile,
        Firmware:cfg.Firmware,FirmwareSHA256:cfg.FirmwareSHA256,CaptureToolSHA256:cfg.CaptureToolSHA256}
    return gameSpecIdentity(batch,game)
}

func (l *CommitLog) Summary(build BuildIdentity) Summary {
    p:=l.Progress
    summary:=Summary{RunID:p.Commit,Build:build,Started:p.Started,Finished:p.Updated,Status:p.Status,Coverage:map[string]int{},OperationalError:p.Error}
    summary.Duration=p.Updated.Sub(p.Started)
    keys:=make([]string,0,len(p.Games))
    for key:=range p.Games{keys=append(keys,key)};sort.Strings(keys)
    for _,key:=range keys{
        result:=p.Games[key]
        core,set,_:=strings.Cut(key,"/")
        summary.Games=append(summary.Games,GameResult{Core:core,Setname:set,Outcome:result.Result,Stage:result.Stage,Message:result.Message,Duration:time.Duration(result.Seconds*float64(time.Second)),Attention:result.Result==New||result.Result==Fail||result.Result==Error})
        summary.Coverage[string(result.Result)]++
    }
    return summary
}

// One digest of the published PNG files replaces all per-frame receipts.
func result_digest(root,core,set string,outcome Outcome)(string,error) {
    if outcome==Error||outcome==Unsupported||outcome==Pending{return "",nil}
    slot:=string(outcome);if outcome==Pass{slot="ref"}
    dir:=filepath.Join(root,core,set,slot)
    if outcome==New{if _,err:=os.Stat(dir);os.IsNotExist(err){dir=filepath.Join(root,core,set,"ref")}}
    paths,err:=filepath.Glob(filepath.Join(dir,"*.png"));if err!=nil{return "",err}
    if len(paths)==0{return "",fmt.Errorf("result PNGs are missing for %s/%s",core,set)}
    files:=map[string]string{}
    for _,path:=range paths{files[filepath.Base(path)]=path}
    return HashFiles(files)
}
