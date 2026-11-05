/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */
package regression

import (
    "bufio"
    "bytes"
    "crypto/rand"
    "encoding/hex"
    "time"
    "golang.org/x/sys/unix"
    "encoding/json"
    "fmt"
    "os"
    "path/filepath"
    "strings"
)

func HasResumeState(root,run_id string) bool {
    for _,name:=range []string{"state","events.jsonl"} {_,err:=os.Stat(filepath.Join(root,"log",run_id,name));if !os.IsNotExist(err){return true}}
    return false
}

// Resuming must not recreate a vanished mounted run or silently replace its
// journal. The original manifest anchors the selected campaign and build.
func RequireResumeJournal(root,run_id string,build BuildIdentity) error {
    dir:=filepath.Join(root,"log",run_id)
    for _,path:=range []string{dir,filepath.Join(dir,"state")} {
        info,err:=os.Stat(path)
        if err!=nil || !info.IsDir() {return fmt.Errorf("resume directory unavailable: %s",path)}
    }
    journal:=filepath.Join(dir,"events.jsonl")
    info,err:=os.Stat(journal)
    if err!=nil || !info.Mode().IsRegular() || info.Size()==0 {return fmt.Errorf("resume journal missing, empty, or invalid: %s",journal)}
    data,err:=os.ReadFile(filepath.Join(dir,"manifest.json"));if err!=nil {return err}
    var manifest Manifest
    if err=json.Unmarshal(data,&manifest);err!=nil {return err}
    if manifest.RunID!=run_id || !sameResumeBuild(manifest.Build,build) {return fmt.Errorf("resume journal manifest run/build anchor differs")}
    return nil
}

func (b *Batch) recover_record_error(game GameSpec,old GameResult) error {
    journal:=filepath.Join(b.Log.Dir,"events.jsonl")
    journal_error:=false
    for _,operation:=range []string{"write","sync","close"} {if strings.HasPrefix(old.RecordError,operation+" "+journal+": "){journal_error=true}}
    if !journal_error || strings.ContainsAny(old.RecordError,";\r\n") {return fmt.Errorf("cannot recover non-journal or composite record error for %s: %s",game.Setname,old.RecordError)}
    exists,err:=b.has_recovery_event(game,old)
    if err!=nil {return fmt.Errorf("check journal recovery for %s: %w",game.Setname,err)}
    if !exists {
        err=b.Log.Write(Event{Setname:game.Setname,Stage:"state-recovered",Outcome:old.Outcome,Message:"Verified finalized state recovered after a journal write failure",Fields:map[string]any{"original_record_error":old.RecordError,"original_stage":old.Stage,"test_identity":old.TestIdentity,"outcome":old.Outcome}})
        if err!=nil {return fmt.Errorf("append state recovery for %s: %w",game.Setname,err)}
    }
    cleared:=old;cleared.RecordError=""
    b.State.Games[game.Setname]=cleared
    if err=write_existing_state_directory(b.StatePath,b.State);err!=nil {
        b.State.Games[game.Setname]=old
        return fmt.Errorf("persist recovered state for %s: %w",game.Setname,err)
    }
    return nil
}

func (b *Batch) has_recovery_event(game GameSpec,old GameResult) (bool,error) {
    history,err:=b.Log.journal_history();if err!=nil{return false,err}
    scanner:=bufio.NewScanner(bytes.NewReader(history));scanner.Buffer(make([]byte,4096),1<<20)
    for scanner.Scan() {
        if strings.TrimSpace(scanner.Text())=="" {continue}
        var event Event
        if err=json.Unmarshal(scanner.Bytes(),&event);err!=nil {return false,fmt.Errorf("invalid existing journal JSON: %w",err)}
        if event.Stage!="state-recovered" || event.RunID!=b.RunID || event.Core!=b.Core || event.Setname!=game.Setname || event.Outcome!=old.Outcome {continue}
        fields,ok:=event.Fields.(map[string]any)
        if ok && fields["test_identity"]==old.TestIdentity && fields["original_record_error"]==old.RecordError && fields["original_stage"]==old.Stage && fields["outcome"]==string(old.Outcome) {return true,nil}
    }
    return false,scanner.Err()
}

func (b *Batch) persist_state() error {
    if b.Resume {return write_existing_state_directory(b.StatePath,b.State)}
    return WriteState(b.StatePath,b.State)
}

// All filesystem mutation is relative to an already-open directory. No mkdir
// or path-based temporary-file creation may recreate a vanished mounted path.
func write_existing_state_directory(filename string,state *State) error {
    copy:=*state;copy.Updated=time.Now().UTC()
    data,err:=json.MarshalIndent(&copy,"","  ");if err!=nil{return err}
    if err=WriteExistingFile(filename,append(data,'\n'),0640);err!=nil{return err}
    state.Updated=copy.Updated
    return nil
}

// WriteExistingFile atomically replaces a file inside an existing directory,
// without creating or reopening a vanished mounted directory by pathname.
func WriteExistingFile(filename string,data []byte,mode os.FileMode) error {
    parent:=filepath.Dir(filename)
    dir,err:=os.Open(parent);if err!=nil{return err};defer dir.Close()
    return write_existing_file_at(dir,parent,filepath.Base(filename),data,mode)
}

func write_existing_file_at(dir *os.File,parent,name string,data []byte,mode os.FileMode,before_replace ...func()error) error {
    original,err:=dir.Stat();if err!=nil{return err};if !original.IsDir(){return fmt.Errorf("parent is not a directory")}
    current,err:=os.Stat(parent);if err!=nil{return err};if !os.SameFile(original,current){return fmt.Errorf("directory changed")}
    var nonce [8]byte;if _,err=rand.Read(nonce[:]);err!=nil{return err}
    temporary:="."+name+".recovery-"+hex.EncodeToString(nonce[:])
    directory_fd:=int(dir.Fd())
    fd,err:=unix.Openat(directory_fd,temporary,unix.O_CREAT|unix.O_EXCL|unix.O_WRONLY|unix.O_NOFOLLOW,uint32(mode.Perm()));if err!=nil{return err}
    defer unix.Unlinkat(directory_fd,temporary,0)
    file:=os.NewFile(uintptr(fd),temporary)
    if _,err=file.Write(data);err!=nil{file.Close();return err}
    if err=file.Sync();err!=nil{file.Close();return err};if err=file.Close();err!=nil{return err}
    for _,guard:=range before_replace{if err=guard();err!=nil{return err}}
    current,err=os.Stat(parent);if err!=nil{return err};if !os.SameFile(original,current){return fmt.Errorf("directory changed before replacement")}
    if err=unix.Renameat(directory_fd,temporary,directory_fd,name);err!=nil{return err}
    return dir.Sync()
}
