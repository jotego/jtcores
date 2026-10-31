/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */
package regression

import (
    "context"
    "os"
    "path/filepath"
    "strings"
    "testing"
)

func compact_fixture(t *testing.T)(*CommitLog,Manifest,Config,*qualityHardware) {
    t.Helper()
    batch,game,hardware:=qualityBatch(t,[]uint16{1,2,3})
    root:=t.TempDir()
    if err:=InitializeLog(root);err!=nil{t.Fatal(err)}
    record,err:=OpenCommitLog(root,strings.Repeat("a",40));if err!=nil{t.Fatal(err)}
    t.Cleanup(func(){record.Close()})
    manifest:=Manifest{Build:BuildIdentity{SHA:record.Progress.Commit},Cores:[]CoreManifest{{Core:"fake",Games:[]GameSpec{game}}}}
    cfg:=Config{Source:batch.CorePath,GlobalProfile:batch.GlobalProfile,Firmware:batch.Firmware,FirmwareSHA256:batch.FirmwareSHA256,CaptureToolSHA256:batch.CaptureToolSHA256}
    return record,manifest,cfg,hardware
}

func TestCompactResumeFootprintAndChangedInputs(t *testing.T) {
    record,manifest,cfg,hardware:=compact_fixture(t)
    if err:=RunCommit(context.Background(),record,manifest,cfg,hardware,false,false);err!=nil{t.Fatal(err)}
    if record.Progress.Games["fake/quality"].Result!=New||hardware.loads!=1{t.Fatalf("capture failed: %+v",record.Progress)}
    // A fresh process reads only the compact JSON and resumes without recapture.
    record.Close()
    reopened,err:=OpenCommitLog(record.Root,record.Progress.Commit);if err!=nil{t.Fatal(err)};defer reopened.Close()
    if err=RunCommit(context.Background(),reopened,manifest,cfg,hardware,false,false);err!=nil{t.Fatal(err)}
    if hardware.loads!=1{t.Fatal("completed game was repeated")}
    entries,err:=os.ReadDir(filepath.Join(record.Root,"log"));if err!=nil{t.Fatal(err)}
    if len(entries)!=3{t.Fatalf("unexpected persistent files: %v",entries)}
    for _,entry:=range entries{if entry.IsDir(){t.Fatal("per-game log folder retained")}}
    // Deliberate manual reruns refresh only the chosen game.
    if err=RunCommit(context.Background(),reopened,manifest,cfg,hardware,true,false);err!=nil{t.Fatal(err)}
    if hardware.loads!=2{t.Fatal("manual run silently reused old capture")}
    // Source fixture changes invalidate the compact input fingerprint.
    game:=manifest.Cores[0].Games[0]
    manualWrite(t,game.ARC,[]byte("changed ARC"))
    if err=RunCommit(context.Background(),reopened,manifest,cfg,hardware,false,false);err!=nil{t.Fatal(err)}
    if hardware.loads!=3{t.Fatal("changed fixture was silently skipped")}
    os.Remove(filepath.Join(record.Root,"fake","quality","new","frame_00000100.png"))
    if err=RunCommit(context.Background(),reopened,manifest,cfg,hardware,false,false);err!=nil{t.Fatal(err)}
    if hardware.loads!=4{t.Fatal("missing result PNG silently accepted")}
    reopened.Progress.Games["fake/obsolete"]=ProgressGame{Result:New}
    if err=RunCommit(context.Background(),reopened,manifest,cfg,hardware,false,false);err!=nil{t.Fatal(err)}
    if _,ok:=reopened.Progress.Games["fake/obsolete"];ok{t.Fatal("obsolete game remained in full inventory")}
}

func TestCompactFingerprintIgnoresRegeneratedMRAMetadata(t *testing.T) {
    record,manifest,cfg,_:=compact_fixture(t)
    game:=manifest.Cores[0].Games[0]
    game.PreparedHashes=map[string]string{"game.mra":"old metadata"}
    before,err:=CompactFingerprint(cfg,record.Progress.Commit,"fake",game);if err!=nil{t.Fatal(err)}
    game.PreparedHashes["game.mra"]="regenerated metadata"
    after,err:=CompactFingerprint(cfg,record.Progress.Commit,"fake",game);if err!=nil{t.Fatal(err)}
    if before!=after{t.Fatal("MRA metadata changed the execution fingerprint")}
    manualWrite(t,game.ARC,[]byte("changed actual board configuration"))
    changed,err:=CompactFingerprint(cfg,record.Progress.Commit,"fake",game);if err!=nil{t.Fatal(err)}
    if changed==before{t.Fatal("changed board input was ignored")}
}

func TestCompactShortFilenamesMigrateAndRejectCollisions(t *testing.T) {
    commit:="f848902"+strings.Repeat("a",33)
    other:="f848902"+strings.Repeat("b",33)
    for _,dirty:=range []bool{false,true}{
        root:=t.TempDir();old_key:=commit;if dirty{old_key+="-dirty"}
        progress:=Progress{Commit:commit,Dirty:dirty,Status:"interrupted",Games:map[string]ProgressGame{"fake/game":{Result:Pending}}}
        manualWrite(t,filepath.Join(root,"log",old_key+".json"),mustJSON(t,progress))
        manualWrite(t,filepath.Join(root,"log",old_key+".log"),[]byte("existing history\n"))
        if err:=InitializeLog(root);err!=nil{t.Fatal(err)}
        record,err:=OpenCommitLog(root,commit,dirty);if err!=nil{t.Fatal(err)};record.Close()
        key:="f848902";if dirty{key+="-dirty"}
        if LogKey(commit,dirty)!=key{t.Fatal("wrong shortened filename")}
        data,err:=os.ReadFile(filepath.Join(root,"log",key+".log"));if err!=nil{t.Fatal(err)}
        if string(data)!="existing history\n"{t.Fatal("migration lost history")}
        if _,err=os.Stat(filepath.Join(root,"log",old_key+".json"));!os.IsNotExist(err){t.Fatal("full hash filename remained")}
        if record.Progress.Commit!=commit{t.Fatal("full identity lost inside JSON")}
        if _,err=OpenCommitLog(root,other,dirty);err==nil{t.Fatal("short prefix collision accepted")}
        if err=InitializeLog(root);err!=nil{t.Fatal("migration is not idempotent",err)}
    }
    root:=t.TempDir()
    manualWrite(t,filepath.Join(root,"log",commit+".json"),[]byte("first record"))
    manualWrite(t,filepath.Join(root,"log",other+".log"),[]byte("second record"))
    if err:=InitializeLog(root);err==nil{t.Fatal("colliding old records migrated")}
    if _,err:=os.Stat(filepath.Join(root,"log",commit+".json"));err!=nil{t.Fatal("collision modified existing records")}
    mixed:=t.TempDir()
    manualWrite(t,filepath.Join(mixed,"log",LogKey(commit,false)+".json"),mustJSON(t,Progress{Commit:commit}))
    legacy:=filepath.Join(mixed,"log",other+".log")
    manualWrite(t,legacy,[]byte("another commit's history"))
    if err:=InitializeLog(mixed);err==nil{t.Fatal("legacy log paired with another commit's short JSON")}
    if _,err:=os.Stat(legacy);err!=nil{t.Fatal("mixed collision moved legacy history")}
}

type cancel_compact_hardware struct { *qualityHardware; cancel context.CancelFunc }
func(h *cancel_compact_hardware)Run(game GameSpec,cab,dir string)(RunInfo,error){
    result,err:=h.qualityHardware.Run(game,cab,dir)
    if h.cancel!=nil{h.cancel();h.cancel=nil}
    return result,err
}

func TestCompactInterruptionResumesOnlyPendingGames(t *testing.T) {
    record,manifest,cfg,hardware:=compact_fixture(t)
    second:=manifest.Cores[0].Games[0];second.Setname="second"
    manifest.Cores[0].Games=append(manifest.Cores[0].Games,second)
    ctx,cancel:=context.WithCancel(context.Background())
    interrupted:=&cancel_compact_hardware{qualityHardware:hardware,cancel:cancel}
    if err:=RunCommit(ctx,record,manifest,cfg,interrupted,false,false);err==nil{t.Fatal("expected interruption")}
    saved,err:=ReadProgress(record.Root,record.Progress.Commit);if err!=nil{t.Fatal(err)}
    if saved.AutomaticComplete||saved.Games["fake/quality"].Result!=New||saved.Games["fake/second"].Result!=Pending{t.Fatalf("bad interruption state: %+v",saved)}
    if err=RunCommit(context.Background(),record,manifest,cfg,hardware,false,false);err!=nil{t.Fatal(err)}
    if hardware.loads!=2||!record.Progress.AutomaticComplete{t.Fatalf("resume repeated work: %d %+v",hardware.loads,record.Progress)}
}

func TestCompactErrorsContinueAndManualIsNotFullBatch(t *testing.T) {
    record,manifest,cfg,hardware:=compact_fixture(t)
    broken:=manifest.Cores[0].Games[0];broken.Setname="broken";broken.PreparationError="missing ROM"
    manifest.Cores[0].Games=append([]GameSpec{broken},manifest.Cores[0].Games...)
    if err:=RunCommit(context.Background(),record,manifest,cfg,hardware,true,false);err!=nil{t.Fatal(err)}
    if record.Progress.Games["fake/broken"].Result!=Error||record.Progress.Games["fake/quality"].Result!=New||record.Progress.AutomaticComplete{t.Fatalf("bad manual/error handling: %+v",record.Progress)}
}

func TestCompactCommitCompletionIgnoresWorkflowAttempts(t *testing.T) {
    record,_,_,_:=compact_fixture(t)
    record.Progress.Games["fake/game"]=ProgressGame{Result:Pass}
    record.Progress.AutomaticComplete=true;record.Progress.Status="complete"
    if err:=record.Save();err!=nil{t.Fatal(err)}
    if !commit_complete(record.Root,record.Progress.Commit,true){t.Fatal("local completion not recognized")}
    if commit_complete(record.Root,record.Progress.Commit,false){t.Fatal("pending report suppressed")}
    record.Progress.ReportURL="https://example.test/report";record.Save()
    if !commit_complete(record.Root,record.Progress.Commit,false){t.Fatal("published completion not recognized")}
    dirty,err:=OpenCommitLog(record.Root,record.Progress.Commit,true);if err!=nil{t.Fatal(err)};defer dirty.Close()
    if dirty.Progress.AutomaticComplete{t.Fatal("dirty run inherited clean completion")}
    dirty.Save()
    if _,err=os.Stat(filepath.Join(record.Root,"log",LogKey(record.Progress.Commit,true)+".json"));err!=nil{t.Fatal(err)}
}

func TestCompactMigrationPreservesPendingAndArchivesClutter(t *testing.T) {
    root:=t.TempDir();archive:=filepath.Join(t.TempDir(),"old-logs")
    source:=t.TempDir()
    global:=filepath.Join(source,"reg.yaml");manualWrite(t,global,[]byte("video: 300\nstart-up: 0\n"))
    cfg:=Config{Source:source,GlobalProfile:global}
    build:=BuildIdentity{SHA:strings.Repeat("b",40),RunID:"123",Attempt:"1"}
    manifest:=Manifest{RunID:"123-attempt-1",Build:build,Cores:[]CoreManifest{{Core:"fake",Games:[]GameSpec{{Setname:"done",PreparedHashes:map[string]string{"game.mra":"metadata"}},{Setname:"pending"}}}}}
    dir:=filepath.Join(root,"log","123-attempt-1")
    manualWrite(t,filepath.Join(dir,"manifest.json"),mustJSON(t,manifest))
    old_batch:=&Batch{Core:"fake",CorePath:source,Build:build,GlobalProfile:global}
    fingerprint,err:=gameSpecIdentity(old_batch,manifest.Cores[0].Games[0]);if err!=nil{t.Fatal(err)}
    manualWrite(t,filepath.Join(dir,"state","fake.json"),mustJSON(t,State{RunID:manifest.RunID,Build:build,Core:"fake",GameSpecIdentities:map[string]string{"done":fingerprint},Games:map[string]GameResult{"done":{Outcome:Error,Message:"recorded error"}}}))
    manualWrite(t,filepath.Join(root,"log","experiment","notes.txt"),[]byte("old experiment"))
    manualWrite(t,filepath.Join(root,"log","upload-directories.json"),[]byte("{}"))
    if err:=MigrateLogs(root,archive,cfg);err!=nil{t.Fatal(err)}
    progress,err:=ReadProgress(root,build.SHA);if err!=nil{t.Fatal(err)}
    if progress.Games["fake/done"].Result!=Error||progress.Games["fake/pending"].Result!=Pending||progress.AutomaticComplete{t.Fatalf("bad migration %+v",progress)}
    if _,err=os.Stat(filepath.Join(archive,"123-attempt-1","manifest.json"));err!=nil{t.Fatal(err)}
    if _,err=os.Stat(filepath.Join(archive,"experiment","notes.txt"));err!=nil{t.Fatal(err)}
    entries,err:=os.ReadDir(filepath.Join(root,"log"));if err!=nil{t.Fatal(err)}
    for _,entry:=range entries{if entry.IsDir(){t.Fatalf("old directory left: %s",entry.Name())}}
    if _,err=os.Stat(filepath.Join(root,"log","upload-directories.json"));err!=nil{t.Fatal(err)}
    record,err:=OpenCommitLog(root,build.SHA);if err!=nil{t.Fatal(err)}
    record.Progress.Games["fake/done"]=ProgressGame{Result:Pending};record.Save();record.Close()
    if err=ImportProgress(root,filepath.Join(archive,manifest.RunID),cfg);err!=nil{t.Fatal(err)}
    restored,err:=ReadProgress(root,build.SHA);if err!=nil{t.Fatal(err)}
    if restored.Games["fake/done"].Result!=Error{t.Fatal("verified archived progress was not restored")}
    record,err=OpenCommitLog(root,build.SHA);if err!=nil{t.Fatal(err)}
    item:=record.Progress.Games["fake/done"]
    item.Input,err=compact_legacy_fingerprint(cfg,build.SHA,"fake",manifest.Cores[0].Games[0]);if err!=nil{t.Fatal(err)}
    record.Progress.Games["fake/done"]=item;record.Save();record.Close()
    if err=ImportProgress(root,filepath.Join(archive,manifest.RunID),cfg);err!=nil{t.Fatal(err)}
    normalized,err:=ReadProgress(root,build.SHA);if err!=nil{t.Fatal(err)}
    if normalized.Games["fake/done"]!=restored.Games["fake/done"]{t.Fatal("early compact fingerprint was not safely normalized")}
}

func TestDiscoverySkipsOtherWorkflowRunsOfCompletedCommit(t *testing.T) {
    record,_,_,_:=compact_fixture(t)
    record.Progress.Games["fake/game"]=ProgressGame{Result:Pass}
    record.Progress.AutomaticComplete=true;record.Progress.Status="complete";record.Save()
    original:=ghCommand;defer func(){ghCommand=original}()
    ghCommand=func(_ context.Context,args ...string)([]byte,error){
        if !strings.Contains(strings.Join(args," "),"workflows/compile-all.yaml/runs"){t.Fatalf("completed SHA inspected again: %v",args)}
        return []byte(`[{"workflow_runs":[{"id":101,"name":"Compile all","run_attempt":1,"status":"completed","conclusion":"success","head_sha":"`+record.Progress.Commit+`"},{"id":202,"name":"Compile all","run_attempt":3,"status":"completed","conclusion":"success","head_sha":"`+record.Progress.Commit+`"}]}]`),nil
    }
    if _,err:=discover_build(context.Background(),"jotego/jtcores","",record.Root,Config{NoPublish:true});err!=ErrNoEligibleBuild{t.Fatalf("duplicate commit selected: %v",err)}
}

func TestCompactPartialManifestCannotCompleteCommit(t *testing.T) {
    record,manifest,cfg,hardware:=compact_fixture(t)
    if err:=RunCommit(context.Background(),record,manifest,cfg,hardware,false,false,true);err!=nil{t.Fatal(err)}
    if record.Progress.AutomaticComplete{t.Fatal("partial manifest marked full commit complete")}
    record.Progress.AutomaticComplete=true
    record.Progress.Games["fake/pending"]=ProgressGame{Result:Pending}
    record.Save()
    if _,err:=ReadProgress(record.Root,record.Progress.Commit);err==nil{t.Fatal("contradictory completion accepted")}
}

func TestCompactMigrationDoesNotRelabelChangedFixtures(t *testing.T) {
    root,source:=t.TempDir(),t.TempDir()
    archive:=filepath.Join(t.TempDir(),"archive")
    global:=filepath.Join(source,"reg.yaml");manualWrite(t,global,[]byte("video: 300\n"))
    cfg:=Config{Source:source,GlobalProfile:global}
    build:=BuildIdentity{SHA:strings.Repeat("d",40),RunID:"123",Attempt:"1"}
    game:=GameSpec{Setname:"game"}
    fingerprint,err:=gameSpecIdentity(&Batch{Core:"fake",CorePath:source,GlobalProfile:global,Build:build},game);if err!=nil{t.Fatal(err)}
    manifest:=Manifest{RunID:"123-attempt-1",Build:build,Cores:[]CoreManifest{{Core:"fake",Games:[]GameSpec{game}}}}
    dir:=filepath.Join(root,"log",manifest.RunID)
    manualWrite(t,filepath.Join(dir,"manifest.json"),mustJSON(t,manifest))
    manualWrite(t,filepath.Join(dir,"state","fake.json"),mustJSON(t,State{RunID:manifest.RunID,Build:build,Core:"fake",GameSpecIdentities:map[string]string{"game":fingerprint},Games:map[string]GameResult{"game":{Outcome:Error}}}))
    manualWrite(t,global,[]byte("video: 400\n"))
    if err=MigrateLogs(root,archive,cfg);err!=nil{t.Fatal(err)}
    progress,err:=ReadProgress(root,build.SHA);if err!=nil{t.Fatal(err)}
    if progress.Games["fake/game"].Result!=Pending||progress.Games["fake/game"].Input!=""{t.Fatal("old result relabelled with current inputs")}
}

func TestManualInterruptionAfterCompletedAutomaticRunStaysReadable(t *testing.T) {
    record,manifest,cfg,hardware:=compact_fixture(t)
    if err:=RunCommit(context.Background(),record,manifest,cfg,hardware,false,false);err!=nil{t.Fatal(err)}
    if !record.Progress.AutomaticComplete{t.Fatal("automatic run not complete")}
    ctx,cancel:=context.WithCancel(context.Background())
    second:=manifest.Cores[0].Games[0];second.Setname="second"
    manifest.Cores[0].Games=append(manifest.Cores[0].Games,second)
    interrupted:=&cancel_compact_hardware{qualityHardware:hardware,cancel:cancel}
    if err:=RunCommit(ctx,record,manifest,cfg,interrupted,true,false);err==nil{t.Fatal("expected interruption")}
    progress,err:=ReadProgress(record.Root,record.Progress.Commit);if err!=nil{t.Fatal(err)}
    if progress.AutomaticComplete||progress.Games["fake/second"].Result!=Pending{t.Fatalf("invalid interrupted manual progress: %+v",progress)}
}
