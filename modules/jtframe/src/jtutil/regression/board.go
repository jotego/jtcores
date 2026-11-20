/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */

package regression

import (
	"archive/tar"
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"
)

// Board is one MiSTer. The runner reaches the boards only through it
type Board interface {
	Name() string
	// Deploy copies the release folder to /media/fat/<folder>. jtbin2mr also
	// wipes the core settings (config/*.cfg, nvram, dips) and keeps MiSTer.ini
	Deploy(ctx context.Context, release, folder string) error
	// Health checks SSH, that Main runs and that its FIFO exists
	Health(ctx context.Context) error
	// Load empties /tmp/jtcap and /tmp/MiSTer.log, then sends load_core <mra>
	Load(ctx context.Context, mra string) error
	Send(ctx context.Context, command string) error
	// Status reads /tmp/jtcap/status.json, the zero value while it is absent
	Status(ctx context.Context) (BoardStatus, error)
	// Fetch copies /tmp/jtcap/<id>/*.png to dir in one tar stream
	Fetch(ctx context.Context, id, dir string) error
	Log(ctx context.Context) ([]byte, error)
	// Reboot restarts the board and waits for Health
	Reboot(ctx context.Context) error
	Close()
}

// BoardStatus is /tmp/jtcap/status.json, protocol 3
type BoardStatus struct {
	State         string `json:"state"`
	Error         string `json:"error"`
	MRA           string `json:"mra"`
	ID            string `json:"id"`
	Frame         int    `json:"frame"`
	FramesTotal   int    `json:"frames_total"`
	Captured      int    `json:"captured"`
	CapturesTotal int    `json:"captures_total"`
	Main          string `json:"main"`
	Protocol      int    `json:"protocol"`
}

const mister_fifo = "/dev/MiSTer_cmd"

// ssh_board shares one SSH connection (ControlMaster) for the whole run.
// MISTERPASSWD, when set, is passed to sshpass, as jtbin2mr does
type ssh_board struct {
	host, socket string
}

func new_ssh_board(host, socket_dir string) Board {
	return &ssh_board{host: host, socket: filepath.Join(socket_dir, host)}
}

func (b *ssh_board) Name() string { return b.host }

func (b *ssh_board) Deploy(ctx context.Context, release, folder string) error {
	cmd := exec.CommandContext(ctx, "jtbin2mr", "-g", "--skip-sd", "--folder", folder, "--delete-hash-folders", "-m", b.host)
	cmd.Env = append(os.Environ(), "JTBIN="+release, "JTUTIL=") // no jtbeta.zip copy: games/mame is shared over NFS
	if out, e := cmd.CombinedOutput(); e != nil {
		return fmt.Errorf("jtbin2mr: %w\n%s", e, out)
	}
	return nil
}

func (b *ssh_board) Health(ctx context.Context) error {
	return b.run(ctx, 30*time.Second, "pidof MiSTer >/dev/null || { echo Main is not running >&2; exit 1; }; [ -p "+mister_fifo+" ] || { echo no "+mister_fifo+" >&2; exit 1; }", nil)
}

func (b *ssh_board) Load(ctx context.Context, mra string) error {
	return b.run(ctx, 30*time.Second, "rm -rf /tmp/jtcap/*; : > /tmp/MiSTer.log; "+fifo_script("load_core "+mra), nil)
}

func (b *ssh_board) Send(ctx context.Context, command string) error {
	return b.run(ctx, 30*time.Second, fifo_script(command), nil)
}

func fifo_script(command string) string {
	return "timeout 5 sh -c 'printf \"%s\\n\" \"$1\" > " + mister_fifo + "' sh " + sh_quote(command)
}

func (b *ssh_board) Status(ctx context.Context) (st BoardStatus, e error) {
	var out bytes.Buffer
	if e = b.run(ctx, 30*time.Second, "cat /tmp/jtcap/status.json 2>/dev/null; true", &out); e != nil || out.Len() == 0 {
		return st, e
	}
	e = json.Unmarshal(out.Bytes(), &st); if e != nil { return st, fmt.Errorf("status.json: %w", e) }
	return st, nil
}

func (b *ssh_board) Fetch(ctx context.Context, id, dir string) error {
	var out bytes.Buffer
	e := b.run(ctx, 2*time.Minute, "cd /tmp/jtcap/"+sh_quote(id)+" && tar cf - *.png", &out); if e != nil { return e }
	tr := tar.NewReader(&out)
	for {
		hdr, e := tr.Next()
		if e == io.EOF {
			return nil
		}
		if e != nil {
			return e
		}
		name := filepath.Base(hdr.Name)
		if hdr.Typeflag != tar.TypeReg || name != hdr.Name || !strings.HasSuffix(name, ".png") {
			return fmt.Errorf("unexpected %s in the PNG stream", hdr.Name)
		}
		data, e := io.ReadAll(tr); if e != nil { return e }
		e = os.WriteFile(filepath.Join(dir, name), data, 0640); if e != nil { return e }
	}
}

func (b *ssh_board) Log(ctx context.Context) ([]byte, error) {
	var out bytes.Buffer
	e := b.run(ctx, time.Minute, "cat /tmp/MiSTer.log", &out)
	return out.Bytes(), e
}

func (b *ssh_board) Reboot(ctx context.Context) error {
	b.run(ctx, 10*time.Second, "reboot", nil)
	b.Close()
	deadline := time.Now().Add(3 * time.Minute)
	for e := sleep(ctx, 20*time.Second); ; e = sleep(ctx, 5*time.Second) {
		if e != nil {
			return e
		}
		if e = b.Health(ctx); e == nil || time.Now().After(deadline) {
			return e
		}
	}
}

func (b *ssh_board) Close() {
	exec.Command("ssh", "-o", "ControlPath="+b.socket, "-O", "exit", b.host).Run()
}

func (b *ssh_board) run(ctx context.Context, timeout time.Duration, script string, out io.Writer) error {
	ctx, cancel := context.WithTimeout(ctx, timeout)
	defer cancel()
	args := []string{"ssh", "-o", "ControlMaster=auto", "-o", "ControlPath=" + b.socket, "-o", "ControlPersist=yes",
		"-o", "ConnectTimeout=10", "-o", "ServerAliveInterval=5", "-l", "root", b.host, script}
	if os.Getenv("MISTERPASSWD") != "" {
		args = append([]string{"sshpass", "-e"}, args...)
	}
	cmd := exec.CommandContext(ctx, args[0], args[1:]...)
	cmd.Env = append(os.Environ(), "SSHPASS="+os.Getenv("MISTERPASSWD"))
	var stderr bytes.Buffer
	cmd.Stdout, cmd.Stderr, cmd.WaitDelay = out, &stderr, 5*time.Second
	if e := cmd.Run(); e != nil {
		return fmt.Errorf("%w %s", e, strings.TrimSpace(stderr.String()))
	}
	return nil
}

func sleep(ctx context.Context, d time.Duration) error {
	select {
	case <-ctx.Done():
		return ctx.Err()
	case <-time.After(d):
		return nil
	}
}

func sh_quote(s string) string { return "'" + strings.ReplaceAll(s, "'", `'\''`) + "'" }
