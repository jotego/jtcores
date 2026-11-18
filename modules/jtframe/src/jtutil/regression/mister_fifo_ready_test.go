//go:build linux

/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */

package regression

import (
	"context"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"syscall"
	"testing"
	"time"
)

func TestMiSTerFIFOReadyChecksCurrentReader(t *testing.T) {
	fifo := filepath.Join(t.TempDir(), "fifo")
	if err := syscall.Mkfifo(fifo, 0600); err != nil {
		t.Fatal(err)
	}
	check := func(want string) {
		t.Helper()
		out, err := exec.Command("sh", "-c", miSTerFIFOReadyScript(os.Getpid(), fifo)).CombinedOutput()
		if err != nil || strings.TrimSpace(string(out)) != want {
			t.Fatalf("ready=%q want %s, err=%v", out, want, err)
		}
	}
	check("0")
	fd, err := syscall.Open(fifo, syscall.O_RDWR|syscall.O_NONBLOCK, 0)
	if err != nil {
		t.Fatal(err)
	}
	check("1")
	if err = os.Remove(fifo); err != nil {
		t.Fatal(err)
	}
	if err = syscall.Mkfifo(fifo, 0600); err != nil {
		t.Fatal(err)
	}
	check("0") // the open reader belongs to the unlinked FIFO
	syscall.Close(fd)
	reader := exec.Command("sh", "-c", `exec 3<>"$1"; sleep 10`, "_", fifo)
	if err = reader.Start(); err != nil {
		t.Fatal(err)
	}
	defer func() { _ = reader.Process.Kill(); _ = reader.Wait() }()
	var writer int
	for i := 0; i < 100; i++ {
		writer, err = syscall.Open(fifo, syscall.O_WRONLY|syscall.O_NONBLOCK, 0)
		if err == nil {
			break
		}
		time.Sleep(time.Millisecond * 10)
	}
	if err != nil {
		t.Fatal(err)
	}
	check("0") // writer is not a reader in the selected process
	syscall.Close(writer)
	pathfd, err := syscall.Open(fifo, 0x200000, 0)
	if err != nil {
		t.Fatal(err)
	} // Linux O_PATH
	defer syscall.Close(pathfd)
	check("0")
}

type fifoGateRemote struct {
	*fakeMiSTerRemote
	ready   bool
	calls   int
	lastPID int
	onReady func()
}

func (f *fifoGateRemote) FIFOReady(_ context.Context, pid int) (bool, error) {
	f.calls++
	f.lastPID = pid
	if f.onReady != nil {
		f.onReady()
	}
	return f.ready, nil
}
func TestMiSTerWaitLoadedRequiresFIFOReader(t *testing.T) {
	r := &fifoGateRemote{fakeMiSTerRemote: newFakeMiSTerRemote()}
	r.probe.MainPID = 101
	r.probe.ArgvRBF = "/candidate.rbf"
	r.probe.ArgvMRA = "/candidate.mra"
	before := r.before
	now := time.Now()
	d := &MiSTerSessionDriver{Remote: r, Config: MiSTerDriverConfig{MainSHA256: before.MainSHA256, ExpectedBridgeCount: 1, LoadTimeout: time.Second, PollInterval: time.Millisecond}, Now: func() time.Time { return now }, Sleep: func(context.Context, time.Duration) error { now = now.Add(time.Second); return nil }}
	active := &miSTerActiveSession{ledger: miSTerBoardLedger{BeforePID: before.MainPID, Before: before}}
	if _, err := d.waitLoaded(context.Background(), active, "/candidate.mra", "/candidate.rbf"); err == nil || r.calls == 0 {
		t.Fatal("accepted loaded Main with no FIFO reader")
	}
	r.ready = true
	now = time.Now()
	r.onReady = func() { now = now.Add(2 * time.Second) }
	if _, err := d.waitLoaded(context.Background(), active, "/candidate.mra", "/candidate.rbf"); err == nil {
		t.Fatal("accepted FIFO readiness after deadline")
	}
	r.ready = false
	r.calls = 0
	r.onReady = func() {
		if r.calls == 2 {
			r.ready = true
		}
	}
	d.Sleep = func(context.Context, time.Duration) error { now = now.Add(100 * time.Millisecond); return nil }
	now = time.Now()
	loaded, err := d.waitLoaded(context.Background(), active, "/candidate.mra", "/candidate.rbf")
	if err != nil || r.calls != 2 || r.lastPID != 101 || loaded.MainPID != 101 {
		t.Fatalf("delayed readiness: pid=%d calls=%d err=%v", r.lastPID, r.calls, err)
	}
	r.onReady = nil
	now = time.Now()
	if _, err := d.waitLoaded(context.Background(), active, "/candidate.mra", "/candidate.rbf"); err != nil {
		t.Fatal(err)
	}
}
