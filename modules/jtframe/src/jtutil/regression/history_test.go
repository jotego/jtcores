/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */
package regression

import (
    "context"
    "os"
    "path/filepath"
    "strings"
    "testing"
    "time"
)

func TestReferenceCRCTracksContentAndNames(t *testing.T) {
    root:=t.TempDir();first:=filepath.Join(root,"first");second:=filepath.Join(root,"second")
    missing,err:=reference_crc(first);if err!=nil||missing!="--------"{t.Fatal(missing,err)}
    os.MkdirAll(first,0750)
    empty,err:=reference_crc(first);if err!=nil||empty!="00000000"{t.Fatal(empty,err)}
    manualWrite(t,filepath.Join(first,"b.png"),[]byte("second"))
    manualWrite(t,filepath.Join(first,"sub","a.png"),[]byte("first"))
    manualWrite(t,filepath.Join(second,"sub","a.png"),[]byte("first"))
    manualWrite(t,filepath.Join(second,"b.png"),[]byte("second"))
    original,err:=reference_crc(first);if err!=nil{t.Fatal(err)}
    same,err:=reference_crc(second);if err!=nil||same!=original{t.Fatal("creation order changed CRC",same,original,err)}
    past:=time.Unix(100,0);os.Chtimes(filepath.Join(first,"b.png"),past,past)
    same,err=reference_crc(first);if err!=nil||same!=original{t.Fatal("mtime changed CRC",same,original,err)}
    manualWrite(t,filepath.Join(first,"b.png"),[]byte("SECOND"))
    changed,err:=reference_crc(first);if err!=nil||changed==original{t.Fatal("content change missed",err)}
    os.Rename(filepath.Join(second,"b.png"),filepath.Join(second,"c.png"))
    renamed,err:=reference_crc(second);if err!=nil||renamed==original{t.Fatal("rename missed",err)}
    if err=os.Symlink(filepath.Join(first,"b.png"),filepath.Join(second,"link"));err!=nil{t.Fatal(err)}
    if _,err=reference_crc(second);err==nil{t.Fatal("symlink followed outside reference contents")}
}

func TestGameHistoryAppendsChecksAndSkipsResumedGames(t *testing.T) {
    record,manifest,cfg,hardware:=compact_fixture(t)
    ctx:=context.Background()
    run:=func(manual bool){t.Helper();if err:=RunCommit(ctx,record,manifest,cfg,hardware,manual,false);err!=nil{t.Fatal(err)}}
    dir:=filepath.Join(record.Root,"fake","quality")
    lines:=func()[]string{t.Helper();data,err:=os.ReadFile(filepath.Join(dir,"log"));if err!=nil{t.Fatal(err)};return strings.Split(strings.TrimSuffix(string(data),"\n"),"\n")}
    run(false)
    first:=lines()
    if len(first)!=1||len(first[0])!=54||first[0][10]!=' '||first[0][19]!=' '||first[0][33]!=' '||first[0][45]!=' '{t.Fatalf("wrong history columns: %q",first)}
    if strings.TrimSpace(first[0][20:33])!="aaaaaaa"||strings.TrimSpace(first[0][34:45])!="NEW"||first[0][46:]!="--------"{t.Fatalf("wrong first check: %q",first)}
    record.Close()
    reopened,err:=OpenCommitLog(record.Root,record.Progress.Commit);if err!=nil{t.Fatal(err)};defer reopened.Close();record=reopened
    run(false)
    if len(lines())!=1{t.Fatal("resume duplicated check history")}
    if err=os.Rename(filepath.Join(dir,"new"),filepath.Join(dir,"ref"));err!=nil{t.Fatal(err)}
    baseline,err:=reference_crc(filepath.Join(dir,"ref"));if err!=nil{t.Fatal(err)}
    run(true)
    after:=lines()
    if len(after)!=2||after[0]!=first[0]||strings.TrimSpace(after[1][34:45])!="PASS"||after[1][46:]!=baseline{t.Fatalf("reference approval not recorded: %q",after)}
    replacement:=make_capture_fixture(t,[]uint16{1,9,3})
    if err=export_png_frames(replacement,filepath.Join(dir,"ref"));err!=nil{t.Fatal(err)}
    run(true)
    after=lines()
    if len(after)!=3||strings.TrimSpace(after[2][34:45])!="FAIL"||after[2][46:]==baseline{t.Fatalf("changed reference not recorded: %q",after)}
    dirty,err:=OpenCommitLog(record.Root,record.Progress.Commit,true);if err!=nil{t.Fatal(err)};defer dirty.Close();record=dirty
    run(true)
    after=lines()
    if len(after)!=4||after[3][20:33]!="aaaaaaa-dirty"{t.Fatalf("dirty identity not retained: %q",after)}
    next,err:=OpenCommitLog(record.Root,strings.Repeat("b",40));if err!=nil{t.Fatal(err)};defer next.Close();record=next
    manifest.Build.SHA=record.Progress.Commit
    run(false)
    after=lines()
    if len(after)!=5||strings.TrimSpace(after[4][20:33])!="bbbbbbb"||after[0]!=first[0]{t.Fatalf("next commit replaced history: %q",after)}
}

func TestGameHistoryIncludesTerminalErrorsAndExclusions(t *testing.T) {
    record,manifest,cfg,hardware:=compact_fixture(t)
    broken:=manifest.Cores[0].Games[0];broken.Setname="broken";broken.PreparationError="missing ROM"
    excluded:=broken;excluded.Setname="excluded";excluded.Unsupported=true
    manifest.Cores[0].Games=[]GameSpec{broken,excluded}
    if err:=RunCommit(context.Background(),record,manifest,cfg,hardware,false,false);err!=nil{t.Fatal(err)}
    for set,verdict:=range map[string]string{"broken":"ERROR","excluded":"UNSUPPORTED"}{
        data,err:=os.ReadFile(filepath.Join(record.Root,"fake",set,"log"));if err!=nil{t.Fatal(err)}
        if strings.TrimSpace(string(data[34:45]))!=verdict||string(data[46:54])!="--------"{t.Fatalf("wrong terminal history: %s",data)}
    }
    if hardware.loads!=0{t.Fatal("invalid game reached the board")}
}

func TestHistoryWriteFailureLeavesCheckPending(t *testing.T) {
    record,manifest,cfg,hardware:=compact_fixture(t)
    dir:=filepath.Join(record.Root,"fake","quality","log")
    if err:=os.MkdirAll(dir,0750);err!=nil{t.Fatal(err)}
    if err:=RunCommit(context.Background(),record,manifest,cfg,hardware,false,false);err==nil{t.Fatal("history write failure ignored")}
    saved,err:=ReadProgress(record.Root,record.Progress.Commit);if err!=nil{t.Fatal(err)}
    if saved.Games["fake/quality"].Result!=Pending||saved.AutomaticComplete{t.Fatal("check completed without its history")}
}
