/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */
package regression

import (
    "bytes"
    "encoding/json"
    "fmt"
    "io"
    "os"
    "path/filepath"
    "time"
    "golang.org/x/sys/unix"
)

func open_event_log(dir,run_id,core string,flags int)(*EventLog,error){
    directory,err:=os.Open(dir);if err!=nil{return nil,err}
    log:=&EventLog{RunID:run_id,Core:core,Dir:dir,directory:directory}
    history,_,err:=log.read_journal()
    if os.IsNotExist(err)&&flags&os.O_CREATE!=0 {
        fd,create_error:=unix.Openat(int(directory.Fd()),"events.jsonl",unix.O_CREAT|unix.O_EXCL|unix.O_WRONLY|unix.O_APPEND|unix.O_NOFOLLOW,0640)
        if create_error==nil {log.file=os.NewFile(uintptr(fd),filepath.Join(dir,"events.jsonl"))} else if create_error!=unix.EEXIST {directory.Close();return nil,create_error}
        history,_,err=log.read_journal()
    }
    if err!=nil {log.Close();return nil,err}
    if flags&os.O_CREATE==0&&len(history)==0{log.Close();return nil,fmt.Errorf("resume event journal became empty before anchored open")}
    if !valid_journal(history){log.Close();return nil,fmt.Errorf("existing event journal is incomplete or invalid")}
    log.history=history
    if log.file==nil {log.reopen_append()}
    return log,nil
}

func valid_journal(data []byte)bool{
    if len(data)>0 && data[len(data)-1]!='\n'{return false}
    for _,line:=range bytes.Split(data,[]byte{'\n'}){if len(bytes.TrimSpace(line))>0&&!json.Valid(line){return false}}
    return true
}

func(l *EventLog) same_directory()error{
    original,err:=l.directory.Stat();if err!=nil{return err}
    current,err:=os.Stat(l.Dir);if err!=nil{return err}
    if !original.IsDir()||!os.SameFile(original,current){return fmt.Errorf("event run directory changed identity")}
    return nil
}

func(l *EventLog) read_journal()([]byte,os.FileInfo,error){
    if err:=l.same_directory();err!=nil{return nil,nil,err}
    fd,err:=unix.Openat(int(l.directory.Fd()),"events.jsonl",unix.O_RDONLY|unix.O_NOFOLLOW,0)
    if err!=nil{return nil,nil,&os.PathError{Op:"open",Path:filepath.Join(l.Dir,"events.jsonl"),Err:err}}
    file:=os.NewFile(uintptr(fd),filepath.Join(l.Dir,"events.jsonl"));defer file.Close()
    info,err:=file.Stat();if err!=nil{return nil,nil,err}
    if !info.Mode().IsRegular(){return nil,nil,fmt.Errorf("event journal is not a regular file")}
    data,err:=io.ReadAll(file)
    return data,info,err
}

func(l *EventLog) reopen_append(){
    if l.file!=nil{_ = l.file.Close();l.file=nil}
    fd,err:=unix.Openat(int(l.directory.Fd()),"events.jsonl",unix.O_WRONLY|unix.O_APPEND|unix.O_NOFOLLOW,0)
    if err==nil{l.file=os.NewFile(uintptr(fd),filepath.Join(l.Dir,"events.jsonl"))}
}

func(l *EventLog) write_event(event Event)error{
    l.mu.Lock();defer l.mu.Unlock()
    path:=filepath.Join(l.Dir,"events.jsonl")
    if l.closed{return &os.PathError{Op:"write",Path:path,Err:os.ErrClosed}}
    if err:=l.same_directory();err!=nil{return err}
    if event.Time.IsZero(){event.Time=time.Now().UTC()};if event.RunID==""{event.RunID=l.RunID};if event.Core==""{event.Core=l.Core}
    line,err:=json.Marshal(event);if err!=nil{return err};line=append(line,'\n')
    current,info,read_error:=l.read_journal()
    repair:=false
    if read_error!=nil{
        if !os.IsNotExist(read_error){return read_error};repair=true
    }else if !bytes.Equal(current,l.history){
        if bytes.HasPrefix(l.history,current){repair=true}else if bytes.HasPrefix(current,l.history)&&valid_journal(current){l.history=append([]byte(nil),current...)}else{return fmt.Errorf("event journal diverged from cached history; refusing to overwrite it")}
    }
    desired:=make([]byte,0,len(l.history)+len(line));desired=append(desired,l.history...);desired=append(desired,line...)
    if !repair {
        if l.file!=nil{opened,stat_error:=l.file.Stat();if stat_error!=nil||!os.SameFile(opened,info){l.reopen_append()}}else{l.reopen_append()}
        if l.file==nil{repair=true}else if _,err=l.file.Write(line);err!=nil{repair=true}else if err=l.file.Sync();err!=nil{repair=true}
    }
    if !repair {
        verified,_,verify_error:=l.read_journal()
        if verify_error==nil&&bytes.Equal(verified,desired){l.history=desired;return nil}
        if verify_error!=nil&&!os.IsNotExist(verify_error){return verify_error}
        if verify_error==nil&&!bytes.HasPrefix(desired,verified){return fmt.Errorf("event journal changed concurrently; refusing to overwrite it")}
        repair=true
    }
    if repair {if err=l.replace_journal(desired);err!=nil{return err}}
    return nil
}

func(l *EventLog) replace_journal(desired []byte)error{
    guard:=func()error{
        if l.before_repair_check!=nil{l.before_repair_check()}
        latest,_,check_error:=l.read_journal()
        if os.IsNotExist(check_error){return nil};if check_error!=nil{return check_error}
        if !bytes.HasPrefix(desired,latest){return fmt.Errorf("event journal diverged before atomic replacement")}
        return nil
    }
    if err:=write_existing_file_at(l.directory,l.Dir,"events.jsonl",desired,0640,guard);err!=nil{return err}
    verified,_,err:=l.read_journal();if err!=nil{return err}
    if !bytes.Equal(verified,desired){return fmt.Errorf("atomic event journal replacement did not retain full history")}
    l.history=append([]byte(nil),desired...);l.reopen_append()
    return nil
}

// Recovery deduplication uses the same canonical history as normal writes.
// Restore a stale path before permitting a state error to be durably cleared.
func(l *EventLog) journal_history()([]byte,error){
    l.mu.Lock();defer l.mu.Unlock()
    if err:=l.same_directory();err!=nil{return nil,err}
    current,_,err:=l.read_journal()
    if err!=nil{
        if !os.IsNotExist(err){return nil,err}
        if err=l.replace_journal(l.history);err!=nil{return nil,err}
    }else if !bytes.Equal(current,l.history){
        if bytes.HasPrefix(l.history,current){if err=l.replace_journal(l.history);err!=nil{return nil,err}}else if bytes.HasPrefix(current,l.history)&&valid_journal(current){l.history=append([]byte(nil),current...)}else{return nil,fmt.Errorf("event journal diverged during recovery lookup")}
    }
    return append([]byte(nil),l.history...),nil
}
