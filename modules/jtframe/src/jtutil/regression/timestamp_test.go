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

func TestProgressLocalTimeAndLegacyResume(t *testing.T) {
    madrid,err:=time.LoadLocation("Europe/Madrid");if err!=nil{t.Fatal(err)}
    previous:=time.Local;time.Local=madrid;t.Cleanup(func(){time.Local=previous})
    commit:=strings.Repeat("a",40)
    root:=t.TempDir()
    legacy:=`{"commit":"`+commit+`","status":"interrupted","started":"2026-10-31T09:33:34.123456789Z","updated":"2026-10-31T09:34:00Z","games":{"fake/game":{"result":"pending"}}}`
    manualWrite(t,filepath.Join(root,"log",commit+".json"),[]byte(legacy))
    if err=InitializeLog(root);err!=nil{t.Fatal(err)}
    record,err:=OpenCommitLog(root,commit);if err!=nil{t.Fatal(err)};defer record.Close()
    started:=record.Progress.Started
    if LogTime(started)!="2026-10-31 10:33:34"{t.Fatal("text timestamp is not local with a space")}
    if err=record.Save();err!=nil{t.Fatal(err)}
    raw,err:=os.ReadFile(filepath.Join(root,"log",LogKey(commit,false)+".json"));if err!=nil{t.Fatal(err)}
    if !strings.Contains(string(raw),`"started": "2026-10-31 10:33:34.123456789+01:00"`){t.Fatalf("wrong saved local timestamp: %s",raw)}
    restored,err:=ReadProgress(root,commit);if err!=nil{t.Fatal(err)}
    if !restored.Started.Equal(started)||restored.Games["fake/game"].Result!=Pending{t.Fatal("resume state changed during timestamp conversion")}
    if err=record.Write("local log test");err!=nil{t.Fatal(err)}
    raw,err=os.ReadFile(filepath.Join(root,"log",LogKey(commit,false)+".log"));if err!=nil{t.Fatal(err)}
    if len(raw)<20||raw[10]!=' '||raw[19]!=' '{t.Fatalf("wrong text log timestamp: %s",raw)}
    written,err:=time.ParseInLocation("2006-01-02 15:04:05",string(raw[:19]),madrid);if err!=nil{t.Fatal(err)}
    if time.Since(written)<0||time.Since(written)>5*time.Second{t.Fatal("text log did not use current local time")}
    for _,stamp:=range []string{"2026-10-25T00:30:00Z","2026-10-25T01:30:00Z","0001-01-01T00:00:00Z"}{
        instant,err:=time.Parse(time.RFC3339,stamp);if err!=nil{t.Fatal(err)}
        data,err:=json.Marshal(Progress{Started:instant});if err!=nil{t.Fatal(err)}
        var decoded Progress
        if err=json.Unmarshal(data,&decoded);err!=nil{t.Fatal(err)}
        if !decoded.Started.Equal(instant)||!decoded.Updated.IsZero(){t.Fatalf("lost timestamp identity around DST/zero time: %s",data)}
    }
}
