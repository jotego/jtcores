/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */
package regression

import (
    "context"
    "encoding/json"
    "errors"
    "fmt"
    "os"
    "path/filepath"
    "strings"
    "testing"
)

func TestPollCutoffAndSuccessfulRetry(t *testing.T) {
    original := ghCommand
    defer func(){ ghCommand=original }()
    successful := false
    sha := strings.Repeat("a",40)
    ghCommand = func(_ context.Context, args ...string)([]byte,error) {
        joined := strings.Join(args," ")
        if strings.Contains(joined,"workflows/compile-sidi128.yaml/runs") { return []byte(`[{"workflow_runs":[]}]`),nil }
        switch {
        case strings.Contains(joined,"workflows/compile-all.yaml/runs"):
            conclusion := "failure"
            if successful { conclusion="success" }
            return []byte(fmt.Sprintf(`[{"workflow_runs":[
                {"id":1,"name":"Compile all","status":"completed","conclusion":"success","head_sha":"%s","run_attempt":1,"created_at":"2026-10-01T00:00:00Z"},
                {"id":2,"name":"Compile all","status":"completed","conclusion":"%s","head_sha":"%s","run_attempt":2,"created_at":"2026-10-30T00:00:00Z"}]}]`,sha,conclusion,sha)),nil
        case strings.HasPrefix(joined,"run view 2 "):
            return []byte(fmt.Sprintf(`{"databaseId":2,"workflowName":"Compile all","status":"completed","conclusion":"success","headSha":"%s","headBranch":"master","event":"push","attempt":2,"jobs":[{"status":"completed","conclusion":"success"}]}`,sha)),nil
        case strings.Contains(joined,"runs/2/artifacts"):
            return []byte(`{"artifacts":[{"id":22,"name":"aaaaaaa.zip","digest":"sha256:abc"}]}`),nil
        case strings.Contains(joined,"runs/2"):
            return []byte(`{"pull_requests":[]}`),nil
        default: t.Fatalf("unexpected command (old build must not be inspected): %s",joined);return nil,nil
        }
    }
    cfg := Config{BuildsSince:"2026-10-30T00:00:00Z"}
    if _,err:=discover_build(context.Background(),"jotego/jtcores","",t.TempDir(),cfg); !errors.Is(err,ErrNoEligibleBuild) { t.Fatalf("failed attempt: %v",err) }
    successful=true
    build,err:=discover_build(context.Background(),"jotego/jtcores","",t.TempDir(),cfg)
    if err!=nil || build.RunID!="2" || build.Attempt!="2" { t.Fatalf("retry not reconsidered: %+v %v",build,err) }
    cfg.BuildsSince="bad timestamp"
    if _,err=discover_build(context.Background(),"jotego/jtcores","",t.TempDir(),cfg);err==nil { t.Fatal("invalid cutoff accepted") }
}

func TestPollLocalCompletionAndPartialPilots(t *testing.T) {
    root:=t.TempDir()
    summary:=Summary{RunID:"406-attempt-1",Build:BuildIdentity{RunID:"406",Attempt:"1"},Status:"publication-pending",Games:[]GameResult{{Setname:"game",Outcome:Fail}}}
    write:=func(folder string) {
        dir:=filepath.Join(root,"log",folder)
        if err:=os.MkdirAll(dir,0750);err!=nil{t.Fatal(err)}
        data,_:=json.Marshal(summary)
        if err:=os.WriteFile(filepath.Join(dir,"summary.json"),data,0600);err!=nil{t.Fatal(err)}
    }
    write("pilot")
    if buildAlreadyComplete(root,"406","1",true) { t.Fatal("pilot suppressed a full campaign") }
    write(summary.RunID)
    if !buildAlreadyComplete(root,"406","1",true) { t.Fatal("completed local hardware campaign selected again") }
    if buildAlreadyComplete(root,"406","1") { t.Fatal("publication retry suppressed") }
    if buildAlreadyComplete(root,"406","2",true) { t.Fatal("new build attempt suppressed") }
    summary.Games[0].Outcome=Pending;write(summary.RunID)
    if buildAlreadyComplete(root,"406","1",true) { t.Fatal("pending games suppressed") }
    summary.Games[0].Outcome=Pass;summary.Status="interrupted";write(summary.RunID)
    if buildAlreadyComplete(root,"406","1",true) { t.Fatal("interrupted campaign suppressed") }
}

func TestPollBoardLock(t *testing.T) {
    root:=t.TempDir()
    first,err:=AcquireLock(root)
    if err!=nil{t.Fatal(err)}
    defer ReleaseLock(first)
    second,err:=AcquireLock(root)
    if second!=nil{ReleaseLock(second)}
    if !errors.Is(err,ErrBoardBusy){t.Fatalf("concurrent acquisition: %v",err)}
}
