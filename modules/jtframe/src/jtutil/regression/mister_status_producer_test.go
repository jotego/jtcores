/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */

package regression

import (
	"strings"
	"testing"
)

func TestMiSTerCaptureV2ProducerStatusSchemas(t *testing.T) {
	legacy := mainMockCaptureStatusV2JSON
	current := strings.Replace(legacy, `"fault":0,`, `"fault":0,"rtl_fault_code":5,`, 1)
	current = strings.Replace(current, `"schedule_state":"complete",`, `"schedule_state":"complete","reason":"rtl_fault",`, 1)
	zero := strings.Replace(strings.Replace(current, `"rtl_fault_code":5`, `"rtl_fault_code":0`, 1), `"reason":"rtl_fault"`, `"reason":""`, 1)
	current = strings.Replace(current, `"state":"complete"`, `"state":"error"`, 1)
	current = strings.Replace(current, `"schedule_state":"complete"`, `"schedule_state":"error"`, 1)
	for name, data := range map[string]string{"legacy": legacy, "current": current, "current zero": zero} {
		status, err := decodeMiSTerCaptureStatusV2([]byte(data))
		if err != nil {
			t.Fatalf("%s producer status: %v", name, err)
		}
		if name == "current" && (status.RTLFaultCode != 5 || status.Reason != "rtl_fault") {
			t.Fatalf("producer diagnostic fields lost: %+v", status)
		}
		if _, err = decodeLiveMiSTerCaptureStatus([]byte(data)); err != nil {
			t.Fatalf("%s live status: %v", name, err)
		}
	}
	bad := map[string]string{
		"fault only":     strings.Replace(legacy, `"fault":0,`, `"fault":0,"rtl_fault_code":5,`, 1),
		"reason only":    strings.Replace(legacy, `"fault":0,`, `"fault":0,"reason":"x",`, 1),
		"bad reason":     strings.Replace(current, `"reason":"rtl_fault"`, `"reason":42`, 1),
		"bad fault type": strings.Replace(current, `"rtl_fault_code":5`, `"rtl_fault_code":"5"`, 1),
		"fault overflow": strings.Replace(current, `"rtl_fault_code":5`, `"rtl_fault_code":256`, 1),
		"null":           strings.Replace(current, `"reason":"rtl_fault"`, `"reason":null`, 1),
		"duplicate":      strings.Replace(current, `"rtl_fault_code":5`, `"rtl_fault_code":5,"rtl_fault_code":5`, 1),
		"unknown":        strings.Replace(current, `"fault":0,`, `"fault":0,"unknown":1,`, 1),
		"wrong pair":     strings.Replace(current, `"reason":"rtl_fault"`, `"unknown":"rtl_fault"`, 1),
	}
	for name, data := range bad {
		t.Run(name, func(t *testing.T) {
			if _, err := decodeMiSTerCaptureStatusV2([]byte(data)); err == nil {
				t.Fatal("invalid status accepted")
			}
		})
	}
}

func TestMiSTerCaptureV2RejectsContradictorySuccessDiagnostics(t *testing.T) {
	fixture := newMiSTerCaptureV2Fixture(t)
	base := string(fixture.status)
	withFields := func(fault, reason string) []byte {
		value := strings.Replace(base, `"fault":0,`, `"fault":0,"rtl_fault_code":`+fault+`,`, 1)
		value = strings.Replace(value, `"schedule_state":"complete",`, `"schedule_state":"complete","reason":`+reason+`,`, 1)
		return []byte(value)
	}
	cases := []struct {
		name, fault, reason string
		accept              bool
	}{
		{"clean producer", "0", `""`, true},
		{"faulted producer", "5", `""`, false},
		{"failure reason", "0", `"capture_encode_timeout"`, false},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			data := withFields(tc.fault, tc.reason)
			_, liveErr := decodeLiveMiSTerCaptureStatus(data)
			_, receiptErr := validateMiSTerCaptureV2(fixture.expected, data, fixture.manifest, fixture.files, fixture.root)
			if (liveErr == nil) != tc.accept || (receiptErr == nil) != tc.accept {
				t.Fatalf("live=%v receipt=%v", liveErr, receiptErr)
			}
		})
	}
}
