/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */
package regression

import (
    "encoding/json"
    "fmt"
    "os"
    "path/filepath"
    "strings"
)

// MigrateLogs is a one-time handoff while the normal board lock is held. Only
// full automatic campaigns supply resume state; experimental logs are archived.
func MigrateLogs(root,archive string,cfg Config) error {
    log_dir:=filepath.Join(root,"log")
    archive,err:=filepath.Abs(archive);if err!=nil{return err}
    absolute_log,err:=filepath.Abs(log_dir);if err!=nil{return err}
    relative,err:=filepath.Rel(absolute_log,archive)
    if err!=nil||relative=="."||!strings.HasPrefix(relative,".."+string(os.PathSeparator)){return fmt.Errorf("archive must be outside regression/log")}
    if _,err=os.Stat(archive);err==nil{return fmt.Errorf("migration archive already exists: %s",archive)}else if !os.IsNotExist(err){return err}
    entries,err:=os.ReadDir(log_dir);if err!=nil{return err}
    records:=map[string]*Progress{}
    for _,entry:=range entries{
        if !entry.IsDir(){continue}
        dir:=filepath.Join(log_dir,entry.Name())
        raw,e:=os.ReadFile(filepath.Join(dir,"manifest.json"));if os.IsNotExist(e){continue};if e!=nil{return e}
        var manifest Manifest
        if e=json.Unmarshal(raw,&manifest);e!=nil{return fmt.Errorf("read %s: %w",dir,e)}
        build:=manifest.Build
        if !valid_commit(build.SHA)||entry.Name()!=build.RunID+"-attempt-"+build.Attempt{continue}
        if _,e=ReadProgress(root,build.SHA);e==nil{return fmt.Errorf("commit %s already has compact state",build.SHA)}else if !os.IsNotExist(e){return e}
        progress:=&Progress{Commit:build.SHA,Status:"interrupted",ProjectCommit:manifest.ProjectSHA,ArchiveSHA:build.ArtifactSHA,Games:map[string]ProgressGame{},RBFs:map[string]string{}}
        pr:=0
        if buildReportsToPR(build){pr=build.PR}
        progress.ReportPR=&pr
        var summary Summary
        if data,e:=os.ReadFile(filepath.Join(dir,"summary.json"));e==nil{
            if e=json.Unmarshal(data,&summary);e!=nil{return e}
            progress.Started=summary.Started;progress.Updated=summary.Finished;progress.ReportURL=summary.ReportURL
        }else if !os.IsNotExist(e){return e}
        var build_record archive_record
        if data,e:=os.ReadFile(filepath.Join(dir,"preparation","build-manifest.json"));e==nil{
            if e=json.Unmarshal(data,&build_record);e!=nil{return e}
            if build_record.SHA!=build.SHA{return fmt.Errorf("archive provenance differs for %s",dir)}
            progress.RBFs=build_record.RBF
        }else if !os.IsNotExist(e){return e}
        if progress.RBFs==nil{progress.RBFs=map[string]string{}}
        pending:=false
        for _,core:=range manifest.Cores{
            state,e:=ReadState(filepath.Join(dir,"state",core.Core+".json"))
            if os.IsNotExist(e){state=&State{Games:map[string]GameResult{}}}else if e!=nil{return e}else{
                if state.Core!=core.Core||state.RunID!=manifest.RunID||!sameResumeBuild(state.Build,build){return fmt.Errorf("inconsistent old state for %s/%s",dir,core.Core)}
            }
            verifier:=&Batch{Root:root,CorePath:cfg.Source,Core:core.Core,RunID:manifest.RunID,Build:build,GlobalProfile:cfg.GlobalProfile,
                Firmware:cfg.Firmware,FirmwareSHA256:cfg.FirmwareSHA256,CaptureToolSHA256:cfg.CaptureToolSHA256,read_only_receipts:true}
            for _,game:=range core.Games{
                key:=core.Core+"/"+game.Setname
                previous,ok:=state.Games[game.Setname]
                if !ok||previous.Outcome==""||previous.RecordError!=""{previous=GameResult{Outcome:Pending}}
                fingerprint:=state.GameSpecIdentities[game.Setname]
                output:=""
                if previous.Outcome!=Pending {
                    current,e:=gameSpecIdentity(verifier,game);if e!=nil{return e}
                    unchanged:=fingerprint!=""&&current==fingerprint&&verifier.verifyFinalized(game,previous)
                    if unchanged {
                        fingerprint,e=CompactFingerprint(cfg,build.SHA,core.Core,game);if e!=nil{return e}
                        output,e=result_digest(root,core.Core,game.Setname,previous.Outcome);if e!=nil{unchanged=false}
                    }
                    if !unchanged {
                        fingerprint=state.GameSpecIdentities[game.Setname];output=""
                        if summary.Status!="complete"&&summary.Status!="publication-pending"{previous=GameResult{Outcome:Pending};fingerprint=""}
                    }
                }
                if previous.Outcome==Pending{pending=true}
                item:=ProgressGame{Result:previous.Outcome,Input:fingerprint,Output:output,Seconds:previous.Duration.Seconds()}
                if previous.Outcome==Error||previous.Outcome==Fail{item.Stage=previous.Stage;item.Message=bounded_message(previous.Message)}
                progress.Games[key]=item
                if progress.Started.IsZero()||!previous.Started.IsZero()&&previous.Started.Before(progress.Started){progress.Started=previous.Started}
                if previous.Finished.After(progress.Updated){progress.Updated=previous.Finished}
                if hash:=game.PreparedHashes[game.RBF];hash!=""{progress.RBFs[filepath.Base(game.RBF)]=hash}
            }
        }
        progress.AutomaticComplete=!pending&&(summary.Status=="complete"||summary.Status=="publication-pending")
        if progress.AutomaticComplete{progress.Status="complete"}
        if prior:=records[build.SHA];prior!=nil{
            if prior.Updated.After(progress.Updated){continue}
        }
        records[build.SHA]=progress
    }
    // Conversion is fully validated before touching any old directory.
    if err=os.MkdirAll(archive,0750);err!=nil{return err}
    for commit,progress:=range records{
        record,e:=OpenCommitLog(root,commit);if e!=nil{return e}
        record.Progress=progress
        e=record.Save()
        if e==nil{e=record.Write(fmt.Sprintf("Imported prior regression progress: %d games, %s",len(progress.Games),progress.Status))}
        close_error:=record.Close();if e!=nil{return e};if close_error!=nil{return close_error}
    }
    for _,entry:=range entries{
        name:=entry.Name()
        if name=="lock"||name=="upload-directories.json"||name=="README.md"{continue}
        if !entry.IsDir(){
            key:=strings.TrimSuffix(strings.TrimSuffix(name,".json"),".log")
            commit:=strings.TrimSuffix(key,"-dirty")
            if valid_commit(commit)||len(commit)==7&&valid_commit(commit+strings.Repeat("0",33)){continue}
        }
        source:=filepath.Join(log_dir,name)
        destination:=filepath.Join(archive,name)
        // /gdrive and /nobackup may be different filesystems.
        if entry.IsDir(){
            if err=copy_tree(source,destination);err!=nil{return err}
        }else{if err=copyFile(source,destination);err!=nil{return err}}
        if err=os.RemoveAll(source);err!=nil{return err}
    }
    return InitializeLog(root)
}

// ImportProgress can finish a migration from its retained archive. It only
// restores pending entries or normalizes early compact fingerprints, only when
// the old input and output evidence still verifies.
func ImportProgress(root,legacy string,cfg Config) error {
    data,err:=os.ReadFile(filepath.Join(legacy,"manifest.json"));if err!=nil{return err}
    var manifest Manifest
    if err=json.Unmarshal(data,&manifest);err!=nil{return err}
    if !safeComponent(manifest.RunID){return fmt.Errorf("unsafe legacy run name")}
    record,err:=OpenCommitLog(root,manifest.Build.SHA);if err!=nil{return err};defer record.Close()
    work,err:=os.MkdirTemp("/tmp","jtutil-regression-import-");if err!=nil{return err};defer os.RemoveAll(work)
    if err=os.MkdirAll(filepath.Join(work,"log"),0750);err!=nil{return err}
    legacy,err=filepath.Abs(legacy);if err!=nil{return err}
    if err=os.Symlink(legacy,filepath.Join(work,"log",manifest.RunID));err!=nil{return err}
    count:=0
    for _,core:=range manifest.Cores{
        if !safeComponent(core.Core){return fmt.Errorf("unsafe legacy core name")}
        state,e:=ReadState(filepath.Join(legacy,"state",core.Core+".json"));if os.IsNotExist(e){continue};if e!=nil{return e}
        if state.Core!=core.Core||state.RunID!=manifest.RunID||!sameResumeBuild(state.Build,manifest.Build){return fmt.Errorf("inconsistent legacy state")}
        verifier:=&Batch{Root:root,DiagnosticsRoot:work,CorePath:cfg.Source,Core:core.Core,RunID:manifest.RunID,Build:manifest.Build,GlobalProfile:cfg.GlobalProfile,
            Firmware:cfg.Firmware,FirmwareSHA256:cfg.FirmwareSHA256,CaptureToolSHA256:cfg.CaptureToolSHA256,read_only_receipts:true}
        for _,game:=range core.Games{
            if !safeComponent(game.Setname){return fmt.Errorf("unsafe legacy setname")}
            key:=core.Core+"/"+game.Setname
            existing,ok:=record.Progress.Games[key];if !ok{continue}
            if existing.Result!=Pending {
                old,e:=compact_legacy_fingerprint(cfg,manifest.Build.SHA,core.Core,game);if e!=nil{return e}
                if existing.Input!=old{continue}
            }
            previous,ok:=state.Games[game.Setname];if !ok||previous.Outcome==Pending||previous.RecordError!=""{continue}
            current,e:=gameSpecIdentity(verifier,game);if e!=nil{return e}
            if current!=state.GameSpecIdentities[game.Setname]||!verifier.verifyFinalized(game,previous){continue}
            fingerprint,e:=CompactFingerprint(cfg,manifest.Build.SHA,core.Core,game);if e!=nil{return e}
            output,e:=result_digest(root,core.Core,game.Setname,previous.Outcome);if e!=nil{return e}
            if existing.Result!=Pending&&(existing.Result!=previous.Outcome||existing.Output!=output){continue}
            item:=ProgressGame{Result:previous.Outcome,Input:fingerprint,Output:output,Seconds:previous.Duration.Seconds()}
            if previous.Outcome==Error||previous.Outcome==Fail{item.Stage=previous.Stage;item.Message=bounded_message(previous.Message)}
            record.Progress.Games[key]=item;count++
        }
    }
    if err=record.Save();err!=nil{return err}
    return record.Write(fmt.Sprintf("Restored %d verified results from migration archive",count))
}
