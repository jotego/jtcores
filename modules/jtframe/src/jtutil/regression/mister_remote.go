/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */

package regression

import (
	"bytes"
	"context"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"time"
)

const (
	miSTerRemoteOutputLimit        = 2 << 20
	miSTerRemoteFileFrameOverhead  = len("PRESENT\n") + 1
	miSTerRemoteCommandOutputLimit = miSTerRemoteOutputLimit + miSTerRemoteFileFrameOverhead
	miSTerOwnedFileBatchMax        = capturePlanMaxEntries + 32
)

// MiSTerCommandRunner makes ssh/scp invocations replaceable in tests.
// Implementations must cap combined output and honor ctx cancellation.
type MiSTerCommandRunner interface {
	Run(context.Context, string, []string, []string, []byte, int) ([]byte, error)
}

// MiSTerExecRunner runs local ssh/scp processes without a shell. It stores no
// credentials; OpenSSH key/agent configuration remains external to the driver.
type MiSTerExecRunner struct{}

func (MiSTerExecRunner) Run(ctx context.Context, program string, args, env []string, input []byte, maxOutput int) ([]byte, error) {
	if maxOutput < 1 {
		return nil, fmt.Errorf("process output limit must be positive")
	}
	command := exec.CommandContext(ctx, program, args...)
	command.Env = mergeEnvironment(os.Environ(), env)
	command.Stdin = bytes.NewReader(input)
	output := &limitedCommandOutput{limit: maxOutput}
	command.Stdout, command.Stderr = output.stream(false), output.stream(true)
	err := command.Run()
	if output.exceeded {
		return nil, fmt.Errorf("%s combined output exceeded %d bytes", filepath.Base(program), maxOutput)
	}
	if err != nil {
		return nil, fmt.Errorf("%s failed: %w", filepath.Base(program), err)
	}
	return append([]byte(nil), output.stdout...), nil
}

type limitedCommandOutput struct {
	mu       sync.Mutex
	limit    int
	total    int
	stdout   []byte
	exceeded bool
}

type limitedCommandStream struct {
	owner  *limitedCommandOutput
	stderr bool
}

func (w *limitedCommandOutput) stream(stderr bool) io.Writer {
	return limitedCommandStream{owner: w, stderr: stderr}
}

func (s limitedCommandStream) Write(data []byte) (int, error) {
	w := s.owner
	w.mu.Lock()
	defer w.mu.Unlock()
	if w.total+len(data) > w.limit {
		w.exceeded = true
		return 0, fmt.Errorf("output limit exceeded")
	}
	w.total += len(data)
	if !s.stderr {
		w.stdout = append(w.stdout, data...)
	}
	return len(data), nil
}

func mergeEnvironment(base, overrides []string) []string {
	result := make([]string, 0, len(base)+len(overrides))
	index := make(map[string]int, len(base)+len(overrides))
	for _, entry := range base {
		name, _, ok := strings.Cut(entry, "=")
		if !ok {
			continue
		}
		index[name] = len(result)
		result = append(result, entry)
	}
	for _, entry := range overrides {
		name, _, ok := strings.Cut(entry, "=")
		if !ok {
			continue
		}
		if at, exists := index[name]; exists {
			result[at] = entry
		} else {
			index[name] = len(result)
			result = append(result, entry)
		}
	}
	return result
}

// MiSTerSSHConfig contains non-secret connection details and the name of an
// externally managed password variable. The value is passed only to a child
// sshpass process as SSHPASS and is never included in argv or diagnostics.
type MiSTerSSHConfig struct {
	Host           string
	User           string
	Port           int
	IdentityFile   string
	KnownHostsFile string
	SSH            string
	SCP            string
	SSHPass        string
	PasswordEnv    string
	Timeout        time.Duration
}

// MiSTerBoardSnapshot contains only the named values needed to verify the
// running Main/FPGA identity; raw argv, environment and config are not logged.
type MiSTerBoardSnapshot struct {
	MainPID      int
	HostName     string
	MainExePath  string
	MainSHA256   string
	CoreName     string
	RBFName      string
	ArgvRBF      string
	ArgvMRA      string
	FPGAState    string
	BridgeStates map[string]string
}

// MiSTerRemote is the bounded board I/O used by the session driver. The
// high-level methods make FIFO delivery, exact file ownership and tests
// explicit while the SSH implementation below supplies the concrete path.
type MiSTerRemote interface {
	Probe(context.Context) (MiSTerBoardSnapshot, error)
	FIFOReady(context.Context, int) (bool, error)
	ResolvePath(context.Context, string) (string, bool, error)
	PathExists(context.Context, string) (bool, error)
	MakeDir(context.Context, string) error
	CreateExclusive(context.Context, string, []byte) error
	Hash(context.Context, string) (string, bool, error)
	File(context.Context, string, int64) ([]byte, bool, error)
	WriteFile(context.Context, string, []byte) error
	Upload(context.Context, string, string, string) (bool, error)
	Download(context.Context, string, string, int64) error
	RemoveOwned(context.Context, string, string) error
	RemoveEmptyDir(context.Context, string) error
	WriteFIFO(context.Context, []byte, time.Duration) error
}

type miSTerOwnedFileBatchRemover interface {
	RemoveOwnedBatch(context.Context, []miSTerOwnedRemoteFile) error
}

// MiSTerSSHRemote is the production SSH/SCP transport. Board commands and all
// remote paths are passed as a single shell-quoted argument; local paths remain
// ordinary argv elements, so spaces and metacharacters cannot inject shell.
type MiSTerSSHRemote struct {
	Config MiSTerSSHConfig
	Runner MiSTerCommandRunner
}

// FIFOReady observes the currently named FIFO and the loaded Main's open
// descriptors without opening or reading the FIFO itself.
func (r MiSTerSSHRemote) FIFOReady(ctx context.Context, pid int) (bool, error) {
	if pid <= 0 {
		return false, fmt.Errorf("invalid Main PID")
	}
	script := miSTerFIFOReadyScript(pid, "/dev/MiSTer_cmd")
	output, err := r.runSSH(ctx, "sh -c "+shellQuote(script), nil, 32)
	if err != nil {
		return false, fmt.Errorf("inspect Main FIFO readiness: %w", err)
	}
	switch strings.TrimSpace(string(output)) {
	case "1":
		return true, nil
	case "0":
		return false, nil
	}
	return false, fmt.Errorf("invalid Main FIFO readiness response")
}

func miSTerFIFOReadyScript(pid int, fifo string) string {
	return `set -u
pid=` + strconv.Itoa(pid) + `
fifo=` + shellQuote(fifo) + `
[ -p "$fifo" ] || { echo 0; exit 0; }
target="$(stat -Lc '%d:%i' "$fifo" 2>/dev/null)" || { echo 0; exit 0; }
for fd in /proc/$pid/fd/*; do
  [ "$(stat -Lc '%d:%i' "$fd" 2>/dev/null)" = "$target" ] || continue
  flags="$(awk '/^flags:/ {print $2}' "/proc/$pid/fdinfo/${fd##*/}" 2>/dev/null)"
  case "$flags" in ''|*[!0-7]*) continue ;; esac
  [ $((0$flags & 010000000)) -eq 0 ] || continue
  mode=$((0$flags & 3))
  [ "$mode" -eq 0 ] || [ "$mode" -eq 2 ] || continue
  [ "$(stat -Lc '%d:%i' "$fd" 2>/dev/null)" = "$target" ] || continue
  [ "$(stat -Lc '%d:%i' "$fifo" 2>/dev/null)" = "$target" ] || break
  echo 1; exit 0
done
echo 0`
}

func (r MiSTerSSHRemote) validate() error {
	if !safeSSHHost(r.Config.Host) || !safeSSHUser(r.Config.User) || r.Config.Port < 1 || r.Config.Port > 65535 {
		return fmt.Errorf("invalid MiSTer SSH endpoint")
	}
	if r.Config.SSH == "" || r.Config.SCP == "" || r.Config.Timeout <= 0 || r.Config.Timeout > 5*time.Minute {
		return fmt.Errorf("MiSTer SSH binary and positive timeout are required")
	}
	if r.Config.PasswordEnv != "" && (!safeEnvironmentName(r.Config.PasswordEnv) || r.Config.SSHPass == "") {
		return fmt.Errorf("password authentication requires a named environment variable and sshpass binary")
	}
	if r.Runner == nil {
		return fmt.Errorf("MiSTer command runner is required")
	}
	for _, path := range []string{r.Config.IdentityFile, r.Config.KnownHostsFile} {
		if path != "" && !filepath.IsAbs(path) {
			return fmt.Errorf("SSH key and known-hosts paths must be absolute")
		}
	}
	return nil
}

func (r MiSTerSSHRemote) target() string { return r.Config.User + "@" + r.Config.Host }

func (r MiSTerSSHRemote) sshArgs(remoteCommand string) []string {
	args := []string{"-T", "-p", strconv.Itoa(r.Config.Port), "-oBatchMode=yes", "-oStrictHostKeyChecking=yes"}
	if r.Config.IdentityFile != "" {
		args = append(args, "-i", r.Config.IdentityFile)
	}
	if r.Config.KnownHostsFile != "" {
		args = append(args, "-oUserKnownHostsFile="+r.Config.KnownHostsFile)
	}
	return append(args, "--", r.target(), remoteCommand)
}

func (r MiSTerSSHRemote) authCommand(program string, args []string) (string, []string, []string, error) {
	if r.Config.PasswordEnv == "" {
		return program, args, nil, nil
	}
	password := os.Getenv(r.Config.PasswordEnv)
	if password == "" {
		return "", nil, nil, fmt.Errorf("password environment variable %s is not set", r.Config.PasswordEnv)
	}
	if len(password) > 4096 {
		return "", nil, nil, fmt.Errorf("password environment variable %s exceeds the bounded credential size", r.Config.PasswordEnv)
	}
	sshArgs := append([]string(nil), args...)
	for i := 0; i < len(sshArgs); i++ {
		if sshArgs[i] == "-oBatchMode=yes" {
			sshArgs[i] = "-oBatchMode=no"
		}
	}
	return r.Config.SSHPass, append([]string{"-e", program}, sshArgs...), []string{"SSHPASS=" + password}, nil
}

func (r MiSTerSSHRemote) runSSH(ctx context.Context, remoteCommand string, input []byte, limit int) ([]byte, error) {
	if err := r.validate(); err != nil {
		return nil, err
	}
	if limit <= 0 || limit > miSTerRemoteCommandOutputLimit {
		return nil, fmt.Errorf("remote output limit outside supported bound")
	}
	callCtx, cancel := context.WithTimeout(ctx, r.Config.Timeout)
	defer cancel()
	program, args, env, err := r.authCommand(r.Config.SSH, r.sshArgs(remoteCommand))
	if err != nil {
		return nil, err
	}
	return r.Runner.Run(callCtx, program, args, env, input, limit)
}

func (r MiSTerSSHRemote) Probe(ctx context.Context) (MiSTerBoardSnapshot, error) {
	var snapshot MiSTerBoardSnapshot
	// Only the named process identity/path fields are returned; raw command-line
	// arguments and environment values are never emitted to the host.
	script := `set -eu
` + miSTerProcessDiscoveryScript("/proc") + `
sha="$(sha256sum "/proc/$pid/exe" | cut -d ' ' -f 1)"
exe="$(readlink -f "/proc/$pid/exe")"
argv="$(tr '\000' '\n' < "/proc/$pid/cmdline")"
argv_rbf="$(printf '%s\n' "$argv" | sed -n '/\.rbf$/p' | tail -n 1)"
argv_mra="$(printf '%s\n' "$argv" | sed -n '/\.mra$/p' | tail -n 1)"
` + miSTerDiagnosticCacheScript("/tmp/CORENAME", "/tmp/RBFNAME") + `
hostname="$(hostname 2>/dev/null || true)"
fpga="$(tr -d '\r\n' < /sys/class/fpga_manager/fpga0/state)"
printf 'M\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$pid" "$exe" "$sha" "$core" "$rbf" "$argv_rbf" "$argv_mra" "$fpga"
printf 'H\t%s\n' "$hostname"
for state in /sys/class/fpga_bridge/*/state; do
  [ -r "$state" ] || continue
  printf 'B\t%s\t%s\n' "$state" "$(tr -d '\r\n' < "$state")"
done
`
	output, err := r.runSSH(ctx, "sh -c "+shellQuote(script), nil, 64<<10)
	if err != nil {
		return snapshot, fmt.Errorf("probe MiSTer Main/FPGA state: %w", err)
	}
	lines := strings.Split(strings.TrimSpace(string(output)), "\n")
	for _, line := range lines {
		fields := strings.Split(line, "\t")
		switch {
		case len(fields) == 2 && fields[0] == "H":
			if fields[1] != "" && (!safeSSHHost(fields[1]) || snapshot.HostName != "") {
				return snapshot, fmt.Errorf("invalid or duplicate actual MiSTer hostname")
			}
			snapshot.HostName = fields[1]
		case len(fields) == 9 && fields[0] == "M":
			pid, parseErr := strconv.Atoi(fields[1])
			if parseErr != nil || pid <= 0 || snapshot.MainPID != 0 {
				return snapshot, fmt.Errorf("invalid or duplicate Main probe record")
			}
			snapshot = MiSTerBoardSnapshot{MainPID: pid, MainExePath: fields[2], MainSHA256: fields[3], CoreName: fields[4], RBFName: fields[5],
				ArgvRBF: fields[6], ArgvMRA: fields[7], FPGAState: fields[8], BridgeStates: make(map[string]string)}
		case len(fields) == 3 && fields[0] == "B":
			if snapshot.BridgeStates == nil {
				snapshot.BridgeStates = make(map[string]string)
			}
			if _, duplicate := snapshot.BridgeStates[fields[1]]; duplicate {
				return snapshot, fmt.Errorf("duplicate FPGA bridge path")
			}
			snapshot.BridgeStates[fields[1]] = fields[2]
		default:
			return snapshot, fmt.Errorf("invalid named MiSTer probe record")
		}
	}
	if snapshot.MainPID == 0 || snapshot.HostName == "" || snapshot.MainExePath == "" || !strings.HasPrefix(snapshot.MainExePath, "/") || !isSHA256Hex(snapshot.MainSHA256) || len(snapshot.BridgeStates) == 0 {
		return snapshot, fmt.Errorf("MiSTer probe omitted Main identity or FPGA bridges")
	}
	return snapshot, nil
}

func miSTerProcessDiscoveryScript(procRoot string) string {
	return "proc_root=" + shellQuote(procRoot) + `
pids=""
for entry in "$proc_root"/[0-9]*; do
  [ -r "$entry/comm" ] || continue
  comm="$(cat "$entry/comm")"
  case "$comm" in
    Main|MiSTer) pids="$pids ${entry##*/}" ;;
  esac
done
set -- $pids
[ "$#" -eq 1 ] || exit 71
pid="$1"
`
}

func miSTerDiagnosticCacheScript(corePath, rbfPath string) string {
	return `if [ -r ` + shellQuote(corePath) + ` ] && [ -f ` + shellQuote(corePath) + ` ]; then
  core="$(tr -d '\r\n' < ` + shellQuote(corePath) + ` 2>/dev/null || true)"
else
  core=""
fi
if [ -r ` + shellQuote(rbfPath) + ` ] && [ -f ` + shellQuote(rbfPath) + ` ]; then
  rbf="$(tr -d '\r\n' < ` + shellQuote(rbfPath) + ` 2>/dev/null || true)"
else
  rbf=""
fi
`
}

func (r MiSTerSSHRemote) File(ctx context.Context, remotePath string, maxBytes int64) ([]byte, bool, error) {
	if err := validMiSTerRemotePath(remotePath); err != nil {
		return nil, false, err
	}
	if maxBytes < 1 || maxBytes > miSTerRemoteOutputLimit {
		return nil, false, fmt.Errorf("remote read limit outside supported bound")
	}
	// The marker and payload are emitted by one shell after opening the file.
	// Reading through that descriptor keeps an atomic rename from mixing a
	// size sampled from one inode with bytes read from a later pathname target.
	const presentMarker = "PRESENT\n"
	const missingMarker = "MISSING\n"
	outputLimit := int64(len(presentMarker)) + maxBytes + 1
	if outputLimit > int64(miSTerRemoteCommandOutputLimit) {
		return nil, false, fmt.Errorf("remote read limit plus framing exceeds %d-byte output bound", miSTerRemoteCommandOutputLimit)
	}
	quotedPath := shellQuote(remotePath)
	readSize := maxBytes + 1
	script := "set -eu; p=" + quotedPath + "; " +
		"if [ -L \"$p\" ]; then exit 74; " +
		"elif [ -e \"$p\" ]; then " +
		"[ -f \"$p\" ] || exit 74; exec 3< \"$p\" || exit 74; " +
		"[ ! -L \"$p\" ] && [ -f \"$p\" ] && [ -f /proc/self/fd/3 ] || exit 74; " +
		"printf 'PRESENT\\n'; head -c " + strconv.FormatInt(readSize, 10) + " <&3; " +
		"else printf 'MISSING\\n'; fi"
	output, err := r.runSSH(ctx, "sh -c "+shellQuote(script), nil, int(outputLimit))
	if err != nil {
		return nil, false, fmt.Errorf("read remote file %s in one bounded snapshot: %w", remotePath, err)
	}
	if bytes.Equal(output, []byte(missingMarker)) {
		return nil, false, nil
	}
	if !bytes.HasPrefix(output, []byte(presentMarker)) {
		return nil, false, fmt.Errorf("remote file %s returned an invalid bounded-read frame (%d output bytes)", remotePath, len(output))
	}
	data := output[len(presentMarker):]
	if int64(len(data)) > maxBytes {
		return nil, true, fmt.Errorf("remote file %s exceeds read limit: got at least %d bytes, maximum %d", remotePath, len(data), maxBytes)
	}
	return append([]byte(nil), data...), true, nil
}

func (r MiSTerSSHRemote) MakeDir(ctx context.Context, remotePath string) error {
	if err := validMiSTerRemotePath(remotePath); err != nil {
		return err
	}
	_, err := r.runSSH(ctx, "umask 077; mkdir -- "+shellQuote(remotePath), nil, 1024)
	return err
}

func (r MiSTerSSHRemote) CreateExclusive(ctx context.Context, remotePath string, data []byte) error {
	if err := validMiSTerRemotePath(remotePath); err != nil {
		return err
	}
	if len(data) == 0 || len(data) > 4096 {
		return fmt.Errorf("exclusive remote marker size is invalid")
	}
	script := "umask 077; set -C; printf %s " + shellQuote(string(data)) + " > " + shellQuote(remotePath)
	_, err := r.runSSH(ctx, "sh -c "+shellQuote(script), nil, 1024)
	return err
}

func (r MiSTerSSHRemote) Hash(ctx context.Context, remotePath string) (string, bool, error) {
	return r.remoteSHA(ctx, remotePath)
}

func (r MiSTerSSHRemote) ResolvePath(ctx context.Context, remotePath string) (string, bool, error) {
	if err := validMiSTerRemotePath(remotePath); err != nil {
		return "", false, err
	}
	quoted := shellQuote(remotePath)
	script := "if [ -e " + quoted + " ] || [ -L " + quoted + " ]; then if [ -f " + quoted + " ] && [ -x " + quoted + " ]; then readlink -f -- " + quoted + "; else exit 74; fi; else printf 'MISSING\\n'; fi"
	output, err := r.runSSH(ctx, script, nil, 2048)
	if err != nil {
		return "", false, err
	}
	resolved := strings.TrimSpace(string(output))
	if resolved == "MISSING" {
		return "", false, nil
	}
	if validMiSTerRemotePath(resolved) != nil {
		return "", false, fmt.Errorf("resolved Main executable path is outside MiSTer-owned roots")
	}
	return resolved, true, nil
}

func (r MiSTerSSHRemote) PathExists(ctx context.Context, remotePath string) (bool, error) {
	if err := validMiSTerRemotePath(remotePath); err != nil {
		return false, err
	}
	quoted := shellQuote(remotePath)
	output, err := r.runSSH(ctx, "if [ -L "+quoted+" ]; then exit 74; elif [ -e "+quoted+" ]; then printf 'PRESENT\\n'; else printf 'MISSING\\n'; fi", nil, 128)
	if err != nil {
		return false, err
	}
	switch strings.TrimSpace(string(output)) {
	case "PRESENT":
		return true, nil
	case "MISSING":
		return false, nil
	default:
		return false, fmt.Errorf("remote path existence response is malformed")
	}
}

func (r MiSTerSSHRemote) WriteFile(ctx context.Context, remotePath string, data []byte) error {
	if err := validMiSTerRemotePath(remotePath); err != nil {
		return err
	}
	if len(data) > int(miSTerFileLimit) {
		return fmt.Errorf("remote write exceeds %d bytes", miSTerFileLimit)
	}
	tmp := remotePath + ".tmp-" + randomNonce()
	if validMiSTerRemotePath(tmp) != nil {
		return fmt.Errorf("remote write temporary path exceeds its bound")
	}
	if _, exists, err := r.remoteSHA(ctx, tmp); err != nil || exists {
		return fmt.Errorf("remote write temporary path is not available")
	}
	// umask keeps Unix temp files private; chmod is not portable on the
	// MiSTer exFAT mount, whose mode bits come from mount masks. Callers verify
	// the exact content after this atomic same-directory replacement.
	script := "umask 077; set -C; cat > " + shellQuote(tmp) + " && mv -f -- " + shellQuote(tmp) + " " + shellQuote(remotePath)
	_, err := r.runSSH(ctx, "sh -c "+shellQuote(script), data, 1024)
	if err != nil {
		_ = r.removeTemporary(ctx, tmp)
	}
	return err
}

func (r MiSTerSSHRemote) Upload(ctx context.Context, localPath, remotePath, expectedSHA string) (bool, error) {
	if err := validMiSTerRemotePath(remotePath); err != nil {
		return false, err
	}
	if !isSHA256Hex(expectedSHA) {
		return false, fmt.Errorf("upload requires an expected SHA256")
	}
	info, err := os.Lstat(localPath)
	if err != nil || !info.Mode().IsRegular() || info.Mode()&os.ModeSymlink != 0 {
		return false, fmt.Errorf("upload source must be a regular nonsymlink file")
	}
	actualSHA, err := FileSHA256(localPath)
	if err != nil || actualSHA != expectedSHA {
		return false, fmt.Errorf("upload source hash changed")
	}
	if existing, exists, statErr := r.remoteSHA(ctx, remotePath); statErr == nil && exists {
		if existing == expectedSHA {
			return false, nil
		}
		return false, fmt.Errorf("remote content-addressed path collision")
	} else if statErr != nil {
		return false, statErr
	}
	parentCheck := "if [ ! -d " + shellQuote(filepath.Dir(remotePath)) + " ] || [ -L " + shellQuote(filepath.Dir(remotePath)) + " ]; then exit 74; fi"
	if _, err = r.runSSH(ctx, parentCheck, nil, 1024); err != nil {
		return false, err
	}
	tmp := remotePath + ".part-" + randomNonce()
	if validMiSTerRemotePath(tmp) != nil {
		return false, fmt.Errorf("remote upload temporary path exceeds its bound")
	}
	if _, exists, statErr := r.remoteSHA(ctx, tmp); statErr != nil || exists {
		return false, fmt.Errorf("upload temporary path is not available")
	}
	args := r.scpArgs(localPath, r.target()+":"+tmp)
	callCtx, cancel := context.WithTimeout(ctx, r.Config.Timeout)
	defer cancel()
	program, args, env, authErr := r.authCommand(r.Config.SCP, args)
	if authErr != nil {
		return false, authErr
	}
	if _, err = r.Runner.Run(callCtx, program, args, env, nil, 4096); err != nil {
		_ = r.removeTemporary(ctx, tmp)
		return false, fmt.Errorf("SCP upload failed: %w", err)
	}
	remoteTmpSHA, exists, err := r.remoteSHA(ctx, tmp)
	if err != nil || !exists || remoteTmpSHA != expectedSHA {
		_ = r.removeTemporary(ctx, tmp)
		return false, fmt.Errorf("uploaded temporary file failed content verification")
	}
	move := "if [ ! -e " + shellQuote(remotePath) + " ]; then mv -- " + shellQuote(tmp) + " " + shellQuote(remotePath) + "; else exit 73; fi"
	if _, err = r.runSSH(ctx, "sh -c "+shellQuote(move), nil, 1024); err != nil {
		_ = r.removeTemporary(ctx, tmp)
		return false, err
	}
	return true, nil
}

func (r MiSTerSSHRemote) Download(ctx context.Context, remotePath, localPath string, maxBytes int64) error {
	if err := validMiSTerRemotePath(remotePath); err != nil {
		return err
	}
	if maxBytes < 1 || maxBytes > 64<<20 {
		return fmt.Errorf("download limit outside supported bound")
	}
	sizeOut, err := r.runSSH(ctx, "if [ -L "+shellQuote(remotePath)+" ] || [ ! -f "+shellQuote(remotePath)+" ]; then exit 74; else wc -c < "+shellQuote(remotePath)+"; fi", nil, 128)
	if err != nil {
		return err
	}
	size, err := strconv.ParseInt(strings.TrimSpace(string(sizeOut)), 10, 64)
	if err != nil || size < 0 || size > maxBytes {
		return fmt.Errorf("remote file size exceeds its bound")
	}
	if err = os.MkdirAll(filepath.Dir(localPath), 0700); err != nil {
		return err
	}
	tmp := localPath + ".part-" + randomNonce()
	args := r.scpArgs(r.target()+":"+remotePath, tmp)
	callCtx, cancel := context.WithTimeout(ctx, r.Config.Timeout)
	defer cancel()
	program, args, env, authErr := r.authCommand(r.Config.SCP, args)
	if authErr != nil {
		_ = os.Remove(tmp)
		return authErr
	}
	if _, err = r.Runner.Run(callCtx, program, args, env, nil, 4096); err != nil {
		_ = os.Remove(tmp)
		return fmt.Errorf("SCP download failed: %w", err)
	}
	info, err := os.Lstat(tmp)
	if err != nil || !info.Mode().IsRegular() || info.Size() != size || info.Size() > maxBytes {
		_ = os.Remove(tmp)
		return fmt.Errorf("downloaded file size or type changed")
	}
	if err = os.Rename(tmp, localPath); err != nil {
		_ = os.Remove(tmp)
		return err
	}
	return nil
}

func (r MiSTerSSHRemote) RemoveOwned(ctx context.Context, remotePath, expectedSHA string) error {
	if err := validMiSTerRemotePath(remotePath); err != nil {
		return err
	}
	if !isSHA256Hex(expectedSHA) {
		return fmt.Errorf("owned removal requires expected SHA256")
	}
	actual, exists, err := r.remoteSHA(ctx, remotePath)
	if err != nil || !exists {
		return err
	}
	if actual != expectedSHA {
		return fmt.Errorf("owned file changed; refusing to remove %s", filepath.Base(remotePath))
	}
	_, err = r.runSSH(ctx, "rm -- "+shellQuote(remotePath), nil, 1024)
	return err
}

func (r MiSTerSSHRemote) RemoveOwnedBatch(ctx context.Context, files []miSTerOwnedRemoteFile) error {
	if len(files) == 0 || len(files) > miSTerOwnedFileBatchMax {
		return fmt.Errorf("owned-file removal batch must contain 1..%d files", miSTerOwnedFileBatchMax)
	}
	var input strings.Builder
	for _, file := range files {
		if validMiSTerRemotePath(file.Path) != nil || !isSHA256Hex(file.SHA256) {
			return fmt.Errorf("owned-file removal batch contains an invalid path or SHA256")
		}
		input.WriteString(file.SHA256)
		input.WriteByte('\t')
		input.WriteString(file.Path)
		input.WriteByte('\n')
	}
	const script = `set -eu
umask 077
list="$(mktemp /tmp/jtframe-remove-owned.XXXXXX)"
trap 'rm -f -- "$list"' EXIT HUP INT TERM
cat > "$list"
tab="$(printf '\t')"
verify() {
  want="$1"
  p="$2"
  if [ -L "$p" ]; then exit 74
  elif [ ! -e "$p" ]; then return 0
  elif [ ! -f "$p" ]; then exit 74
  fi
  actual="$(sha256sum -- "$p")" || exit 74
  actual="${actual%% *}"
  [ "$actual" = "$want" ] || exit 74
}
while IFS="$tab" read -r want p; do
  [ -n "$want" ] && [ -n "$p" ] || exit 74
  verify "$want" "$p"
done < "$list"
while IFS="$tab" read -r want p; do
  if [ -e "$p" ] || [ -L "$p" ]; then
    verify "$want" "$p"
    rm -- "$p"
  fi
done < "$list"
`
	_, err := r.runSSH(ctx, "sh -c "+shellQuote(script), []byte(input.String()), 1024)
	if err != nil {
		return fmt.Errorf("remove owned remote files as one verified batch: %w", err)
	}
	return nil
}

func (r MiSTerSSHRemote) RemoveEmptyDir(ctx context.Context, remotePath string) error {
	if err := validMiSTerRemotePath(remotePath); err != nil {
		return err
	}
	quoted := shellQuote(remotePath)
	script := "if [ -L " + quoted + " ]; then exit 74; elif [ -d " + quoted + " ]; then rmdir -- " + quoted + "; elif [ ! -e " + quoted + " ]; then exit 0; else exit 74; fi"
	_, err := r.runSSH(ctx, script, nil, 1024)
	return err
}

func (r MiSTerSSHRemote) removeTemporary(ctx context.Context, remotePath string) error {
	if err := validMiSTerRemotePath(remotePath); err != nil {
		return err
	}
	_, err := r.runSSH(ctx, "rm -f -- "+shellQuote(remotePath), nil, 1024)
	return err
}

func (r MiSTerSSHRemote) WriteFIFO(ctx context.Context, record []byte, timeout time.Duration) error {
	if len(record) == 0 || len(record) > 1023 || record[len(record)-1] != '\n' || strings.Count(string(record), "\n") != 1 || strings.IndexByte(string(record), 0) >= 0 {
		return fmt.Errorf("MiSTer FIFO record must be one newline-terminated command of at most 1023 bytes")
	}
	if timeout < 2*time.Second || timeout > r.Config.Timeout {
		return fmt.Errorf("FIFO timeout must be positive and within the SSH command bound")
	}
	seconds := int(timeout/time.Second) - 1
	script := fmt.Sprintf("timeout -k 1s %ds sh -c 'printf %%s \"$1\" > /dev/MiSTer_cmd' sh %s", seconds, shellQuote(string(record)))
	callCtx, cancel := context.WithTimeout(ctx, timeout)
	defer cancel()
	_, err := r.runSSH(callCtx, "sh -c "+shellQuote(script), nil, 1024)
	return err
}

func (r MiSTerSSHRemote) remoteSHA(ctx context.Context, remotePath string) (string, bool, error) {
	if err := validMiSTerRemotePath(remotePath); err != nil {
		return "", false, err
	}
	output, err := r.runSSH(ctx, "if [ -f "+shellQuote(remotePath)+" ] && [ ! -L "+shellQuote(remotePath)+" ]; then sha256sum -- "+shellQuote(remotePath)+"; else printf 'MISSING\\n'; fi", nil, 512)
	if err != nil {
		return "", false, err
	}
	if strings.TrimSpace(string(output)) == "MISSING" {
		return "", false, nil
	}
	fields := strings.Fields(string(output))
	if len(fields) < 1 || !isSHA256Hex(fields[0]) {
		return "", false, fmt.Errorf("remote SHA256 response is malformed")
	}
	return fields[0], true, nil
}

func (r MiSTerSSHRemote) scpArgs(source, target string) []string {
	source = quoteSCPRemoteSpec(source)
	target = quoteSCPRemoteSpec(target)
	args := []string{"-O", "-P", strconv.Itoa(r.Config.Port), "-oBatchMode=yes", "-oStrictHostKeyChecking=yes"}
	if r.Config.IdentityFile != "" {
		args = append(args, "-i", r.Config.IdentityFile)
	}
	if r.Config.KnownHostsFile != "" {
		args = append(args, "-oUserKnownHostsFile="+r.Config.KnownHostsFile)
	}
	return append(args, "--", source, target)
}

func quoteSCPRemoteSpec(spec string) string {
	separator := strings.IndexByte(spec, ':')
	if separator <= 0 {
		return spec
	}
	host, remotePath := spec[:separator], spec[separator+1:]
	if !strings.Contains(host, "@") || validMiSTerRemotePath(remotePath) != nil {
		return spec
	}
	// Legacy SCP's sink compares the returned basename against the literal
	// request. Avoid shell quotes for portable paths so that check still works.
	if miSTerSCPPortablePath(remotePath) { return spec }
	return host + ":" + shellQuote(remotePath)
}

func miSTerSCPPortablePath(path string) bool {
	for _, c := range path {
		if !(c >= 'a' && c <= 'z' || c >= 'A' && c <= 'Z' || c >= '0' && c <= '9' || c == '/' || c == '.' || c == '_' || c == '-') {
			return false
		}
	}
	return true
}

func safeEnvironmentName(value string) bool {
	if value == "" || !((value[0] >= 'A' && value[0] <= 'Z') || (value[0] >= 'a' && value[0] <= 'z') || value[0] == '_') {
		return false
	}
	for _, c := range value[1:] {
		if !((c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') || (c >= '0' && c <= '9') || c == '_') {
			return false
		}
	}
	return true
}

func safeSSHHost(value string) bool {
	if value == "" {
		return false
	}
	for _, r := range value {
		if !(r >= 'a' && r <= 'z' || r >= 'A' && r <= 'Z' || r >= '0' && r <= '9' || r == '.' || r == '-' || r == ':') {
			return false
		}
	}
	return true
}

func safeSSHUser(value string) bool {
	if value == "" {
		return false
	}
	for _, r := range value {
		if !(r >= 'a' && r <= 'z' || r >= 'A' && r <= 'Z' || r >= '0' && r <= '9' || r == '_' || r == '-' || r == '.') {
			return false
		}
	}
	return true
}

func validMiSTerRemotePath(value string) error {
	if len(value) == 0 || len(value) > 1023 || !(strings.HasPrefix(value, "/tmp/") || strings.HasPrefix(value, "/media/fat/")) || filepath.Clean(value) != value {
		return fmt.Errorf("remote path is outside MiSTer-owned roots")
	}
	for _, r := range value {
		if r < 0x20 || r == 0x7f || r == '\\' {
			return fmt.Errorf("remote path contains a control or backslash character")
		}
	}
	for _, part := range strings.Split(value, "/") {
		if part == ".." || part == "." {
			return fmt.Errorf("remote path contains traversal")
		}
	}
	return nil
}

func shellQuote(value string) string { return "'" + strings.ReplaceAll(value, "'", "'\\''") + "'" }
