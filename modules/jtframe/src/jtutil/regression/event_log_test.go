/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */
package regression

import (
    "bytes"
    "encoding/json"
    "os"
    "path/filepath"
    "testing"
)

func event_writer_fixture(t *testing.T)(*EventLog,string){
    t.Helper();log,err:=NewEventLog(t.TempDir(),"run","core");if err!=nil{t.Fatal(err)}
    t.Cleanup(func(){_ = log.Close()})
    for _,stage:=range []string{"first","second"}{if err=log.Write(Event{Stage:stage});err!=nil{t.Fatal(err)}}
    return log,filepath.Join(log.Dir,"events.jsonl")
}
func assert_event_history(t *testing.T,path string,want ...string){
    t.Helper();data,err:=os.ReadFile(path);if err!=nil{t.Fatal(err)}
    lines:=bytes.Split(bytes.TrimSpace(data),[]byte{'\n'})
    if len(lines)!=len(want){t.Fatalf("journal event count got%d want%d",len(lines),len(want))}
    for i,line:=range lines{var event Event;if err=json.Unmarshal(line,&event);err!=nil||event.Stage!=want[i]{t.Fatalf("journal history changed at%d: %+v %v",i,event,err)}}
}

func TestEventLogRestoresAllHistoryAfterRemoteInodeReplacement(t *testing.T){
    log,path:=event_writer_fixture(t)
    complete,err:=os.ReadFile(path);if err!=nil{t.Fatal(err)}
    first:=append(bytes.SplitAfter(complete,[]byte{'\n'})[0][:0:0],bytes.SplitAfter(complete,[]byte{'\n'})[0]...)
    replacement:=filepath.Join(log.Dir,"remote-owner-reset.tmp")
    if err=os.WriteFile(replacement,first,0644);err!=nil{t.Fatal(err)}
    if os.Geteuid()==0{if err=os.Chown(replacement,1026,100);err!=nil{t.Fatal(err)}}
    if err=os.Chmod(replacement,0444);err!=nil{t.Fatal(err)}
    if err=os.Rename(replacement,path);err!=nil{t.Fatal(err)}
    if err=log.Write(Event{Stage:"third"});err!=nil{t.Fatal(err)}
    assert_event_history(t,path,"first","second","third")
    got,err:=os.ReadFile(path);if err!=nil||!bytes.HasPrefix(got,complete){t.Fatal("cached full prefix was lost")}
    leftovers,_:=filepath.Glob(filepath.Join(log.Dir,".*.recovery-*"));if len(leftovers)!=0{t.Fatalf("temporary repair artifacts remain: %v",leftovers)}
}

func TestEventLogRepairsENOENTFromCachedFullHistory(t *testing.T){
    log,path:=event_writer_fixture(t)
    if err:=os.Remove(path);err!=nil{t.Fatal(err)}
    if err:=log.Write(Event{Stage:"third"});err!=nil{t.Fatal(err)}
    assert_event_history(t,path,"first","second","third")
}

func TestEventLogNormalAppendKeepsSameInode(t *testing.T){
    log,path:=event_writer_fixture(t)
    before,err:=os.Stat(path);if err!=nil{t.Fatal(err)}
    if err=log.Write(Event{Stage:"third"});err!=nil{t.Fatal(err)}
    after,err:=os.Stat(path);if err!=nil||!os.SameFile(before,after){t.Fatal("normal append rewrote whole journal")}
    assert_event_history(t,path,"first","second","third")
}

func TestEventLogMissingRunDirectoryFailsWithoutRecreation(t *testing.T){
    log,_:=event_writer_fixture(t)
    if err:=os.RemoveAll(log.Dir);err!=nil{t.Fatal(err)}
    if err:=log.Write(Event{Stage:"third"});err==nil{t.Fatal("missing run directory accepted")}
    if _,err:=os.Stat(log.Dir);!os.IsNotExist(err){t.Fatal("writer recreated vanished run directory")}
}

func TestEventLogReplacedRunDirectoryFailsClosed(t *testing.T){
    log,path:=event_writer_fixture(t)
    backup:=log.Dir+"-original"
    if err:=os.Rename(log.Dir,backup);err!=nil{t.Fatal(err)}
    if err:=os.Mkdir(log.Dir,0750);err!=nil{t.Fatal(err)}
    sentinel:=[]byte("external directory must remain untouched\n")
    if err:=os.WriteFile(path,sentinel,0644);err!=nil{t.Fatal(err)}
    if err:=log.Write(Event{Stage:"third"});err==nil{t.Fatal("different run directory identity accepted")}
    got,err:=os.ReadFile(path);if err!=nil||!bytes.Equal(got,sentinel){t.Fatal("replacement directory was modified")}
    assert_event_history(t,filepath.Join(backup,"events.jsonl"),"first","second")
}

func TestEventLogPreservesValidExternalAppend(t *testing.T){
    log,path:=event_writer_fixture(t)
    file,err:=os.OpenFile(path,os.O_APPEND|os.O_WRONLY,0);if err!=nil{t.Fatal(err)}
    if err=json.NewEncoder(file).Encode(Event{Stage:"external"});err!=nil{t.Fatal(err)};_ = file.Close()
    if err=log.Write(Event{Stage:"third"});err!=nil{t.Fatal(err)}
    assert_event_history(t,path,"first","second","external","third")
}

func TestEventLogRefusesToOverwriteDivergentExternalHistory(t *testing.T){
    log,path:=event_writer_fixture(t)
    external:=[]byte("{\"stage\":\"different-history\"}\n")
    if err:=os.WriteFile(path,external,0644);err!=nil{t.Fatal(err)}
    if err:=log.Write(Event{Stage:"third"});err==nil{t.Fatal("divergent history was overwritten")}
    got,err:=os.ReadFile(path);if err!=nil||!bytes.Equal(got,external){t.Fatal("divergent history lost")}
}

func TestEventLogRepairGuardPreservesLateConcurrentDivergence(t *testing.T){
    log,path:=event_writer_fixture(t)
    if err:=os.Remove(path);err!=nil{t.Fatal(err)}
    external:=[]byte("{\"stage\":\"concurrent-history\"}\n")
    log.before_repair_check=func(){if err:=os.WriteFile(path,external,0644);err!=nil{t.Fatal(err)}}
    if err:=log.Write(Event{Stage:"third"});err==nil{t.Fatal("repair overwrote a late divergent replacement")}
    got,err:=os.ReadFile(path);if err!=nil||!bytes.Equal(got,external){t.Fatal("late concurrent history was lost")}
    leftovers,_:=filepath.Glob(filepath.Join(log.Dir,".*.recovery-*"));if len(leftovers)!=0{t.Fatal("failed repair leaked temporary files")}
}

func TestEventLogRepairsAppendPermissionFailure(t *testing.T){
    log,path:=event_writer_fixture(t)
    _ = log.file.Close()
    readonly,err:=os.Open(path);if err!=nil{t.Fatal(err)}
    log.file=readonly
    if err=log.Write(Event{Stage:"third"});err!=nil{t.Fatal(err)}
    assert_event_history(t,path,"first","second","third")
}

func TestResumeAnchoredOpenRejectsEmptyReplacement(t *testing.T){
    log,path:=event_writer_fixture(t)
    if err:=os.Truncate(path,0);err!=nil{t.Fatal(err)}
    if opened,err:=open_event_log(log.Dir,log.RunID,log.Core,os.O_APPEND|os.O_WRONLY);err==nil{_ = opened.Close();t.Fatal("empty resume journal seeded a new cache")}
}

func TestEventLogRetainsVerifiedCacheAcrossCoreBoundary(t *testing.T){
    log,path:=event_writer_fixture(t)
    history,err:=os.ReadFile(path);if err!=nil{t.Fatal(err)}
    log.SetCore("next-core")
    first:=bytes.SplitAfter(history,[]byte{'\n'})[0]
    replacement:=filepath.Join(log.Dir,"old-core-snapshot.tmp")
    if err=os.WriteFile(replacement,first,0644);err!=nil{t.Fatal(err)}
    if err=os.Rename(replacement,path);err!=nil{t.Fatal(err)}
    if err=log.Write(Event{Stage:"next-core-load"});err!=nil{t.Fatal(err)}
    assert_event_history(t,path,"first","second","next-core-load")
    data,err:=os.ReadFile(path);if err!=nil||!bytes.HasPrefix(data,history){t.Fatal("core boundary lost prior verified bytes")}
    lines:=bytes.Split(bytes.TrimSpace(data),[]byte{'\n'});var event Event
    if err=json.Unmarshal(lines[2],&event);err!=nil||event.Core!="next-core"{t.Fatal("new core event used wrong default core")}
}
