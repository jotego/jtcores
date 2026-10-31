/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */

package regression

import (
	"context"
	"errors"
	"os"
	"path/filepath"
	"testing"
	"time"
)

func TestCaptureDeadlineIncludesRecordingAndRetrieval(t *testing.T) {
	for _, test:=range []struct{frames int;maximum,want time.Duration}{
		{4000,900*time.Second,520*time.Second},
		{1000,900*time.Second,220*time.Second},
		{4000,300*time.Second,300*time.Second},
		{4000,60*time.Second,60*time.Second},
		{int(^uint(0)>>1),0,900*time.Second},
		{int(^uint(0)>>1),time.Duration(1<<63-1),time.Duration(1<<63-1)},
		{-1,0,120*time.Second},
	} {
		if got:=timeout_for_frames(test.frames,test.maximum);got!=test.want {t.Fatalf("frames%d cap%s got%s want%s",test.frames,test.maximum,got,test.want)}
	}
}

func TestHelperProcessesUseUnbufferedPythonOutput(t *testing.T) {
	hardware:=&FTPHardware{}
	output,err:=hardware.run("sh",[]string{"-c",`printf '%s' "$PYTHONUNBUFFERED"`},time.Second)
	if err!=nil || output!="1" {t.Fatalf("unbuffered setting missing: %q %v",output,err)}
}

type failing_diagnostic_hardware struct{ work string }
func (*failing_diagnostic_hardware) Load(GameSpec)(LoadInfo,error){return LoadInfo{},nil}
func (h *failing_diagnostic_hardware) Run(_ GameSpec,_ string,dir string)(RunInfo,error){
	work:=filepath.Dir(dir)
	h.work=work
	for name,data:=range map[string]string{
		"helper-progress.log":"capture frame100 retrieved\n",
		"ftp-report.json.upload.json":`{"status":"uploading"}`,
		"ftp-report.json":`{"status":"timed-out"}`,
		"frame_00000100.raw":"raw",
		"frame_00000100.png":"png",
		"fixture.rom":"rom",
	} {
		if err:=os.WriteFile(filepath.Join(work,name),[]byte(data),0600);err!=nil {return RunInfo{},err}
	}
	return RunInfo{Report:filepath.Join(work,"ftp-report.json")},errors.New("synthetic helper timeout")
}
func (*failing_diagnostic_hardware) Cleanup([]string)error{return nil}
func (*failing_diagnostic_hardware) Healthy()error{return nil}

func TestFailedHelperKeepsOnlyTextDiagnosticsBeforeWorkRemoval(t *testing.T) {
	hardware:=&failing_diagnostic_hardware{}
	batch:=makeBatch(t,t.TempDir(),hardware,[]GameSpec{{Setname:"failed"}})
	if err:=batch.Run();err!=nil {t.Fatal(err)}
	if batch.State.Games["failed"].Outcome!=Error {t.Fatal("synthetic timeout outcome lost")}
	dir:=filepath.Join(batch.Root,"log",batch.RunID,batch.Core,"failed","helper")
	entries,err:=os.ReadDir(dir);if err!=nil {t.Fatal(err)}
	if len(entries)!=3 {t.Fatalf("unexpected diagnostic artifacts: %v",entries)}
	for _,name:=range []string{"helper-progress.log","ftp-report.json","ftp-report.json.upload.json"} {
		if _,err=os.Stat(filepath.Join(dir,name));err!=nil {t.Fatal(err)}
	}
	if filepath.Dir(hardware.work)!="/tmp" {t.Fatalf("workspace is not in /tmp: %s",hardware.work)}
	if _,err=os.Stat(hardware.work);!os.IsNotExist(err) {t.Fatal("transient capture work was retained") }
}

type workspace_hardware struct {
	Hardware
	t *testing.T
	work []string
}

func (h *workspace_hardware) Run(game GameSpec, cab, dir string) (RunInfo,error) {
	work:=filepath.Dir(dir)
	if filepath.Dir(work)!="/tmp" {h.t.Fatalf("capture workspace outside /tmp: %s",work)}
	info,err:=os.Stat(work)
	if err!=nil || info.Mode().Perm()!=0700 {h.t.Fatalf("workspace is not private: %v %v",info,err)}
	if filepath.Dir(cab)!=work {h.t.Fatalf("neutral CAB outside workspace: %s",cab)}
	for _,previous:=range h.work {
		if previous==work {h.t.Fatal("games reused a workspace")}
		if _,err=os.Stat(previous);!os.IsNotExist(err) {h.t.Fatal("previous game workspace survived until next game")}
	}
	h.work=append(h.work,work)
	if err=os.WriteFile(filepath.Join(work,"frame.raw"),[]byte("temporary raw capture"),0600);err!=nil {h.t.Fatal(err)}
	return h.Hardware.Run(game,cab,dir)
}

func TestSuccessfulCapturesRemoveEachTemporaryWorkspace(t *testing.T) {
	batch,game,hardware:=qualityBatch(t,[]uint16{1,2,3})
	second:=game
	second.Setname="second"
	batch.Games=append(batch.Games,second)
	observer:=&workspace_hardware{Hardware:hardware,t:t}
	batch.Hardware=observer
	if err:=batch.Run();err!=nil {t.Fatal(err)}
	if len(observer.work)!=2 {t.Fatalf("expected two captures: %v",observer.work)}
	for _,work:=range observer.work {
		if _,err:=os.Stat(work);!os.IsNotExist(err) {t.Fatal("successful capture retained temporary work")}
	}
	for _,set:=range []string{game.Setname,second.Setname} {
		if batch.State.Games[set].Outcome!=New {t.Fatalf("capture did not finish: %+v",batch.State.Games[set])}
		if _,err:=os.Stat(filepath.Join(batch.Root,batch.Core,set,"new","frame_00000100.png"));err!=nil {t.Fatal("published capture lost:",err)}
	}
}

type interrupted_hardware struct {
    Hardware
    cancel context.CancelFunc
}
func (h *interrupted_hardware) Run(game GameSpec, cab, dir string) (RunInfo,error) {
    result,err := h.Hardware.Run(game,cab,dir)
    h.cancel()
    return result,err
}
func TestInterruptCleansCurrentGameAndLeavesNextPending(t *testing.T) {
    batch,game,hardware:=qualityBatch(t,[]uint16{1,2,3})
    ctx,cancel:=context.WithCancel(context.Background())
    defer cancel()
    batch.Context=ctx
    second:=game
    second.Setname="second"
    batch.Games=append(batch.Games,second)
    observer:=&workspace_hardware{Hardware:hardware,t:t}
    batch.Hardware=&interrupted_hardware{Hardware:observer,cancel:cancel}
    if err:=batch.Run();!errors.Is(err,context.Canceled) {t.Fatalf("interrupt lost: %v",err)}
    if len(observer.work)!=1 {t.Fatalf("started next game after interrupt: %v",observer.work)}
    if _,err:=os.Stat(observer.work[0]);!os.IsNotExist(err) {t.Fatal("interrupted capture retained temporary work")}
    if batch.State.Games[game.Setname].Outcome!=New || batch.State.Games["second"].Outcome!=Pending {t.Fatalf("wrong interrupted state: %+v",batch.State.Games)}
}

func TestChangedPreparedInputStopsBeforeBoardLoad(t *testing.T) {
    batch,game,hardware:=qualityBatch(t,[]uint16{1,2,3})
    digest,err:=fileSHA256(game.RBF)
    if err!=nil {t.Fatal(err)}
    game.PreparedHashes=map[string]string{game.RBF:digest}
    batch.Games=[]GameSpec{game}
    if err=os.WriteFile(game.RBF,[]byte("another local build"),0600);err!=nil {t.Fatal(err)}
    if err=batch.Run();err!=nil {t.Fatal(err)}
    result:=batch.State.Games[game.Setname]
    if hardware.loads!=0 || result.Outcome!=Error || result.Stage!="prepare" {t.Fatalf("changed build reached hardware: loads%d result%+v",hardware.loads,result)}
}
