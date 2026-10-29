/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */
package regression

import (
    "encoding/json"
    "os"
    "path/filepath"
    "strings"
    "testing"
    "time"
)

func journal_recovery_batch(t *testing.T)(*Batch,GameSpec,GameResult){
    t.Helper();batch,game,result:=receipt_test_batch(t,0)
    capture:=make_capture_fixture(t,[]uint16{1,2,3})
    seed_receipt(t,batch,game.Setname,capture,GameMetadata{Build:batch.Build,TestIdentity:result.TestIdentity})
    publish_test_new(t,batch,game,capture)
    result.Core=batch.Core;result.Setname=game.Setname;result.Stage="reference";result.Message="no approved reference";result.Attention=true
    result.Started=time.Date(2026,10,29,12,0,0,0,time.UTC);result.Finished=result.Started.Add(3*time.Second);result.Duration=3*time.Second
    result.RecordError="sync "+filepath.Join(batch.Log.Dir,"events.jsonl")+": no such file or directory"
    batch.State.Games=map[string]GameResult{game.Setname:result}
    identity,err:=gameSpecIdentity(batch,game);if err!=nil{t.Fatal(err)}
    batch.State.GameSpecIdentities=map[string]string{game.Setname:identity}
    batch.State.TestIdentity,err=batchIdentity(batch);if err!=nil{t.Fatal(err)}
    if err=WriteState(batch.StatePath,batch.State);err!=nil{t.Fatal(err)}
    return batch,game,result
}

func recovery_events(t *testing.T,batch *Batch)[]Event{
    t.Helper();data,err:=os.ReadFile(filepath.Join(batch.Log.Dir,"events.jsonl"));if err!=nil{t.Fatal(err)}
    var events []Event
    for _,line:=range strings.Split(strings.TrimSpace(string(data)),"\n"){if line==""{continue};var event Event;if err=json.Unmarshal([]byte(line),&event);err!=nil{t.Fatal(err)};events=append(events,event)}
    return events
}

func TestVerifiedFinalizedStateRepairsJournalWithoutRecapture(t *testing.T){
    batch,game,old:=journal_recovery_batch(t)
    files:=map[string]string{}
    for _,dir:=range []string{batch.capture_receipt(game.Setname),filepath.Join(batch.Root,batch.Core,game.Setname,"new")}{entries,err:=os.ReadDir(dir);if err!=nil{t.Fatal(err)};for _,entry:=range entries{if !entry.IsDir(){path:=filepath.Join(dir,entry.Name());files[path],err=FileSHA256(path);if err!=nil{t.Fatal(err)}}}}
    if err:=batch.Run();err!=nil{t.Fatal(err)}
    want:=old;want.RecordError=""
    if !sameJSONValue(batch.State.Games[game.Setname],want){t.Fatal("recovery changed capture outcome, attention, or timestamps")}
    state,err:=ReadState(batch.StatePath);if err!=nil||!sameJSONValue(state.Games[game.Setname],want){t.Fatal("cleared error not durably persisted")}
    events:=recovery_events(t,batch)
    if len(events)!=1||events[0].Stage!="state-recovered"||events[0].Outcome!=New{t.Fatalf("invented or missing recovery events: %+v",events)}
    fields:=events[0].Fields.(map[string]any)
    if fields["original_record_error"]!=old.RecordError||fields["test_identity"]!=old.TestIdentity||fields["original_stage"]!=old.Stage{t.Fatal("original error/identity not recorded")}
    if len(batch.Hardware.(*retryHardware).loaded)!=0{t.Fatal("verified capture reran")}
    for path,want:=range files{got,e:=FileSHA256(path);if e!=nil||got!=want{t.Fatalf("image or receipt changed: %s",path)}}
}

func TestTamperedCaptureCannotClearJournalError(t *testing.T){
    for _,kind:=range []string{"published","receipt"}{t.Run(kind,func(t *testing.T){
        batch,game,old:=journal_recovery_batch(t)
        if kind=="published"{publish_test_new(t,batch,game,make_capture_fixture(t,[]uint16{4,5,6}))}else{if err:=os.WriteFile(filepath.Join(batch.capture_receipt(game.Setname),"frames.json"),[]byte(`{"schema":0}`),0600);err!=nil{t.Fatal(err)}}
        if err:=batch.Run();err==nil||!strings.Contains(err.Error(),"unverified finalized"){t.Fatalf("tampered capture recovered: %v",err)}
        if batch.State.Games[game.Setname].RecordError!=old.RecordError{t.Fatal("tampered capture lost journal error")}
        if len(recovery_events(t,batch))!=0||len(batch.Hardware.(*retryHardware).loaded)!=0{t.Fatal("unverified recovery wrote event or ran hardware")}
    })}
}

func TestRecoveryAppendFailureKeepsRecordError(t *testing.T){
    batch,game,old:=journal_recovery_batch(t)
    _ = batch.Log.Close()
    if err:=batch.Run();err==nil||!strings.Contains(err.Error(),"append state recovery"){t.Fatalf("append failure hidden: %v",err)}
    state,err:=ReadState(batch.StatePath)
    if err!=nil||state.Games[game.Setname].RecordError!=old.RecordError||batch.State.Games[game.Setname].RecordError!=old.RecordError{t.Fatal("failed append cleared error")}
}

func TestRecoveryEventIsIdempotentAfterStateWriteFailure(t *testing.T){
    batch,game,old:=journal_recovery_batch(t)
    if !batch.verifyFinalized(game,old){t.Fatal("fixture not verified")}
    valid_path:=batch.StatePath;batch.StatePath=t.TempDir()
    if err:=batch.recover_record_error(game,old);err==nil||!strings.Contains(err.Error(),"persist recovered state"){t.Fatalf("expected state write failure: %v",err)}
    if batch.State.Games[game.Setname].RecordError!=old.RecordError||len(recovery_events(t,batch))!=1{t.Fatal("failed state write lost recovery evidence")}
    batch.StatePath=valid_path
    if err:=batch.Run();err!=nil{t.Fatal(err)}
    if len(recovery_events(t,batch))!=1||batch.State.Games[game.Setname].RecordError!=""{t.Fatal("resume duplicated recovery event or failed to clear state")}
}

func TestResumeJournalDoesNotCreateMissingMountedPaths(t *testing.T){
    for _,kind:=range []string{"run","state","journal","empty","anchor"}{t.Run(kind,func(t *testing.T){
        root:=t.TempDir();build:=BuildIdentity{RunID:"run",SHA:"build"};run:="run-attempt-1"
        log,err:=NewEventLog(root,run,"core");if err!=nil{t.Fatal(err)}
        if err=log.Write(Event{Stage:"load"});err!=nil{t.Fatal(err)};_ = log.Close()
        dir:=filepath.Join(root,"log",run)
        if err=os.Mkdir(filepath.Join(dir,"state"),0750);err!=nil{t.Fatal(err)}
        manifest:=Manifest{RunID:run,Build:build};data,_:=json.Marshal(manifest)
        if err=os.WriteFile(filepath.Join(dir,"manifest.json"),data,0600);err!=nil{t.Fatal(err)}
        missing:=""
        switch kind{
        case "run":missing=dir;err=os.RemoveAll(dir)
        case "state":missing=filepath.Join(dir,"state");err=os.Remove(missing)
        case "journal":missing=filepath.Join(dir,"events.jsonl");err=os.Remove(missing)
        case "empty":err=os.Truncate(filepath.Join(dir,"events.jsonl"),0)
        case "anchor":build.SHA="wrong"
        }
        if err!=nil{t.Fatal(err)}
        if opened,e:=NewEventLog(root,run,"core",build);e==nil{_ = opened.Close();t.Fatal("invalid resume journal opened")}
        if missing!=""{if _,e:=os.Stat(missing);!os.IsNotExist(e){t.Fatal("resume recreated a missing mounted path")}}
    })}
}

func TestRecoveryAfterAppendDoesNotRecreateMissingStateDirectory(t *testing.T){
    batch,game,old:=journal_recovery_batch(t)
    state_dir:=filepath.Join(filepath.Dir(batch.StatePath),"existing-state")
    if err:=os.Mkdir(state_dir,0750);err!=nil{t.Fatal(err)}
    batch.StatePath=filepath.Join(state_dir,"core.json")
    if err:=WriteState(batch.StatePath,batch.State);err!=nil{t.Fatal(err)}
    event:=Event{Setname:game.Setname,Stage:"state-recovered",Outcome:old.Outcome,Fields:map[string]any{"original_record_error":old.RecordError,"original_stage":old.Stage,"test_identity":old.TestIdentity,"outcome":old.Outcome}}
    if err:=batch.Log.Write(event);err!=nil{t.Fatal(err)}
    if err:=os.RemoveAll(state_dir);err!=nil{t.Fatal(err)}
    if err:=batch.recover_record_error(game,old);err==nil{t.Fatal("missing state directory accepted")}
    if _,err:=os.Stat(state_dir);!os.IsNotExist(err){t.Fatal("recovery recreated missing state directory")}
    if batch.State.Games[game.Setname].RecordError!=old.RecordError||len(recovery_events(t,batch))!=1{t.Fatal("missing state directory lost retryable error or duplicated event")}
}

func TestJournalRecoveryVerificationLeavesLegacyReceiptsUntouched(t *testing.T){
    batch,game,old:=journal_recovery_batch(t)
    capture:=make_capture_fixture(t,[]uint16{1,2,3})
    dir:=batch.capture_receipt(game.Setname)
    if err:=os.Remove(filepath.Join(dir,"frames.json"));err!=nil{t.Fatal(err)}
    if err:=export_png_frames(capture,dir);err!=nil{t.Fatal(err)}
    if err:=batch.Run();err!=nil{t.Fatal(err)}
    files,_:=filepath.Glob(filepath.Join(dir,"*.png"))
    if len(files)!=3{t.Fatal("recovery migrated or removed legacy receipt images")}
    if _,err:=os.Stat(filepath.Join(dir,"frames.json"));!os.IsNotExist(err){t.Fatal("recovery wrote a new receipt")}
    if batch.State.Games[game.Setname].RecordError!=""||old.RecordError==""{t.Fatal("legacy verified journal row did not recover")}
}

func TestResumeErrorWritersDoNotRecreateMissingDirectories(t *testing.T){
    root:=t.TempDir();missing:=filepath.Join(root,"vanished")
    if _,err:=AcquireLock(missing,true);err==nil{t.Fatal("resume lock recreated missing log root")}
    if err:=WriteSummary(missing,Summary{},true);err==nil{t.Fatal("resume summary recreated missing run")}
    if err:=WriteExistingFile(filepath.Join(missing,"state.json"),[]byte("state"),0640);err==nil{t.Fatal("anchored writer recreated missing state directory")}
    if _,err:=os.Stat(missing);!os.IsNotExist(err){t.Fatal("missing mounted directory was recreated")}
}

func TestCompositeRecordErrorIsNotClearedAsJournalRecovery(t *testing.T){
    batch,game,old:=journal_recovery_batch(t)
    old.RecordError+="; preserve helper diagnostics: unrelated failure"
    batch.State.Games[game.Setname]=old
    if err:=batch.Run();err==nil||!strings.Contains(err.Error(),"composite"){t.Fatalf("composite error was hidden: %v",err)}
    if batch.State.Games[game.Setname].RecordError!=old.RecordError||len(recovery_events(t,batch))!=0{t.Fatal("composite failure was cleared")}
}
