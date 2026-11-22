/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */

package regression

import (
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"reflect"
	"strconv"
	"strings"
	"testing"
	"time"
)

type recordedCommand struct {
	program string
	args    []string
	env     []string
	stdin   []byte
	limit   int
}

type recordingRunner struct {
	calls []recordedCommand
	out   []byte
	err   error
}

type localRemoteShellRunner struct {
	calls int
	err   error
}

func (r *localRemoteShellRunner) Run(ctx context.Context, _ string, args, _ []string, input []byte, _ int) ([]byte, error) {
	r.calls++
	if r.err != nil {
		return nil, r.err
	}
	if len(args) == 0 {
		return nil, fmt.Errorf("missing remote command")
	}
	command := exec.CommandContext(ctx, "sh", "-c", args[len(args)-1])
	command.Stdin = bytes.NewReader(input)
	return command.CombinedOutput()
}

func (r *recordingRunner) Run(_ context.Context, program string, args, env []string, input []byte, limit int) ([]byte, error) {
	r.calls = append(r.calls, recordedCommand{program: program, args: append([]string(nil), args...), env: append([]string(nil), env...), stdin: append([]byte(nil), input...), limit: limit})
	return append([]byte(nil), r.out...), r.err
}

func testSSHRemote(runner MiSTerCommandRunner) MiSTerSSHRemote {
	return MiSTerSSHRemote{Config: MiSTerSSHConfig{Host: "mister.home", User: "root", Port: 22,
		IdentityFile: "/tmp/test-key", KnownHostsFile: "/tmp/known_hosts", SSH: "ssh", SCP: "scp", Timeout: 5 * time.Second}, Runner: runner}
}

func TestMiSTerSSHRemoteUsesArgvAndQuotesRemoteCommand(t *testing.T) {
	runner := &recordingRunner{}
	remote := testSSHRemote(runner)
	if err := remote.WriteFIFO(context.Background(), []byte("cab_stop session-1\n"), 3*time.Second); err != nil {
		t.Fatal(err)
	}
	if len(runner.calls) != 1 {
		t.Fatalf("got %d process calls, want one", len(runner.calls))
	}
	call := runner.calls[0]
	if call.program != "ssh" || len(call.args) < 4 || call.args[len(call.args)-3] != "--" || call.args[len(call.args)-1] == "" {
		t.Fatalf("SSH argv was not constructed as a direct process call: %+v", call)
	}
	remoteCommand := call.args[len(call.args)-1]
	if !strings.Contains(remoteCommand, "timeout -k 1s 2s") || !strings.Contains(remoteCommand, "cab_stop session-1") || !strings.Contains(remoteCommand, "/dev/MiSTer_cmd") {
		t.Fatalf("bounded FIFO wrapper missing: %q", remoteCommand)
	}
	if err := remote.WriteFIFO(context.Background(), []byte("load_core /media/fat/_Arcade/a b'c.mra\n"), 3*time.Second); err != nil {
		t.Fatal("shell metacharacters in a single FIFO record were not safely quoted", err)
	}
	if want := "'load_core /media/fat/_Arcade/a b'\\''c.mra\n'"; shellQuote("load_core /media/fat/_Arcade/a b'c.mra\n") != want {
		t.Fatalf("shell quoting failed for space/quote-bearing FIFO record: got %q want %q", shellQuote("load_core /media/fat/_Arcade/a b'c.mra\n"), want)
	}
	for _, arg := range call.args {
		if strings.Contains(arg, "cab_stop") && arg != remoteCommand {
			t.Fatalf("remote command escaped its single SSH argument: %+v", call.args)
		}
	}
}

func TestMiSTerSSHRemoteRemoves32OwnedImagesInOneVerifiedBatch(t *testing.T) {
	root := t.TempDir()
	files := make([]miSTerOwnedRemoteFile, 32)
	for index := range files {
		name := fmt.Sprintf("image-%02d ' $ ;.png", index)
		path := filepath.Join(root, name)
		data := []byte(fmt.Sprintf("frame-%04d", index))
		if err := os.WriteFile(path, data, 0600); err != nil {
			t.Fatal(err)
		}
		files[index] = miSTerOwnedRemoteFile{Path: path, SHA256: digestBytes(data), Owned: true}
	}
	runner := &localRemoteShellRunner{}
	remote := testSSHRemote(runner)
	if err := removeOwnedMiSTerFiles(context.Background(), remote, files); err != nil {
		t.Fatal(err)
	}
	if runner.calls != 1 {
		t.Fatalf("32 image removals used %d SSH calls, want one bounded batch", runner.calls)
	}
	for _, file := range files {
		if _, err := os.Lstat(file.Path); !os.IsNotExist(err) {
			t.Fatalf("verified owned image remains or has unexpected stat error: %s (%v)", file.Path, err)
		}
	}
}

func TestMiSTerSSHRemoteBatchVerifiesAllHashesBeforeDeleting(t *testing.T) {
	root := t.TempDir()
	first, second := filepath.Join(root, "first.png"), filepath.Join(root, "second.png")
	if err := os.WriteFile(first, []byte("first"), 0600); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(second, []byte("second"), 0600); err != nil {
		t.Fatal(err)
	}
	runner := &localRemoteShellRunner{}
	remote := testSSHRemote(runner)
	files := []miSTerOwnedRemoteFile{{Path: first, SHA256: digestBytes([]byte("first"))}, {Path: second, SHA256: digestBytes([]byte("wrong"))}}
	if err := remote.RemoveOwnedBatch(context.Background(), files); err == nil {
		t.Fatal("changed second file was accepted")
	}
	if runner.calls != 1 {
		t.Fatalf("changed hash caused %d SSH calls, want one preflight batch", runner.calls)
	}
	for _, name := range []string{first, second} {
		if _, err := os.Stat(name); err != nil {
			t.Fatalf("preflight mismatch deleted a file before verifying the full batch: %s: %v", name, err)
		}
	}
}

func TestMiSTerSSHRemoteBatchDistinguishesMissingFilesAndTransportErrors(t *testing.T) {
	root := t.TempDir()
	present := filepath.Join(root, "present.png")
	if err := os.WriteFile(present, []byte("present"), 0600); err != nil {
		t.Fatal(err)
	}
	runner := &localRemoteShellRunner{}
	remote := testSSHRemote(runner)
	missing := filepath.Join(root, "already-absent.png")
	files := []miSTerOwnedRemoteFile{{Path: missing, SHA256: digestBytes([]byte("absent"))}, {Path: present, SHA256: digestBytes([]byte("present"))}}
	if err := remote.RemoveOwnedBatch(context.Background(), files); err != nil {
		t.Fatalf("missing owned file should be an idempotent no-op, not an SSH error: %v", err)
	}
	if _, err := os.Lstat(present); !os.IsNotExist(err) {
		t.Fatalf("present file was not removed after missing-file check: %v", err)
	}
	transportErr := errors.New("simulated SSH transport failure")
	runner.err = transportErr
	if err := remote.RemoveOwnedBatch(context.Background(), []miSTerOwnedRemoteFile{{Path: present, SHA256: digestBytes([]byte("present"))}}); !errors.Is(err, transportErr) {
		t.Fatalf("SSH transport failure was confused with an absent file: %v", err)
	}
	if runner.calls != 2 {
		t.Fatalf("batch call count is %d, want one per invocation", runner.calls)
	}
}

func TestMiSTerSSHRemoteBatchRejectsEmptyHashWithoutDeleting(t *testing.T) {
	root := t.TempDir()
	name := filepath.Join(root, "keep.png")
	if err := os.WriteFile(name, []byte("keep"), 0600); err != nil {
		t.Fatal(err)
	}
	runner := &localRemoteShellRunner{}
	remote := testSSHRemote(runner)
	if err := remote.RemoveOwnedBatch(context.Background(), []miSTerOwnedRemoteFile{{Path: name}}); err == nil {
		t.Fatal("empty expected hash was accepted")
	}
	if runner.calls != 0 {
		t.Fatalf("invalid ownership launched %d SSH calls", runner.calls)
	}
	if _, err := os.Stat(name); err != nil {
		t.Fatalf("invalid ownership removed a file: %v", err)
	}
}

func TestMiSTerSCPArgumentsKeepLocalNamesWithSpacesAndQuotesInArgv(t *testing.T) {
	remote := testSSHRemote(&recordingRunner{})
	local := "/tmp/MRA 'quoted' ; literal.mra"
	remotePath := "/media/fat/_Arcade/space ; $ `touch /tmp/scp-injected` ' quoted.mra"
	args := remote.scpArgs(local, "root@mister.home:"+remotePath)
	if !contains(args, "-O") {
		t.Fatalf("SCP must use the legacy protocol supported by MiSTer SSH servers: %#v", args)
	}
	if !contains(args, local) {
		t.Fatalf("local path was not kept intact in SCP argv: %#v", args)
	}
	if !contains(args, "root@mister.home:"+shellQuote(remotePath)) {
		t.Fatalf("remote -O path was not quoted for the remote shell: %#v", args)
	}
	if strings.Contains(args[len(args)-1], "touch /tmp/scp-injected") && !strings.Contains(args[len(args)-1], "'\\''") {
		t.Fatal("remote shell metacharacters were passed without quoting")
	}
}

func TestMiSTerSCPLegacyPortableDownloadAndShellSafety(t *testing.T) {
	remote := testSSHRemote(&recordingRunner{})
	for _, path := range []string{"/media/fat/screenshots/circusc/20261118_015040-cabcap_j232-circusc-6_01f4.png", "/tmp/jtframe-capture-a-00001.receipt.json"} {
		args := remote.scpArgs("root@mister.home:"+path, "/tmp/output")
		if !contains(args, "-O") || contains(args, "-T") || !contains(args, "root@mister.home:"+path) { t.Fatalf("portable source changed or strict check disabled: %#v", args) }
	}
	for _, path := range []string{"/tmp/space name", "/tmp/glob*", "/tmp/$(touch x)", "/tmp/a'b", "/tmp/a;id", "/tmp/`id`"} {
		args := remote.scpArgs("root@mister.home:"+path, "/tmp/output")
		if !contains(args, "root@mister.home:"+shellQuote(path)) { t.Fatalf("unsafe source not shell-quoted: %#v", args) }
	}
}

func TestMiSTerProbeRecordsActualHostnameInsteadOfSSHAlias(t *testing.T) {
	runner := &recordingRunner{out: []byte("M\t101\t/media/fat/Main\t" + strings.Repeat("a", 64) + "\tcircus\tJTFRAME\t/media/fat/circus.rbf\t/media/fat/circus.mra\toperating\nH\tmister-real.local\nB\t/sys/class/fpga_bridge/br0/state\tenabled\n")}
	remote := testSSHRemote(runner)
	snapshot, err := remote.Probe(context.Background())
	if err != nil {
		t.Fatal(err)
	}
	if snapshot.HostName != "mister-real.local" || remote.Config.Host == snapshot.HostName {
		t.Fatalf("probe did not retain actual hostname separately from SSH alias: snapshot=%+v alias=%q", snapshot, remote.Config.Host)
	}
}

func TestMiSTerRemoveEmptyDirIsNonRecursiveAndPreservesPreexistingContents(t *testing.T) {
	remotePath := "/media/fat/screenshots/circusc"
	localPath := filepath.Join(t.TempDir(), "circusc")
	if err := os.Mkdir(localPath, 0700); err != nil {
		t.Fatal(err)
	}
	runner := &localShellRemoteRunner{targetPath: remotePath, localPath: localPath}
	remote := testSSHRemote(runner)
	if err := os.WriteFile(filepath.Join(localPath, "keep.png"), []byte("preexisting"), 0600); err != nil {
		t.Fatal(err)
	}
	if err := remote.RemoveEmptyDir(context.Background(), remotePath); err == nil {
		t.Fatal("nonempty screenshot directory was removed")
	}
	if _, err := os.Stat(filepath.Join(localPath, "keep.png")); err != nil {
		t.Fatalf("nonempty directory content changed: %v", err)
	}
	if err := os.Remove(filepath.Join(localPath, "keep.png")); err != nil {
		t.Fatal(err)
	}
	if err := remote.RemoveEmptyDir(context.Background(), remotePath); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(localPath); !os.IsNotExist(err) {
		t.Fatalf("empty owned directory remains: %v", err)
	}
}

func TestMiSTerSSHRemotePasswordIsChildEnvironmentOnly(t *testing.T) {
	const secret = "never-put-this-in-argv"
	t.Setenv("MISTERPASSWD", secret)
	runner := &recordingRunner{}
	remote := testSSHRemote(runner)
	remote.Config.PasswordEnv = "MISTERPASSWD"
	remote.Config.SSHPass = "sshpass"
	if err := remote.WriteFIFO(context.Background(), []byte("load_core /media/fat/_Arcade/a b'c.mra\n"), 3*time.Second); err != nil {
		t.Fatal("FIFO argument with shell metacharacters should remain one quoted record", err)
	}
	if err := remote.WriteFIFO(context.Background(), []byte("cab_stop session-1\n"), 3*time.Second); err != nil {
		t.Fatal(err)
	}
	call := runner.calls[0]
	if call.program != "sshpass" || len(call.args) == 0 || call.args[0] != "-e" {
		t.Fatalf("password transport did not use sshpass -e: %+v", call)
	}
	if !contains(call.env, "SSHPASS="+secret) {
		t.Fatal("child-only SSHPASS was not supplied")
	}
	for _, arg := range call.args {
		if strings.Contains(arg, secret) {
			t.Fatal("secret was placed in process arguments")
		}
	}
	if contains(call.args, "-oBatchMode=yes") || !contains(call.args, "-oBatchMode=no") {
		t.Fatalf("password route must explicitly disable BatchMode: %+v", call.args)
	}
}

func TestMiSTerSSHRemoteMissingPasswordFailsBeforeCommand(t *testing.T) {
	t.Setenv("JT_TEST_MISTER_PASSWORD_MISSING", "")
	runner := &recordingRunner{}
	remote := testSSHRemote(runner)
	remote.Config.PasswordEnv = "JT_TEST_MISTER_PASSWORD_MISSING"
	remote.Config.SSHPass = "sshpass"
	if err := remote.WriteFIFO(context.Background(), []byte("cab_stop session-1\n"), 3*time.Second); err == nil {
		t.Fatal("missing configured password should fail closed")
	}
	if len(runner.calls) != 0 {
		t.Fatal("missing credential unexpectedly invoked a process")
	}
}

func TestMiSTerProcessDiscoveryUsesLinuxProcFixture(t *testing.T) {
	tests := []struct {
		name      string
		comms     []string
		wantPID   string
		wantMatch bool
	}{
		{name: "Linux MiSTer comm", comms: []string{"MiSTer"}, wantPID: "101", wantMatch: true},
		{name: "supported Main alias", comms: []string{"Main"}, wantPID: "101", wantMatch: true},
		{name: "unrelated names", comms: []string{"main", "mister", "MiSTer-worker"}},
		{name: "one supported among unrelated", comms: []string{"worker", "MiSTer", "other"}, wantPID: "102", wantMatch: true},
		{name: "duplicate supported processes", comms: []string{"Main", "MiSTer"}},
	}
	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			procRoot := filepath.Join(t.TempDir(), "proc fixture")
			if err := os.Mkdir(procRoot, 0o700); err != nil {
				t.Fatal(err)
			}
			executable, err := exec.LookPath("sh")
			if err != nil {
				t.Fatal(err)
			}
			for index, comm := range test.comms {
				pid := 101 + index
				entry := filepath.Join(procRoot, fmt.Sprint(pid))
				if err := os.Mkdir(entry, 0o700); err != nil {
					t.Fatal(err)
				}
				if err := os.WriteFile(filepath.Join(entry, "comm"), []byte(comm+"\n"), 0o600); err != nil {
					t.Fatal(err)
				}
				if err := os.Symlink(executable, filepath.Join(entry, "exe")); err != nil {
					t.Fatal(err)
				}
			}
			script := "set -eu\n" + miSTerProcessDiscoveryScript(procRoot) + `
exe="$(readlink -f "$proc_root/$pid/exe")"
sha="$(sha256sum "$proc_root/$pid/exe" | cut -d ' ' -f 1)"
printf '%s\t%s\t%s\n' "$pid" "$exe" "$sha"
`
			command := exec.Command("sh", "-c", script)
			output, err := command.CombinedOutput()
			if !test.wantMatch {
				if err == nil {
					t.Fatalf("ambiguous or unsupported process set selected a process: %q", output)
				}
				if exit, ok := err.(*exec.ExitError); !ok || exit.ExitCode() != 71 {
					t.Fatalf("process set did not fail with the exact-one-match code: output=%q err=%v", output, err)
				}
				return
			}
			if err != nil {
				t.Fatalf("supported process was not selected: output=%q err=%v", output, err)
			}
			fields := strings.Split(strings.TrimSpace(string(output)), "\t")
			if len(fields) != 3 || fields[0] != test.wantPID {
				t.Fatalf("wrong selected process: %q", output)
			}
			resolved, err := filepath.EvalSymlinks(executable)
			if err != nil {
				t.Fatal(err)
			}
			binary, err := os.ReadFile(resolved)
			if err != nil {
				t.Fatal(err)
			}
			wantHash := sha256.Sum256(binary)
			if fields[1] != resolved || fields[2] != hex.EncodeToString(wantHash[:]) {
				t.Fatalf("fixture executable identity mismatch: got=%q resolved=%q", fields, resolved)
			}
		})
	}
}

func TestMiSTerDiagnosticCachesAreOptional(t *testing.T) {
	cacheRoot := t.TempDir()
	corePath := filepath.Join(cacheRoot, "CORENAME")
	rbfPath := filepath.Join(cacheRoot, "RBFNAME")
	read := func() ([]string, error) {
		script := "set -eu\n" + miSTerDiagnosticCacheScript(corePath, rbfPath) + `
printf '%s\t%s\n' "$core" "$rbf"
`
		output, err := exec.Command("sh", "-c", script).CombinedOutput()
		return strings.Split(strings.TrimSuffix(string(output), "\n"), "\t"), err
	}
	values, err := read()
	if err != nil || !reflect.DeepEqual(values, []string{"", ""}) {
		t.Fatalf("missing diagnostic caches must not fail the probe: values=%q err=%v", values, err)
	}
	if err := os.WriteFile(corePath, []byte("circusc\r\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(rbfPath, []byte("jtcircus\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	values, err = read()
	if err != nil || !reflect.DeepEqual(values, []string{"circusc", "jtcircus"}) {
		t.Fatalf("present diagnostic caches should remain observable: values=%q err=%v", values, err)
	}
}

func TestMiSTerRemotePathAndFIFOBounds(t *testing.T) {
	badPaths := []string{"", "relative/file", "/tmp/../etc/passwd", "/media/fat/a\nother"}
	for _, candidate := range badPaths {
		if err := validMiSTerRemotePath(candidate); err == nil {
			t.Errorf("unsafe path accepted: %q", candidate)
		}
	}
	if err := validMiSTerRemotePath("/media/fat/games/mame/space ' quote ; $ archive.zip"); err != nil {
		t.Fatalf("printable archive basename should be safe under shell quoting: %v", err)
	}
	runner := &recordingRunner{}
	remote := testSSHRemote(runner)
	for _, record := range [][]byte{nil, []byte("cab_stop x"), []byte("cab_stop x\nother\n"), []byte("bad\x00\n"), make([]byte, 1024)} {
		if err := remote.WriteFIFO(context.Background(), record, 3*time.Second); err == nil {
			t.Errorf("invalid FIFO record accepted: %q", record)
		}
	}
	if len(runner.calls) != 0 {
		t.Fatal("invalid FIFO record invoked SSH")
	}
}

func TestMiSTerExecRunnerMergesOnlyChildEnvironment(t *testing.T) {
	t.Setenv("JTFRAME_TEST_OVERRIDE", "parent")
	runner := MiSTerExecRunner{}
	output, err := runner.Run(context.Background(), "/usr/bin/printenv", []string{"JTFRAME_TEST_OVERRIDE"}, []string{"JTFRAME_TEST_OVERRIDE=child"}, nil, 4096)
	if err != nil {
		t.Fatal(err)
	}
	if string(output) != "child\n" {
		t.Fatalf("child override missing from subprocess environment: %q", output)
	}
	if os.Getenv("JTFRAME_TEST_OVERRIDE") != "parent" {
		t.Fatal("child environment override modified parent process environment")
	}
	if !reflect.DeepEqual(mergeEnvironment([]string{"A=1", "B=2"}, []string{"A=3", "C=4"}), []string{"A=3", "B=2", "C=4"}) {
		t.Fatal("environment merge did not replace child variable deterministically")
	}
}

func TestMiSTerExecRunnerKeepsBinaryStdoutSeparateFromStderr(t *testing.T) {
	runner := MiSTerExecRunner{}
	want := []byte{0x00, 0xff, '\n', 'X'}
	output, err := runner.Run(context.Background(), "/bin/sh", []string{"-c", "printf '\\000\\377\\nX'; printf 'diagnostic' >&2"}, nil, nil, 64)
	if err != nil {
		t.Fatal(err)
	}
	if !bytes.Equal(output, want) {
		t.Fatalf("stdout was mixed with diagnostics or changed: got %v, want %v", output, want)
	}
	if _, err = runner.Run(context.Background(), "/bin/sh", []string{"-c", "printf abc; printf def >&2"}, nil, nil, 5); err == nil || !strings.Contains(err.Error(), "combined output exceeded 5 bytes") {
		t.Fatalf("combined stdout/stderr limit was not enforced: %v", err)
	}
}

type localShellRemoteRunner struct {
	targetPath      string
	localPath       string
	replacementPath string
	swapAfterCall   int
	swapInsideHead  bool
	calls           int
	lastCommand     string
	lastMaxOutput   int
}

type localWriteFileRunner struct {
	remotePath  string
	localPath   string
	chmodMarker string
	chmodFails  bool
	failMove    bool
	lastCommand string
}

func (r *localWriteFileRunner) Run(ctx context.Context, program string, args, env []string, input []byte, maxOutput int) ([]byte, error) {
	if program != "ssh" || len(args) == 0 {
		return nil, fmt.Errorf("unexpected local WriteFile invocation")
	}
	commandText := strings.ReplaceAll(args[len(args)-1], r.remotePath, r.localPath)
	if strings.Contains(commandText, "sha256sum") {
		return []byte("MISSING\n"), nil
	}
	if r.failMove && strings.Contains(commandText, "mv -f --") {
		commandText = strings.Replace(commandText, "&& mv -f --", "&& false #", 1)
	}
	r.lastCommand = commandText
	binDir, err := os.MkdirTemp(filepath.Dir(r.localPath), "chmod-shim-")
	if err != nil {
		return nil, err
	}
	defer os.RemoveAll(binDir)
	chmod := "#!/bin/sh\nprintf called > " + shellQuote(r.chmodMarker) + "\n"
	if r.chmodFails {
		chmod += "exit 71\n"
	} else {
		chmod += "exec /bin/chmod \"$@\"\n"
	}
	if err = os.WriteFile(filepath.Join(binDir, "chmod"), []byte(chmod), 0700); err != nil {
		return nil, err
	}
	command := exec.CommandContext(ctx, "/bin/sh", "-c", commandText)
	command.Env = append(append([]string(nil), env...), "PATH="+binDir+string(os.PathListSeparator)+os.Getenv("PATH"))
	command.Stdin = bytes.NewReader(input)
	var stdout, stderr bytes.Buffer
	command.Stdout, command.Stderr = &stdout, &stderr
	err = command.Run()
	if stdout.Len()+stderr.Len() > maxOutput {
		return nil, fmt.Errorf("local WriteFile shell output exceeded %d bytes", maxOutput)
	}
	if err != nil {
		return nil, fmt.Errorf("local WriteFile shell failed: %w", err)
	}
	return append([]byte(nil), stdout.Bytes()...), nil
}

func TestMiSTerWriteFileAvoidsFATChmodAndKeepsUnixTempPrivate(t *testing.T) {
	t.Run("exfat target succeeds when chmod is unsupported", func(t *testing.T) {
		dir := t.TempDir()
		remotePath := "/media/fat/config/circusc.CFG"
		localPath := filepath.Join(dir, "circusc.CFG")
		marker := filepath.Join(dir, "chmod-called")
		runner := &localWriteFileRunner{remotePath: remotePath, localPath: localPath,
			chmodMarker: marker, chmodFails: true}
		remote := testSSHRemote(runner)
		want := []byte("native-video-status\n")
		if err := remote.WriteFile(context.Background(), remotePath, want); err != nil {
			t.Fatal(err)
		}
		got, err := os.ReadFile(localPath)
		if err != nil || !bytes.Equal(got, want) {
			t.Fatalf("published file bytes=%q err=%v", got, err)
		}
		if _, err = os.Lstat(marker); !os.IsNotExist(err) {
			t.Fatalf("FAT path invoked unsupported chmod; marker stat err=%v", err)
		}
		for _, fragment := range []string{"umask 077", "set -C", "cat >", "mv -f --"} {
			if !strings.Contains(runner.lastCommand, fragment) {
				t.Fatalf("atomic write script lost %q: %s", fragment, runner.lastCommand)
			}
		}
		if strings.Contains(runner.lastCommand, "chmod 0600") {
			t.Fatalf("exFAT write still depends on chmod: %s", runner.lastCommand)
		}
	})
	t.Run("Unix temp remains private from umask", func(t *testing.T) {
		dir := t.TempDir()
		remotePath := "/tmp/jtframe-test/status.json"
		localPath := filepath.Join(dir, "status.json")
		runner := &localWriteFileRunner{remotePath: remotePath, localPath: localPath,
			chmodMarker: filepath.Join(dir, "chmod-called"), chmodFails: false}
		remote := testSSHRemote(runner)
		if err := remote.WriteFile(context.Background(), remotePath, []byte("private\n")); err != nil {
			t.Fatal(err)
		}
		info, err := os.Stat(localPath)
		if err != nil {
			t.Fatal(err)
		}
		if got := info.Mode().Perm(); got != 0600 {
			t.Fatalf("Unix destination mode=%#o, want 0600 from umask 077", got)
		}
		if strings.Contains(runner.lastCommand, "chmod 0600") {
			t.Fatalf("umask-private Unix write should not require chmod: %s", runner.lastCommand)
		}
	})
}

func TestMiSTerWriteFileRemovesTemporaryAfterFailedPublish(t *testing.T) {
	dir := t.TempDir()
	remotePath := "/media/fat/config/circusc.CFG"
	localPath := filepath.Join(dir, "circusc.CFG")
	runner := &localWriteFileRunner{remotePath: remotePath, localPath: localPath, failMove: true}
	remote := testSSHRemote(runner)
	if err := remote.WriteFile(context.Background(), remotePath, []byte("must not publish")); err == nil {
		t.Fatal("failed atomic publish unexpectedly succeeded")
	}
	entries, err := os.ReadDir(dir)
	if err != nil {
		t.Fatal(err)
	}
	if len(entries) != 0 {
		t.Fatalf("failed write left local stand-in for remote .tmp file: %v", entries)
	}
}

func (r *localShellRemoteRunner) Run(ctx context.Context, program string, args, env []string, input []byte, maxOutput int) ([]byte, error) {
	if program != "ssh" || len(args) == 0 || len(input) != 0 {
		return nil, fmt.Errorf("unexpected local shell remote invocation")
	}
	r.calls++
	r.lastMaxOutput = maxOutput
	commandText := strings.ReplaceAll(args[len(args)-1], r.targetPath, r.localPath)
	r.lastCommand = commandText
	binDir := ""
	if r.swapInsideHead && strings.Contains(commandText, "head -c ") {
		var err error
		binDir, err = os.MkdirTemp(filepath.Dir(r.localPath), "head-shim-")
		if err != nil {
			return nil, err
		}
		defer os.RemoveAll(binDir)
		head := "#!/bin/sh\nmv -- " + shellQuote(r.replacementPath) + " " + shellQuote(r.localPath) + "\nexec /usr/bin/head \"$@\"\n"
		if err = os.WriteFile(filepath.Join(binDir, "head"), []byte(head), 0700); err != nil {
			return nil, err
		}
	}
	command := exec.CommandContext(ctx, "/bin/sh", "-c", commandText)
	command.Env = append(os.Environ(), env...)
	if binDir != "" {
		command.Env = append(command.Env, "PATH="+binDir+string(os.PathListSeparator)+os.Getenv("PATH"))
	}
	command.Stdin = bytes.NewReader(input)
	var stdout, stderr bytes.Buffer
	command.Stdout, command.Stderr = &stdout, &stderr
	err := command.Run()
	combined := stdout.Len() + stderr.Len()
	if combined > maxOutput {
		return nil, fmt.Errorf("local shell output exceeded %d bytes", maxOutput)
	}
	if err != nil {
		return nil, fmt.Errorf("local shell command failed: %w", err)
	}
	if r.swapAfterCall == r.calls {
		if err = os.Rename(r.replacementPath, r.localPath); err != nil {
			return nil, err
		}
	}
	return append([]byte(nil), stdout.Bytes()...), nil
}

func TestMiSTerFileLegacySeparateOpensReproduceAtomicReplaceMismatch(t *testing.T) {
	dir := t.TempDir()
	remotePath := "/media/fat/config/status.json"
	localPath := filepath.Join(dir, "status.json")
	replacement := filepath.Join(dir, "replacement.json")
	oldData := []byte(`{"state":"old"}`)
	newData := []byte(`{"state":"running","generation":2}`)
	if err := os.WriteFile(localPath, oldData, 0600); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(replacement, newData, 0600); err != nil {
		t.Fatal(err)
	}
	runner := &localShellRemoteRunner{targetPath: remotePath, localPath: localPath, replacementPath: replacement, swapAfterCall: 1}
	remote := testSSHRemote(runner)
	sizeOut, err := remote.runSSH(context.Background(), "if [ -L "+shellQuote(remotePath)+" ]; then exit 74; elif [ -f "+shellQuote(remotePath)+" ]; then wc -c < "+shellQuote(remotePath)+"; else printf 'MISSING\\n'; fi", nil, 128)
	if err != nil {
		t.Fatal(err)
	}
	size, err := strconv.ParseInt(strings.TrimSpace(string(sizeOut)), 10, 64)
	if err != nil || size != int64(len(oldData)) {
		t.Fatalf("first local file read did not observe original size: size=%d err=%v", size, err)
	}
	newRead, err := remote.runSSH(context.Background(), "cat -- "+shellQuote(remotePath), nil, 1024)
	if err != nil {
		t.Fatal(err)
	}
	if size == int64(len(newRead)) {
		t.Fatalf("replacement race not reproduced: initial size=%d later bytes=%d", size, len(newRead))
	}
	if !bytes.Equal(newRead, newData) {
		t.Fatal("second local file read did not observe the atomically replaced file")
	}
}

func TestMiSTerFileReadsOneOpenedSnapshotAcrossAtomicReplace(t *testing.T) {
	dir := t.TempDir()
	remotePath := "/media/fat/config/status.json"
	localPath := filepath.Join(dir, "status.json")
	replacement := filepath.Join(dir, "replacement.json")
	oldData := []byte{0, '{', '\n', 0xff, '}', 0}
	newData := []byte(`{"state":"new"}`)
	if err := os.WriteFile(localPath, oldData, 0600); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(replacement, newData, 0600); err != nil {
		t.Fatal(err)
	}
	runner := &localShellRemoteRunner{targetPath: remotePath, localPath: localPath, replacementPath: replacement, swapInsideHead: true}
	remote := testSSHRemote(runner)
	got, exists, err := remote.File(context.Background(), remotePath, 1024)
	if err != nil || !exists {
		t.Fatalf("atomic replacement during opened-file read failed: exists=%v err=%v", exists, err)
	}
	if !bytes.Equal(got, oldData) {
		t.Fatalf("read did not remain bound to opened inode: got %v want %v", got, oldData)
	}
	if runner.calls != 1 {
		t.Fatalf("File used %d remote shell calls; want one opened-file transaction", runner.calls)
	}
	if !strings.Contains(runner.lastCommand, "exec 3<") || !strings.Contains(runner.lastCommand, "head -c 1025 <&3") {
		t.Fatalf("bounded opened-file read command missing from shell transaction: %q", runner.lastCommand)
	}
}

func TestMiSTerFileDistinguishesMissingEmptyBinaryAndOversize(t *testing.T) {
	dir := t.TempDir()
	remotePath := "/media/fat/config/status.json"
	localPath := filepath.Join(dir, "status.json")
	t.Run("missing", func(t *testing.T) {
		runner := &localShellRemoteRunner{targetPath: remotePath, localPath: localPath}
		got, exists, err := testSSHRemote(runner).File(context.Background(), remotePath, 32)
		if err != nil || exists || got != nil {
			t.Fatalf("missing file result=%v exists=%v err=%v", got, exists, err)
		}
	})
	t.Run("maximum payload limit includes bounded framing", func(t *testing.T) {
		runner := &localShellRemoteRunner{targetPath: remotePath, localPath: localPath}
		got, exists, err := testSSHRemote(runner).File(context.Background(), remotePath, miSTerRemoteOutputLimit)
		if err != nil || exists || got != nil {
			t.Fatalf("maximum-limit missing result=%v exists=%v err=%v", got, exists, err)
		}
		if runner.lastMaxOutput != miSTerRemoteCommandOutputLimit {
			t.Fatalf("remote transport cap=%d, want payload cap plus exact framing=%d", runner.lastMaxOutput, miSTerRemoteCommandOutputLimit)
		}
	})
	t.Run("empty", func(t *testing.T) {
		if err := os.WriteFile(localPath, nil, 0600); err != nil {
			t.Fatal(err)
		}
		runner := &localShellRemoteRunner{targetPath: remotePath, localPath: localPath}
		got, exists, err := testSSHRemote(runner).File(context.Background(), remotePath, 32)
		if err != nil || !exists || len(got) != 0 {
			t.Fatalf("empty file result=%v exists=%v err=%v", got, exists, err)
		}
	})
	t.Run("binary", func(t *testing.T) {
		want := []byte{0, 0xff, '\n', 'P', 'R', 'E', 'S', 'E', 'N', 'T', '\n', 0}
		if err := os.WriteFile(localPath, want, 0600); err != nil {
			t.Fatal(err)
		}
		runner := &localShellRemoteRunner{targetPath: remotePath, localPath: localPath}
		got, exists, err := testSSHRemote(runner).File(context.Background(), remotePath, 32)
		if err != nil || !exists || !bytes.Equal(got, want) {
			t.Fatalf("binary file result=%v exists=%v err=%v, want exact bytes %v", got, exists, err, want)
		}
	})
	t.Run("oversize bounded at limit plus one", func(t *testing.T) {
		if err := os.WriteFile(localPath, []byte("123456"), 0600); err != nil {
			t.Fatal(err)
		}
		runner := &localShellRemoteRunner{targetPath: remotePath, localPath: localPath}
		got, exists, err := testSSHRemote(runner).File(context.Background(), remotePath, 5)
		if err == nil || !exists || got != nil || !strings.Contains(err.Error(), "at least 6 bytes") || !strings.Contains(err.Error(), "maximum 5") {
			t.Fatalf("oversize result=%v exists=%v err=%v", got, exists, err)
		}
	})
	t.Run("symlink rejected", func(t *testing.T) {
		if err := os.Remove(localPath); err != nil && !os.IsNotExist(err) {
			t.Fatal(err)
		}
		target := filepath.Join(dir, "target")
		if err := os.WriteFile(target, []byte("safe"), 0600); err != nil {
			t.Fatal(err)
		}
		if err := os.Symlink(target, localPath); err != nil {
			t.Fatal(err)
		}
		runner := &localShellRemoteRunner{targetPath: remotePath, localPath: localPath}
		if got, exists, err := testSSHRemote(runner).File(context.Background(), remotePath, 32); err == nil || exists || got != nil {
			t.Fatalf("symlink result=%v exists=%v err=%v", got, exists, err)
		}
	})
	t.Run("nonregular rejected", func(t *testing.T) {
		if err := os.Remove(localPath); err != nil && !os.IsNotExist(err) {
			t.Fatal(err)
		}
		if err := os.Mkdir(localPath, 0700); err != nil {
			t.Fatal(err)
		}
		runner := &localShellRemoteRunner{targetPath: remotePath, localPath: localPath}
		if got, exists, err := testSSHRemote(runner).File(context.Background(), remotePath, 32); err == nil || exists || got != nil {
			t.Fatalf("nonregular result=%v exists=%v err=%v", got, exists, err)
		}
	})
}

func contains(values []string, want string) bool {
	for _, value := range values {
		if value == want {
			return true
		}
	}
	return false
}
