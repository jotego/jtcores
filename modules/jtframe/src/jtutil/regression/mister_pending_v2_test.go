/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */

package regression

import (
	"context"
	"strings"
	"testing"
)

func TestMiSTerLegacyPendingFinalizationIsRejectedBeforeReplay(t *testing.T) {
	f := newRunCommitRecoveryFixture(t, "legacy-pending-v1")
	f.failOnce("after-pending")
	if _, err := RunCommitMiSTer(context.Background(), f.log, f.prepared, f.cfg, f.deps, f.policy); err == nil {
		t.Fatal("pending-plan failure hook did not interrupt result finalization")
	}
	plan := f.onlyPendingPlan(t)
	plan.Candidate.CaptureProtocol = ""
	for index := range plan.Candidate.Images {
		plan.Candidate.Images[index].Sequence = uint32(index + 1)
	}
	candidateDigest, err := canonicalMiSTerDigest(plan.Candidate)
	if err != nil {
		t.Fatal(err)
	}
	plan.CandidateDigest = candidateDigest
	plan.Summary.OutputDigest = candidateDigest
	if err := plan.Validate(); err != nil {
		t.Fatalf("historical markerless v1 pending plan is not internally valid: %v", err)
	}
	inputDigest, err := plan.InputDigest()
	if err != nil {
		t.Fatal(err)
	}
	laneKey := captureRunLaneForTest(f.log.Progress, f.policy.RunScopeID)
	lane := f.log.Progress.CaptureRuns[laneKey]
	for key, item := range lane.Finalizations {
		if item.State != CaptureFinalizationPending {
			continue
		}
		item.Plan = plan.Clone()
		item.InputDigest = inputDigest
		lane.Finalizations[key] = item
	}
	f.log.Progress.CaptureRuns[laneKey] = lane
	if err := f.log.Save(); err != nil {
		t.Fatalf("could not persist a self-consistent old pending plan: %v", err)
	}

	if _, err := RunCommitMiSTer(context.Background(), f.log, f.prepared, f.cfg, f.deps, f.retryPolicy()); err == nil || !strings.Contains(err.Error(), "legacy or missing capture protocol") {
		t.Fatalf("legacy pending plan was replayed as a fresh v2 result: %v", err)
	}
	f.assertCaptureCalls(t, 1)
	f.assertNoSharedEffects(t)
	f.assertHistoryRows(t, 0)
}
