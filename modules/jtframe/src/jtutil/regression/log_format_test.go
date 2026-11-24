/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */
package regression

import (
    "os"
    "path/filepath"
    "strings"
    "testing"
    "time"
)

func TestLogFieldsStayAligned(t *testing.T) {
    stamp:=time.Date(2026,10,31,12,34,56,0,time.Local)
    for _,sample:=range []struct{game string;seconds float64;verdict,message string}{
        {"circus/circusc",185.2,"pass",""},
        {"s16b/bayroute",201.9,"fail","19/40 frames differ"},
        {"",-1,"error","discovery failed\nconnection refused"},
        {"fake/"+strings.Repeat("long",10),0,"unsupported","not supported"},
    }{
        output:=FormatLogEntry(stamp,sample.game,sample.seconds,sample.verdict,sample.message)
        for _,line:=range strings.Split(strings.TrimSuffix(output,"\n"),"\n"){
            if len(line)<75{t.Fatalf("missing fields: %q",line)}
            if line[:10]!="2026-10-31"||line[11:19]!="12:34:56"{t.Fatalf("date/time fields: %q",line)}
            for _,position:=range []int{10,19,52,63}{if line[position]!=' '{t.Fatalf("unaligned field at %d: %q",position,line)}}
            if strings.TrimSpace(line[64:75])!=strings.ToUpper(sample.verdict){t.Fatalf("verdict moved: %q",line)}
            if sample.seconds<0&&strings.TrimSpace(line[53:63])!="-"{t.Fatal("unmeasured duration displayed as zero")}
        }
        if len(sample.game)>32&&!strings.Contains(output,sample.game){t.Fatal("long game identity lost")}
    }
}

func TestFrameDifferenceMessageCountsOnlyComparedFrames(t *testing.T) {
    batch,game,_:=qualityBatch(t,[]uint16{1,4,3,5})
    manualWrite(t,batch.GlobalProfile,[]byte("video: 400\nstart-up: 100\n"))
    reference:=make_capture_fixture(t,[]uint16{9,2,3,4})
    ref:=filepath.Join(batch.Root,batch.Core,game.Setname,"ref")
    if err:=os.MkdirAll(ref,0750);err!=nil{t.Fatal(err)}
    if err:=export_png_frames(reference,ref);err!=nil{t.Fatal(err)}
    if err:=batch.Run();err!=nil{t.Fatal(err)}
    result:=batch.State.Games[game.Setname]
    if result.Outcome!=Fail||result.Message!="2/3 frames differ"{t.Fatalf("incorrect comparison count: %+v",result)}
}
