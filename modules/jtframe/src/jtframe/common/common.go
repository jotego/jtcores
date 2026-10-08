/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 4-1-2025 */

package common

import (
	"fmt"
	"errors"
	"os"
	"os/exec"
	"strings"
	"path/filepath"
)

func Must( e error ) {
	if e!=nil {
		fmt.Fprintln(os.Stderr,e)
		os.Exit(1)
	}
}

func MustContext( e error, context string ) {
	if e!=nil {
		fmt.Printf("%s\n%s\n",context,e.Error())
		os.Exit(1)
	}
}

func ConfigFilePath(core, file string) (full_path string) {
	if core=="" {
		panic(fmt.Errorf("Blank core name not valid"))
	}
	return filepath.Join(os.Getenv("JTROOT"),"cores",core,"cfg",file)
}

func MakeJTpath(parts...string) string {
	jtroot := os.Getenv("JTROOT")
	leaf := filepath.Join(parts...)
	return filepath.Join(jtroot,leaf)
}

func Doc2string(doc string) string {
	jtframe := os.Getenv("JTFRAME")
	fname := filepath.Join(jtframe,"doc",doc)
	buf, e := os.ReadFile(fname)
	Must(e)
	return string(buf)
}

func FindFileInFolders( fname string, all_paths []string ) (string, error) {
	for _, path := range all_paths {
		fullpath := filepath.Join(path,fname)
		f, e := os.Open(fullpath)
		f.Close()
		if e==nil {
			return fullpath, nil
		}
	}
	return "",fmt.Errorf("Error cannot find file %s",fname)
}

func FileExists(fname string) bool {
	f, e := os.Open(fname)
	f.Close()
	return e == nil
}

// returns the first 7 hex digits of the commit
func GetCommit() (string,error) {
	jtroot := os.Getenv("JTROOT")
	cmd := exec.Command("git","-C",jtroot,"rev-parse","HEAD")
	cmd.Env = clean_git_env(os.Environ())
	output, e := cmd.Output()
	if e!=nil {
		return "0000000",fmt.Errorf("%s\n%s\n",string(output),e.Error())
	}
	commit:=string(output)
	return commit[0:7],nil
}

func clean_git_env(env []string) []string {
	local := map[string]bool{
		"GIT_ALTERNATE_OBJECT_DIRECTORIES": true,
		"GIT_CONFIG": true,
		"GIT_CONFIG_PARAMETERS": true,
		"GIT_CONFIG_COUNT": true,
		"GIT_OBJECT_DIRECTORY": true,
		"GIT_DIR": true,
		"GIT_WORK_TREE": true,
		"GIT_IMPLICIT_WORK_TREE": true,
		"GIT_GRAFT_FILE": true,
		"GIT_INDEX_FILE": true,
		"GIT_NO_REPLACE_OBJECTS": true,
		"GIT_REPLACE_REF_BASE": true,
		"GIT_PREFIX": true,
		"GIT_SHALLOW_FILE": true,
		"GIT_COMMON_DIR": true,
	}
	clean := make([]string, 0, len(env))
	for _, each := range env {
		name := each
		if eq := strings.IndexByte(each, '='); eq >= 0 {
			name = each[:eq]
		}
		if !local[name] {
			clean = append(clean, each)
		}
	}
	return clean
}

func ShowErrors( all_errors... error ) {
	for _, e := range all_errors {
		if e==nil { continue }
		fmt.Println(e)
	}
}

func JoinErrors( all_errors... error ) error {
	var sb strings.Builder
	for _, e := range all_errors {
		if e!=nil {
			if sb.Len()>0 {
				sb.WriteString("\n")
			}
			sb.WriteString(e.Error())
		}
	}
	if sb.Len()>0 {
		return errors.New(sb.String())
	} else {
		return nil
	}
}