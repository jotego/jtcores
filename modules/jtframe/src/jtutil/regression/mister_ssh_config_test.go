/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */

package regression

import (
	"context"
	"reflect"
	"testing"
)

type sshConfigRecordingRunner struct {
	program string
	args    []string
	env     []string
}

func (r *sshConfigRecordingRunner) Run(_ context.Context, program string, args, env []string, _ []byte, _ int) ([]byte, error) {
	r.program = program
	r.args = append([]string(nil), args...)
	r.env = append([]string(nil), env...)
	return []byte("ok"), nil
}

func TestMiSTerSSHConfigRunnerAddsConfigToSSHAndSCP(t *testing.T) {
	for _, test := range []struct {
		name    string
		program string
		args    []string
		want    []string
	}{
		{name: "ssh", program: "/usr/bin/ssh", args: []string{"-T", "-p", "2201", "--", "u@h", "true"}, want: []string{"-F", "/tmp/ssh config", "-T", "--", "u@h", "true"}},
		{name: "scp", program: "/usr/bin/scp", args: []string{"-P", "2201", "--", "local file", "u@h:/tmp/file"}, want: []string{"-F", "/tmp/ssh config", "--", "local file", "u@h:/tmp/file"}},
		{name: "sshpass ssh", program: "/usr/bin/sshpass", args: []string{"-e", "/usr/bin/ssh", "-T", "-p", "2201", "--", "u@h", "true"}, want: []string{"-e", "/usr/bin/ssh", "-F", "/tmp/ssh config", "-T", "--", "u@h", "true"}},
		{name: "sshpass scp", program: "/usr/bin/sshpass", args: []string{"-e", "/usr/bin/scp", "-P", "2201", "--", "local", "u@h:/tmp/file"}, want: []string{"-e", "/usr/bin/scp", "-F", "/tmp/ssh config", "--", "local", "u@h:/tmp/file"}},
	} {
		t.Run(test.name, func(t *testing.T) {
			recorder := &sshConfigRecordingRunner{}
			got, err := (MiSTerSSHConfigRunner{Base: recorder, Path: "/tmp/ssh config"}).Run(context.Background(), test.program, test.args, []string{"SSHPASS=secret"}, nil, 1024)
			if err != nil {
				t.Fatal(err)
			}
			if string(got) != "ok" || recorder.program != test.program || !reflect.DeepEqual(recorder.args, test.want) || !reflect.DeepEqual(recorder.env, []string{"SSHPASS=secret"}) {
				t.Fatalf("forwarded call = %q %#v %#v", recorder.program, recorder.args, recorder.env)
			}
		})
	}
}

func TestMiSTerSSHConfigRunnerRejectsUnsupportedOrInvalidInputs(t *testing.T) {
	for _, test := range []struct {
		name, program, config string
		args                  []string
	}{
		{name: "relative config", program: "ssh", config: "config"},
		{name: "unexpected program", program: "sh", config: "/tmp/config"},
		{name: "malformed sshpass", program: "sshpass", config: "/tmp/config", args: []string{"-p", "secret"}},
	} {
		t.Run(test.name, func(t *testing.T) {
			_, err := (MiSTerSSHConfigRunner{Base: &sshConfigRecordingRunner{}, Path: test.config}).Run(context.Background(), test.program, test.args, nil, nil, 10)
			if err == nil {
				t.Fatal("invalid config runner input was accepted")
			}
		})
	}
}
