package regression

import (
    "context"
    "encoding/json"
    "fmt"
    "path/filepath"
    "strconv"
    "strings"
    "testing"
    "time"
)

// Fake only the GitHub API; exercise the real discovery and commit bookkeeping.
func mock_build_workflows(t *testing.T, runs []apiWorkflowRun) {
    t.Helper()
    previous:=ghCommand
    t.Cleanup(func(){ghCommand=previous})
    ghCommand=func(_ context.Context,args ...string)([]byte,error){
        joined:=strings.Join(args," ")
        if strings.Contains(joined,"/workflows/") {
            selected:=[]apiWorkflowRun{}
            for _, run:=range runs {
                if strings.Contains(joined,"/workflows/"+workflow_file(run.Name)+"/") {selected=append(selected,run)}
            }
            return json.Marshal([]map[string]any{{"workflow_runs":selected}})
        }
        for _, run:=range runs {
            id:=strconv.FormatInt(run.ID,10)
            if strings.HasPrefix(joined,"run view "+id+" ") {
                return json.Marshal(map[string]any{"databaseId":run.ID,"workflowName":run.Name,"number":run.RunNumber,"attempt":run.Attempt,"status":run.Status,"conclusion":run.Conclusion,"headSha":run.HeadSHA,"headBranch":"master","event":"workflow_dispatch","jobs":[]map[string]string{{"status":"completed","conclusion":"success"}}})
            }
            if strings.HasSuffix(joined,"/runs/"+id+"/artifacts") {
                name:=run.HeadSHA[:7]+".zip"
                if run.Name=="Compile SiDi128" {name=run.HeadSHA[:7]+"-sidi128.zip"}
                return json.Marshal(map[string]any{"artifacts":[]map[string]any{{"id":run.ID*10,"name":name,"digest":"sha256:feed"}}})
            }
            if strings.HasSuffix(joined,"/runs/"+id) {return []byte(`{"pull_requests":[]}`),nil}
        }
        return nil,fmt.Errorf("unexpected GitHub command: %s",joined)
    }
}

func dual_workflow_runs() []apiWorkflowRun {
    return []apiWorkflowRun{
        {ID:101,Name:"Compile all",RunNumber:7,Attempt:1,Status:"completed",Conclusion:"success",HeadSHA:strings.Repeat("a",40),CreatedAt:time.Date(2026,11,1,0,0,0,0,time.UTC)},
        {ID:202,Name:"Compile SiDi128",RunNumber:8,Attempt:1,Status:"completed",Conclusion:"success",HeadSHA:strings.Repeat("b",40),CreatedAt:time.Date(2026,11,2,0,0,0,0,time.UTC)},
    }
}

func TestDiscoverBothBuildWorkflows(t *testing.T) {
    for _,tc:=range []struct{name,full_status string;want string}{
        {"oldest full build","success","101"},
        {"SiDi128 after failed full build","failure","202"},
    } {
        t.Run(tc.name,func(t *testing.T){
            runs:=dual_workflow_runs();runs[0].Conclusion=tc.full_status
            mock_build_workflows(t,runs)
            got,err:=DiscoverBuild(context.Background(),Config{},t.TempDir(),"")
            if err!=nil||got.RunID!=tc.want {t.Fatalf("selected %+v: %v",got,err)}
            if got.RunID=="202" && (got.Workflow!=compileSidi128Workflow||got.Artifact!="bbbbbbb-sidi128.zip") {t.Fatalf("wrong SiDi128 identity: %+v",got)}
        })
    }
}

func TestBothWorkflowsShareCommitCompletion(t *testing.T) {
    runs:=dual_workflow_runs();runs[1].HeadSHA=runs[0].HeadSHA
    mock_build_workflows(t,runs)
    root:=t.TempDir()
    if err:=InitializeLog(root);err!=nil{t.Fatal(err)}
    record,err:=OpenCommitLog(root,runs[0].HeadSHA,false);if err!=nil{t.Fatal(err)}
    defer record.Close()
    record.Progress.Games["core/set"]=ProgressGame{Result:Pass}
    record.Progress.AutomaticComplete=true;record.Progress.Status="complete"
    if err=record.Save();err!=nil{t.Fatal(err)}
    if _,err=DiscoverBuild(context.Background(),Config{NoPublish:true},root,"");err!=ErrNoEligibleBuild {t.Fatalf("same commit captured twice: %v",err)}
}

func TestBuildWorkflowRunNumbersMustBeUnambiguous(t *testing.T) {
    runs:=dual_workflow_runs();runs[1].RunNumber=runs[0].RunNumber
    mock_build_workflows(t,runs)
    if _,err:=getEligibleRunByNumber(context.Background(),githubRepository,7);err==nil||!strings.Contains(err.Error(),"use the GitHub run ID") {t.Fatalf("ambiguous run accepted: %v",err)}
    got,err:=DiscoverBuild(context.Background(),Config{},t.TempDir(),"202")
    if err!=nil||got.Workflow!=compileSidi128Workflow {t.Fatalf("explicit run ID failed: %+v %v",got,err)}
}

func TestNewWorkflowCanBeAbsentUntilDeployment(t *testing.T) {
    previous:=ghCommand;t.Cleanup(func(){ghCommand=previous})
    for _,status:=range []int{404,403,500} {
        ghCommand=func(_ context.Context,args ...string)([]byte,error){
            if strings.Contains(strings.Join(args," "),compileSidi128Workflow){return nil,fmt.Errorf("HTTP %d",status)}
            return []byte(`[{"workflow_runs":[]}]`),nil
        }
        _,err:=listWorkflowRuns(context.Background(),githubRepository)
        if (err==nil)!=(status==404) {t.Fatalf("HTTP %d: %v",status,err)}
    }
}

func TestSiDi128ArchiveDoesNotReuseFullPlatformZIP(t *testing.T) {
    root:=t.TempDir();cfg:=Config{Source:filepath.Join(root,"source"),BuildsDir:filepath.Join(root,"builds")}
    full:=filepath.Join(cfg.BuildsDir,"aaaaaaa.zip")
    manualWrite(t,full,[]byte("existing full-platform archive"))
    id:=BuildIdentity{Repository:githubRepository,Workflow:compileSidi128Workflow,RunID:"202",Attempt:"1",SHA:strings.Repeat("a",40),Artifact:"aaaaaaa-sidi128.zip",ArtifactID:2020}
    payload:=filepath.Join(root,"payload.zip")
    writeZip(t,payload,map[string]string{"release/sidi128/jtfoo.rbf":"new RBF","release/mra/Foo.mra":"MRA"})
    previous:=ghArtifactDownload;t.Cleanup(func(){ghArtifactDownload=previous})
    downloads:=0
    ghArtifactDownload=func(_ context.Context,_ string,artifact int64,destination string)error{
        if artifact!=2020{t.Fatalf("wrong artifact %d",artifact)}
        downloads++;writeZip(t,destination,map[string]string{id.Artifact:readString(t,payload)});return nil
    }
    for i:=0;i<2;i++ {
        archive,_,err:=prepareArtifact(context.Background(),cfg,filepath.Join(root,"preparation"),id)
        if err!=nil||archive!=filepath.Join(cfg.BuildsDir,id.Artifact) {t.Fatalf("archive %s: %v",archive,err)}
    }
    if downloads!=1||readString(t,full)!="existing full-platform archive"||readString(t,filepath.Join(cfg.Source,"release/sidi128/jtfoo.rbf"))!="new RBF" {t.Fatal("archive collision or wrong extraction")}
    id.Artifact="aaaaaaa.zip"
    if _,_,err:=prepareArtifact(context.Background(),cfg,filepath.Join(root,"bad"),id);err==nil{t.Fatal("SiDi128 workflow accepted full-platform name")}
}

func TestSiDi128WorkflowReportLabel(t *testing.T) {
    summary:=Summary{Build:BuildIdentity{Workflow:compileSidi128Workflow,RunNumber:8,RunID:"202"}}
    body:=formatGitHubSummary(summary,"marker")
    if !strings.Contains(body,"Build: compile_sidi128 #8")||strings.Contains(body,"compile_all") {t.Fatal(body)}
}
