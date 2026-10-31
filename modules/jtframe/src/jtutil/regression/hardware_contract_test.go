/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */

package regression

import (
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

type failing_diagnostic_hardware struct{}
func (*failing_diagnostic_hardware) Load(GameSpec)(LoadInfo,error){return LoadInfo{},nil}
func (*failing_diagnostic_hardware) Run(_ GameSpec,_ string,dir string)(RunInfo,error){
	work:=filepath.Dir(dir)
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
	batch:=makeBatch(t,t.TempDir(),&failing_diagnostic_hardware{},[]GameSpec{{Setname:"failed"}})
	if err:=batch.Run();err!=nil {t.Fatal(err)}
	if batch.State.Games["failed"].Outcome!=Error {t.Fatal("synthetic timeout outcome lost")}
	dir:=filepath.Join(batch.Root,"log",batch.RunID,batch.Core,"failed","helper")
	entries,err:=os.ReadDir(dir);if err!=nil {t.Fatal(err)}
	if len(entries)!=3 {t.Fatalf("unexpected diagnostic artifacts: %v",entries)}
	for _,name:=range []string{"helper-progress.log","ftp-report.json","ftp-report.json.upload.json"} {
		if _,err=os.Stat(filepath.Join(dir,name));err!=nil {t.Fatal(err)}
	}
	work:=filepath.Join(batch.CorePath,".cache","jtutil-regression","work",batch.RunID,batch.Core,"failed")
	if _,err=os.Stat(work);!os.IsNotExist(err) {t.Fatal("transient capture work was retained")}
}
