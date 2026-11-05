/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */
package regression

import (
    "fmt"
    "hash/crc32"
    "io"
    "io/fs"
    "os"
    "path/filepath"
    "strings"
)

// Called before marking the game complete, while the common board lock is held.
func (l *CommitLog) append_game_history(core,set string,result GameResult) error {
    if result.Outcome==Pending{return nil}
    if !safeComponent(core)||!safeComponent(set){return fmt.Errorf("invalid history game %q/%q",core,set)}
    dir:=filepath.Join(l.Root,core,set)
    crc,err:=reference_crc(filepath.Join(dir,"ref"));if err!=nil{return fmt.Errorf("%s/%s reference CRC: %w",core,set,err)}
    if err=os.MkdirAll(dir,0750);err!=nil{return err}
    file,err:=os.OpenFile(filepath.Join(dir,"log"),os.O_CREATE|os.O_WRONLY|os.O_APPEND,0640)
    if err!=nil{return fmt.Errorf("%s/%s history: %w",core,set,err)}
    row:=fmt.Sprintf("%s %-13s %-11s %s\n",LogTime(result.Finished),LogKey(l.Progress.Commit,l.Progress.Dirty),strings.ToUpper(string(result.Outcome)),crc)
    _,write_error:=io.WriteString(file,row)
    if write_error==nil{write_error=file.Sync()}
    close_error:=file.Close()
    if write_error!=nil{return fmt.Errorf("%s/%s history: %w",core,set,write_error)}
    return close_error
}

// CRC32/IEEE covers sorted relative names and raw file bytes, not timestamps.
// Type tags, NUL-separated names and file lengths make boundaries unambiguous.
func reference_crc(dir string)(string,error) {
    info,err:=os.Lstat(dir)
    if os.IsNotExist(err){return "--------",nil};if err!=nil{return "",err}
    if !info.IsDir(){return "",fmt.Errorf("reference is not a directory")}
    digest:=crc32.NewIEEE()
    err=filepath.WalkDir(dir,func(path string,entry fs.DirEntry,walk_error error)error{
        if walk_error!=nil{return walk_error};if path==dir{return nil}
        relative,e:=filepath.Rel(dir,path);if e!=nil{return e};relative=filepath.ToSlash(relative)
        if entry.IsDir(){fmt.Fprintf(digest,"d%s\x00",relative);return nil}
        info,e:=entry.Info();if e!=nil{return e}
        if !info.Mode().IsRegular(){return fmt.Errorf("reference contains a non-regular file: %s",relative)}
        fmt.Fprintf(digest,"f%s\x00%d\x00",relative,info.Size())
        file,e:=os.Open(path);if e!=nil{return e}
        size,read_error:=io.Copy(digest,file)
        close_error:=file.Close()
        if read_error!=nil{return read_error};if close_error!=nil{return close_error}
        if size!=info.Size(){return fmt.Errorf("reference changed while hashing %s",relative)}
        return nil
    })
    if err!=nil{return "",err}
    return fmt.Sprintf("%08x",digest.Sum32()),nil
}
