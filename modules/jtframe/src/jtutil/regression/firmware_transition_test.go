/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */
package regression

import (
    "encoding/json"
    "os"
    "path/filepath"
    "strings"
    "testing"
)

func firmware_transition_test_batch(t *testing.T) (*Batch,FirmwareTransition,map[string]string) {
    t.Helper()
    root:=t.TempDir()
    old:=GameSpec{Setname:"old",ARC:filepath.Join(root,"old.arc")}
    pending:=GameSpec{Setname:"pending",ARC:filepath.Join(root,"pending.arc")}
    for _,path:=range []string{old.ARC,pending.ARC} {if err:=os.WriteFile(path,[]byte("unchanged ARC"),0600);err!=nil {t.Fatal(err)}}
    batch:=makeBatch(t,root,&retryHardware{},[]GameSpec{old,pending})
    batch.Firmware="ATH261028";batch.FirmwareSHA256=strings.Repeat("a",64);batch.CaptureToolSHA256=strings.Repeat("c",64)
    if err:=os.WriteFile(batch.GlobalProfile,[]byte("video: 200\nstart-up: 0\n"),0600);err!=nil {t.Fatal(err)}
    profile,err:=resolvedGameProfile(batch,old);if err!=nil {t.Fatal(err)}
    definition,fixtures,cab,source_cab,err:=currentReceiptDefinition(batch,old,profile,"rgb555");if err!=nil {t.Fatal(err)}
    metadata:=GameMetadata{Build:batch.Build,TestIdentity:definition,Profile:profile,FixtureHashes:fixtures,CABSHA256:cab,CABSourceSHA256:source_cab,CABClipMode:"prefix",CABFrameBudget:profile.Video,Firmware:batch.Firmware,FirmwareSHA256:batch.FirmwareSHA256,CaptureToolSHA256:batch.CaptureToolSHA256,CaptureFormat:"rgb555",Frames:profile.Video,Cadence:100,Startup:profile.Startup}
    capture:=make_capture_fixture(t,[]uint16{1,2})
    seed_receipt(t,batch,old.Setname,capture,metadata)
    if err=PublishComplete(filepath.Join(batch.Root,batch.Core,old.Setname),capture,New,nil);err!=nil {t.Fatal(err)}
    batch.State.TestIdentity,err=batchIdentity(batch);if err!=nil {t.Fatal(err)}
    batch.State.GameSpecIdentities=map[string]string{}
    for _,game:=range batch.Games {identity,e:=gameSpecIdentity(batch,game);if e!=nil {t.Fatal(e)};batch.State.GameSpecIdentities[game.Setname]=identity}
    batch.State.Games=map[string]GameResult{old.Setname:{Core:batch.Core,Setname:old.Setname,Outcome:New,TestIdentity:definition},pending.Setname:{Core:batch.Core,Setname:pending.Setname,Outcome:Pending}}
    transition:=FirmwareTransition{Schema:1,RunID:batch.RunID,Build:batch.Build,From:FirmwarePair{Firmware:batch.Firmware,SHA256:batch.FirmwareSHA256},To:FirmwarePair{Firmware:"ATH261029",SHA256:strings.Repeat("b",64)}}
    unchanged:=map[string]string{}
    for _,dir:=range []string{batch.capture_receipt(old.Setname),filepath.Join(batch.Root,batch.Core,old.Setname,"new")} {
        entries,e:=os.ReadDir(dir);if e!=nil {t.Fatal(e)}
        for _,entry:=range entries {path:=filepath.Join(dir,entry.Name());unchanged[path],e=FileSHA256(path);if e!=nil {t.Fatal(e)}}
    }
    batch.Firmware=transition.To.Firmware;batch.FirmwareSHA256=transition.To.SHA256;batch.RetryErrors=true
    write_test_firmware_transition(t,batch,transition)
    return batch,transition,unchanged
}

func write_test_firmware_transition(t *testing.T,batch *Batch,transition FirmwareTransition) {
    t.Helper();data,err:=json.Marshal(transition);if err!=nil {t.Fatal(err)}
    if err=atomic_write(filepath.Join(batch.Root,"log",batch.RunID,"firmware-transition.json"),data,0600);err!=nil {t.Fatal(err)}
}

func assert_historical_capture_unchanged(t *testing.T,batch *Batch,files map[string]string) {
    t.Helper()
    for path,want:=range files {got,err:=FileSHA256(path);if err!=nil || got!=want {t.Fatalf("historical capture changed: %s %v",path,err)}}
    if _,err:=os.Stat(filepath.Join(batch.Root,batch.Core,"old","ref"));!os.IsNotExist(err) {t.Fatal("transition created a reference")}
}

func TestFirmwareTransitionPreservesOldNewAndRefreshesPending(t *testing.T) {
    batch,_,unchanged:=firmware_transition_test_batch(t)
    old_identity:=batch.State.GameSpecIdentities["old"]
    new_identity,err:=gameSpecIdentity(batch,batch.Games[1]);if err!=nil {t.Fatal(err)}
    if err=batch.Run();err!=nil {t.Fatal(err)}
    hardware:=batch.Hardware.(*retryHardware)
    if len(hardware.loaded)!=1 || hardware.loaded[0]!="pending" {t.Fatalf("historical game reran: %v",hardware.loaded)}
    if batch.State.GameSpecIdentities["old"]!=old_identity || batch.State.GameSpecIdentities["pending"]!=new_identity {t.Fatal("mixed per-game identities were not preserved")}
    aggregate,err:=batchIdentity(batch);if err!=nil || batch.State.TestIdentity!=aggregate {t.Fatal("aggregate did not advance to current firmware")}
    assert_historical_capture_unchanged(t,batch,unchanged)
}

func TestFirmwareTransitionRejectsChangedHistoricalFixture(t *testing.T) {
    batch,_,unchanged:=firmware_transition_test_batch(t)
    if err:=os.WriteFile(batch.Games[0].ARC,[]byte("changed fixture"),0600);err!=nil {t.Fatal(err)}
    if err:=batch.Run();err==nil || !strings.Contains(err.Error(),"cannot prove historical") {t.Fatalf("changed historical fixture accepted: %v",err)}
    if len(batch.Hardware.(*retryHardware).loaded)!=0 {t.Fatal("board used before historical proof")}
    assert_historical_capture_unchanged(t,batch,unchanged)
}

func TestFirmwareTransitionRejectsWrongAuthorization(t *testing.T) {
    for _,field:=range []string{"run","build","from","to","schema","tool"} {t.Run(field,func(t *testing.T){
        batch,transition,_:=firmware_transition_test_batch(t)
        switch field {case "run":transition.RunID="other";case "build":transition.Build.SHA="other";case "from":transition.From.SHA256=strings.Repeat("d",64);case "to":transition.To.SHA256=strings.Repeat("d",64);case "schema":transition.Schema=0;case "tool":batch.CaptureToolSHA256=strings.Repeat("d",64)}
        write_test_firmware_transition(t,batch,transition)
        if err:=batch.Run();err==nil {t.Fatalf("wrong %s transition accepted",field)}
        if len(batch.Hardware.(*retryHardware).loaded)!=0 {t.Fatal("board used with unproven transition")}
    })}
}

func TestFirmwareTransitionResumeAfterSecondInterruption(t *testing.T) {
    batch,_,unchanged:=firmware_transition_test_batch(t)
    batch.Hardware=&fakeHardware{failLoad:true,unavailable:true}
    if err:=batch.Run();err==nil || !strings.Contains(err.Error(),"board outage") {t.Fatalf("expected interrupted pending game: %v",err)}
    saved,err:=ReadState(batch.StatePath);if err!=nil {t.Fatal(err)}
    if saved.Games["old"].Outcome!=New || saved.Games["pending"].Outcome!=Pending {t.Fatal("interruption lost historical or pending outcome")}
    batch.State=saved;batch.Hardware=&retryHardware{}
    if err=batch.Run();err!=nil {t.Fatal(err)}
    if loaded:=batch.Hardware.(*retryHardware).loaded;len(loaded)!=1 || loaded[0]!="pending" {t.Fatalf("resume reran historical game: %v",loaded)}
    assert_historical_capture_unchanged(t,batch,unchanged)
}

func TestFirmwareChangeWithoutTransitionStillFailsClosed(t *testing.T) {
    batch,_,_:=firmware_transition_test_batch(t)
    if err:=os.Remove(filepath.Join(batch.Root,"log",batch.RunID,"firmware-transition.json"));err!=nil {t.Fatal(err)}
    if err:=batch.Run();err==nil {t.Fatal("firmware check was globally waived")}
    if len(batch.Hardware.(*retryHardware).loaded)!=0 {t.Fatal("board used without transition")}
}

func TestFirmwareTransitionUnsupportedRowsNeedUnchangedOldDefinition(t *testing.T) {
    for _,changed:=range []bool{false,true} {t.Run(jsonNumber(bool_test_int(changed)),func(t *testing.T){
        batch,transition,_:=firmware_transition_test_batch(t)
        batch.Games[0].Unsupported=true;batch.Games[0].UnsupportedReason="target excluded"
        historical:=batch.historical_firmware_batch(&transition)
        identity,err:=gameSpecIdentity(historical,batch.Games[0]);if err!=nil {t.Fatal(err)}
        batch.State.GameSpecIdentities["old"]=identity
        batch.State.Games["old"]=GameResult{Core:batch.Core,Setname:"old",Outcome:Unsupported,Stage:"inventory",Message:"target excluded"}
        if changed {batch.Games[0].UnsupportedReason="different exclusion"}
        err=batch.Run()
        if changed && err==nil {t.Fatal("changed unsupported definition accepted")}
        if !changed && err!=nil {t.Fatal(err)}
    })}
}
func bool_test_int(value bool)int {if value {return 1};return 0}
