/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */

package regression

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// The helper models FTP ownership and failures on local temporary files only.
func TestRegressionCurlProcess(t *testing.T) {
	root:=os.Getenv("JTREG_CURL_TEST_ROOT");if root=="" {return}
	var args []string
	for i,arg:=range os.Args {if arg=="--" {args=os.Args[i+1:];break}}
	file,err:=os.OpenFile(filepath.Join(root,"calls.jsonl"),os.O_CREATE|os.O_APPEND|os.O_WRONLY,0600);if err!=nil {os.Exit(2)}
	_ = json.NewEncoder(file).Encode(args);_ = file.Close()
	var upload,quote,url string
	list_only:=false
	for i,arg:=range args {if arg=="--list-only" {list_only=true};if arg=="--upload-file" && i+1<len(args) {upload=args[i+1]};if arg=="--quote" && i+1<len(args) {quote=args[i+1]};if strings.HasPrefix(arg,"ftp://board/") {url=strings.TrimPrefix(arg,"ftp://board/")}}
	fail:=func(name string,once bool)bool {path:=filepath.Join(root,name);if _,e:=os.Stat(path);e!=nil {return false};if once {_ = os.Remove(path)};return true}
	remote:=func(path string)string{return filepath.Join(root,"remote",strings.TrimPrefix(path,"/"))}
	if list_only {
		entries,e:=os.ReadDir(remote(url));if e!=nil {os.Exit(21)}
		for _,entry:=range entries {fmt.Println(entry.Name())}
		os.Exit(0)
	}
	if upload!="" {
		data,e:=os.ReadFile(upload);if e!=nil {os.Exit(2)}
		target:=remote(url);_ = os.MkdirAll(filepath.Dir(target),0750)
		role:="rom";if strings.HasSuffix(upload,".rbf") {role="rbf"};if strings.HasSuffix(upload,".arc") {role="arc"}
		if fail("fail-next-"+role,true) {_ = os.WriteFile(target,data[:len(data)/2],0600);os.Exit(22)}
		if os.WriteFile(target,data,0600)!=nil {os.Exit(2)}
	}
	if strings.HasPrefix(quote,"SITE LOAD ") {
		if fail("fail-next-load",true) {os.Exit(21)}
		if _,e:=os.Stat(remote(strings.TrimPrefix(quote,"SITE LOAD ")));e!=nil {os.Exit(21)}
	}
	if strings.HasPrefix(quote,"DELE ") {
		path:=strings.TrimPrefix(quote,"DELE ")
		if strings.HasSuffix(path,".rbf") && fail("fail-rbf-delete",false) {os.Exit(21)}
		if os.Remove(remote(path))!=nil {os.Exit(21)}
	}
	if strings.HasPrefix(quote,"RMD ") {if os.Remove(remote(strings.TrimPrefix(quote,"RMD ")))!=nil {os.Exit(21)}}
	os.Exit(0)
}

func mock_rbf_hardware(t *testing.T)(*FTPHardware,string) {
	t.Helper();root:=t.TempDir();t.Setenv("JTREG_CURL_TEST_ROOT",root)
	if err:=os.MkdirAll(filepath.Join(root,"remote"),0750);err!=nil {t.Fatal(err)}
	executable,err:=os.Executable();if err!=nil {t.Fatal(err)}
	curl:=filepath.Join(root,"curl")
	script:=fmt.Sprintf("#!/bin/sh\nexec %q -test.run=TestRegressionCurlProcess -- \"$@\"\n",executable)
	if err=os.WriteFile(curl,[]byte(script),0700);err!=nil {t.Fatal(err)}
	return &FTPHardware{Host:"board",Curl:curl,PendingUploadDirsPath:filepath.Join(root,"log","upload-cleanup.json")},root
}

func mock_rbf_game(t *testing.T,root,set string)GameSpec {
	t.Helper();game:=GameSpec{Setname:set,RBF:filepath.Join(root,"jttest.rbf"),ARC:filepath.Join(root,set+".arc"),ROMs:[]string{filepath.Join(root,set+".rom")}}
	for path,data:=range map[string]string{game.RBF:"shared-RBF-bytes",game.ARC:"ARC-"+set,game.ROMs[0]:"ROM-"+set} {if err:=os.WriteFile(path,[]byte(data),0600);err!=nil {t.Fatal(err)}}
	return game
}

func mock_curl_calls(t *testing.T,root string)[][]string {
	t.Helper();data,err:=os.ReadFile(filepath.Join(root,"calls.jsonl"));if err!=nil {t.Fatal(err)}
	var calls [][]string
	for _,line:=range strings.Split(strings.TrimSpace(string(data)),"\n") {var args []string;if err=json.Unmarshal([]byte(line),&args);err!=nil {t.Fatal(err)};calls=append(calls,args)}
	return calls
}

func count_mock_calls(calls [][]string,option,contains string)int {
	count:=0
	for _,args:=range calls {for i,arg:=range args {if arg==option && i+1<len(args) && strings.Contains(args[i+1],contains) {count++}}}
	return count
}

func TestCoreUploadsRBFOnceAndLoadsEveryGame(t *testing.T) {
	h,root:=mock_rbf_hardware(t)
	var shared_dir string
	for i,set:=range []string{"one","two","three"} {
		game:=mock_rbf_game(t,root,set)
		info,err:=h.Load(game);if err!=nil {t.Fatal(err)}
		if i==0 {shared_dir=h.core_dir} else if h.core_dir!=shared_dir {t.Fatal("same core changed upload namespace")}
		if info.RBFReused!=(i>0) || len(info.Transfers)!=3 || info.SiteLoadDuration<=0 {t.Fatalf("missing transfer/load timing: %+v",info)}
		for _,transfer:=range info.Transfers {if transfer.Reused {if transfer.Role!="rbf" || transfer.Bytes!=0 || transfer.Uploaded {t.Fatal("reused RBF reported as uploaded")}} else if !transfer.Uploaded || transfer.Bytes<1 || transfer.Duration<=0 {t.Fatalf("invalid upload timing: %+v",transfer)}}
		for _,path:=range info.RemoteFiles {if strings.HasSuffix(path,".rbf") || ownedLoadDir(path) {t.Fatal("game owns shared RBF or directory")}}
		if err=h.Cleanup(info.RemoteFiles);err!=nil {t.Fatal(err)}
		if _,err=os.Stat(filepath.Join(root,"remote",shared_dir,"jttest.rbf"));err!=nil {t.Fatal("per-game cleanup removed shared RBF")}
	}
	calls:=mock_curl_calls(t,root)
	if count_mock_calls(calls,"--upload-file",".rbf")!=1 || count_mock_calls(calls,"--upload-file",".arc")!=3 || count_mock_calls(calls,"--upload-file",".rom")!=3 || count_mock_calls(calls,"--quote","SITE LOAD ")!=3 {t.Fatalf("wrong upload/load counts: %v",calls)}
	if err:=h.ReleaseCore();err!=nil {t.Fatal(err)}
	calls=mock_curl_calls(t,root)
	if count_mock_calls(calls,"--quote","DELE "+shared_dir+"/jttest.rbf")!=1 || count_mock_calls(calls,"--quote","RMD "+shared_dir)!=0 {t.Fatal("release did not delete RBF and defer current directory")}
	game:=mock_rbf_game(t,root,"next")
	info,err:=h.Load(game);if err!=nil {t.Fatal(err)}
	if info.RBFReused || h.core_dir==shared_dir {t.Fatal("next core scope trusted previous cached RBF")}
	calls=mock_curl_calls(t,root)
	if count_mock_calls(calls,"--quote","RMD "+shared_dir)!=1 {t.Fatal("next successful load did not remove old namespace")}
	_ = h.Cleanup(info.RemoteFiles);if err=h.ReleaseCore();err!=nil {t.Fatal(err)}
}

func TestFailedRBFUploadIsRetriedAndNotGameOwned(t *testing.T) {
	h,root:=mock_rbf_hardware(t);game:=mock_rbf_game(t,root,"one")
	if err:=os.WriteFile(filepath.Join(root,"fail-next-rbf"),nil,0600);err!=nil {t.Fatal(err)}
	info,err:=h.Load(game);if err==nil || h.core_rbf_ready || len(info.RemoteFiles)!=0 || len(info.Transfers)!=1 || info.Transfers[0].Error=="" {t.Fatalf("partial RBF incorrectly cached/owned: %+v %v",info,err)}
	info,err=h.Load(game);if err!=nil || info.RBFReused {t.Fatalf("failed RBF not retried: %+v %v",info,err)}
	if count_mock_calls(mock_curl_calls(t,root),"--upload-file",".rbf")!=2 {t.Fatal("failed RBF upload not retried")}
	_ = h.Cleanup(info.RemoteFiles);if err=h.ReleaseCore();err!=nil {t.Fatal(err)}
}

func TestGameUploadAndLoadFailuresKeepSharedRBF(t *testing.T) {
	for _,failure:=range []string{"arc","rom","load"} {t.Run(failure,func(t *testing.T){
		h,root:=mock_rbf_hardware(t);game:=mock_rbf_game(t,root,"one")
		if err:=os.WriteFile(filepath.Join(root,"fail-next-"+failure),nil,0600);err!=nil {t.Fatal(err)}
		info,err:=h.Load(game);if err==nil || !h.core_rbf_ready {t.Fatalf("game failure discarded verified shared RBF: %v",err)}
		if failure=="load" && info.SiteLoadDuration<=0 {t.Fatal("failed SITE LOAD timing missing")}
		if err=h.Cleanup(info.RemoteFiles);err!=nil {t.Fatal(err)}
		info,err=h.Load(mock_rbf_game(t,root,"two"));if err!=nil || !info.RBFReused {t.Fatalf("next title did not reuse RBF: %v",err)}
		if count_mock_calls(mock_curl_calls(t,root),"--upload-file",".rbf")!=1 {t.Fatal("RBF uploaded again after game failure")}
		_ = h.Cleanup(info.RemoteFiles);if err=h.ReleaseCore();err!=nil {t.Fatal(err)}
	})}
}

func TestChangedRBFIdentityFailsBeforeAnyNewUpload(t *testing.T) {
	h,root:=mock_rbf_hardware(t);game:=mock_rbf_game(t,root,"one")
	info,err:=h.Load(game);if err!=nil {t.Fatal(err)}
	before:=len(mock_curl_calls(t,root))
	if err=os.WriteFile(game.RBF,[]byte("different-RBF"),0600);err!=nil {t.Fatal(err)}
	if _,err=h.Load(game);err==nil || !strings.Contains(err.Error(),"identity changed") {t.Fatalf("changed RBF reused: %v",err)}
	if len(mock_curl_calls(t,root))!=before {t.Fatal("changed identity performed FTP operations")}
	_ = h.Cleanup(info.RemoteFiles);if err=h.ReleaseCore();err!=nil {t.Fatal(err)}
}

func TestFailedSharedDeletionSurvivesFreshHardwareInstance(t *testing.T) {
	h,root:=mock_rbf_hardware(t);game:=mock_rbf_game(t,root,"one")
	info,err:=h.Load(game);if err!=nil {t.Fatal(err)}
	if err=h.Cleanup(info.RemoteFiles);err!=nil {t.Fatal(err)}
	old_dir:=h.core_dir
	if err=os.WriteFile(filepath.Join(root,"fail-rbf-delete"),nil,0600);err!=nil {t.Fatal(err)}
	if err=h.ReleaseCore();err==nil {t.Fatal("failed shared deletion was not reported")}
	pending,err:=os.ReadFile(h.PendingUploadDirsPath);if err!=nil || !strings.Contains(string(pending),old_dir+"/jttest.rbf") || !strings.Contains(string(pending),old_dir+`"`) {t.Fatalf("file and directory cleanup ownership lost: %s %v",pending,err)}
	if err=os.Remove(filepath.Join(root,"fail-rbf-delete"));err!=nil {t.Fatal(err)}
	fresh:=&FTPHardware{Host:h.Host,Curl:h.Curl,PendingUploadDirsPath:h.PendingUploadDirsPath}
	info,err=fresh.Load(mock_rbf_game(t,root,"fresh"));if err!=nil || info.RBFReused {t.Fatalf("fresh process trusted old RBF: %v",err)}
	if _,err=os.Stat(filepath.Join(root,"remote",old_dir));!os.IsNotExist(err) {t.Fatal("fresh process did not clean failed shared deletion")}
	pending,err=os.ReadFile(h.PendingUploadDirsPath);if err!=nil || strings.Contains(string(pending),old_dir) {t.Fatalf("cleaned ownership remained in ledger: %s %v",pending,err)}
	_ = fresh.Cleanup(info.RemoteFiles);if err=fresh.ReleaseCore();err!=nil {t.Fatal(err)}
}

func TestInterruptedCoreOwnershipIsDurableBeforeRelease(t *testing.T) {
	h,root:=mock_rbf_hardware(t);game:=mock_rbf_game(t,root,"one")
	info,err:=h.Load(game);if err!=nil {t.Fatal(err)}
	old_dir:=h.core_dir
	pending,err:=os.ReadFile(h.PendingUploadDirsPath);if err!=nil {t.Fatal(err)}
	for _,name:=range append([]string{old_dir,old_dir+"/jttest.rbf"},info.RemoteFiles...) {if !strings.Contains(string(pending),name) {t.Fatalf("ownership not durable before release: %s",name)}}
	// Simulate losing the process without per-game or per-core cleanup.
	fresh:=&FTPHardware{Host:h.Host,Curl:h.Curl,PendingUploadDirsPath:h.PendingUploadDirsPath}
	next,err:=fresh.Load(mock_rbf_game(t,root,"fresh"));if err!=nil {t.Fatal(err)}
	if _,err=os.Stat(filepath.Join(root,"remote",old_dir));!os.IsNotExist(err) {t.Fatal("fresh process left nonempty interrupted namespace")}
	pending,err=os.ReadFile(h.PendingUploadDirsPath);if err!=nil || strings.Contains(string(pending),old_dir) {t.Fatalf("interrupted ownership not retired: %s %v",pending,err)}
	_ = fresh.Cleanup(next.RemoteFiles);if err=fresh.ReleaseCore();err!=nil {t.Fatal(err)}
}

func TestCleanupLedgerRetiresAlreadyDeletedFilesWithEmptyDirectory(t *testing.T) {
	h,root:=mock_rbf_hardware(t);game:=mock_rbf_game(t,root,"one")
	info,err:=h.Load(game);if err!=nil {t.Fatal(err)}
	if err=h.Cleanup(info.RemoteFiles);err!=nil {t.Fatal(err)}
	old_dir:=h.core_dir
	if err=h.ReleaseCore();err!=nil {t.Fatal(err)}
	fresh:=&FTPHardware{Host:h.Host,Curl:h.Curl,PendingUploadDirsPath:h.PendingUploadDirsPath}
	next,err:=fresh.Load(mock_rbf_game(t,root,"fresh"));if err!=nil {t.Fatal(err)}
	pending,err:=os.ReadFile(h.PendingUploadDirsPath);if err!=nil || strings.Contains(string(pending),old_dir) {t.Fatalf("missing files prevented empty-directory cleanup: %s %v",pending,err)}
	_ = fresh.Cleanup(next.RemoteFiles);if err=fresh.ReleaseCore();err!=nil {t.Fatal(err)}
}

func TestPreuploadInterruptionDoesNotLeavePhantomOwnership(t *testing.T) {
	h,root:=mock_rbf_hardware(t)
	phantom:="/JTREG_0123456789abcdef01234567"
	for _,name:=range []string{phantom,phantom+"/jttest.rbf",phantom+"/one.arc",phantom+"/one.rom"} {if err:=h.queuePendingUploadDir(name);err!=nil {t.Fatal(err)}}
	fresh:=&FTPHardware{Host:h.Host,Curl:h.Curl,PendingUploadDirsPath:h.PendingUploadDirsPath}
	info,err:=fresh.Load(mock_rbf_game(t,root,"fresh"));if err!=nil {t.Fatal(err)}
	pending,err:=os.ReadFile(h.PendingUploadDirsPath);if err!=nil || strings.Contains(string(pending),phantom) {t.Fatalf("proven absent ownership remained: %s %v",pending,err)}
	_ = fresh.Cleanup(info.RemoteFiles);if err=fresh.ReleaseCore();err!=nil {t.Fatal(err)}
}

func TestPresentPermissionFailureIsNotTreatedAsAbsence(t *testing.T) {
	h,root:=mock_rbf_hardware(t);game:=mock_rbf_game(t,root,"one")
	info,err:=h.Load(game);if err!=nil {t.Fatal(err)}
	if err=h.Cleanup(info.RemoteFiles);err!=nil {t.Fatal(err)}
	old_dir:=h.core_dir
	if err=os.WriteFile(filepath.Join(root,"fail-rbf-delete"),nil,0600);err!=nil {t.Fatal(err)}
	if err=h.ReleaseCore();err==nil {t.Fatal("present shared RBF deletion failure was ignored")}
	fresh:=&FTPHardware{Host:h.Host,Curl:h.Curl,PendingUploadDirsPath:h.PendingUploadDirsPath}
	fresh.Logger=func(string){}
	info,err=fresh.Load(mock_rbf_game(t,root,"fresh"));if err!=nil {t.Fatal(err)}
	pending,err:=os.ReadFile(h.PendingUploadDirsPath);if err!=nil || !strings.Contains(string(pending),old_dir+"/jttest.rbf") {t.Fatalf("permission failure ownership lost: %s %v",pending,err)}
	_ = os.Remove(filepath.Join(root,"fail-rbf-delete"))
	_ = fresh.Cleanup(info.RemoteFiles);if err=fresh.ReleaseCore();err!=nil {t.Fatal(err)}
}
