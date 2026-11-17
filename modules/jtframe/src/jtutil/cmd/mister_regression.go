/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */

package cmd

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/spf13/cobra"
	"jtutil/regression"
)

func runMiSTerRegression(ctx context.Context, command *cobra.Command, cfg regression.Config, dataRoot string, cores, sets []string, archiveMode, manual bool) (resultErr error) {
	if command == nil || ctx == nil {
		return fmt.Errorf("MiSTer regression requires a command and context")
	}
	if regressionMigrate != "" || regressionImport != "" {
		return fmt.Errorf("--migrate-logs and --import-progress are not supported for target=mister")
	}
	if regressionManifest != "" {
		return fmt.Errorf("--manifest is not supported for qualified MiSTer capture; prepare from verified source/build inventory")
	}
	if regressionRetryErrors {
		return fmt.Errorf("--retry-errors is specific to the legacy serial hardware path")
	}
	if regressionPublishTo != "github" || command.Flags().Changed("publish-to") {
		return fmt.Errorf("MiSTer regression is local-only and does not accept --publish-to")
	}
	if err := miSTerRequireCoreSet(cores, sets); err != nil {
		return err
	}
	cfg.NoPublish = true
	cfg.Source = project_root()
	cfg, err := miSTerResultRoot(cfg, dataRoot)
	if err != nil {
		return err
	}
	if err = cfg.ValidateMiSTerRun(); err != nil {
		return err
	}
	qualification, err := regression.ReadMiSTerQualification(cfg)
	if err != nil {
		return err
	}
	if cfg.GlobalProfile == "" {
		cfg.GlobalProfile = filepath.Join(cfg.Source, "modules", "jtframe", "bin", "reg.yaml")
	}
	if cfg.Repository == "" {
		cfg.Repository = "jotego/jtcores"
	}
	if manual && len(cores) == 0 && !archiveMode {
		return fmt.Errorf("manual MiSTer capture requires --core or --cores")
	}
	lock, err := regression.AcquireLock(dataRoot)
	if err != nil {
		if regressionPoll && errors.Is(err, regression.ErrBoardBusy) {
			fmt.Fprintln(command.OutOrStdout(), err)
			return nil
		}
		return err
	}
	defer regression.ReleaseLock(lock)
	if err = regression.GuardCaptureTarget(dataRoot, "mister"); err != nil {
		return err
	}
	if err = regression.InitializeLog(dataRoot); err != nil {
		return err
	}
	var manifest regression.Manifest
	var manualArchive regression.ManualArchive
	commit, dirty := "", false
	if archiveMode {
		archiveRoot := cfg.BuildsDir
		if archiveRoot == "" {
			archiveRoot = filepath.Join(os.Getenv("JOTEGO"), "core-builds")
		}
		manualArchive, err = regression.ResolveManualArchive(ctx, cfg.Source, archiveRoot, regressionCommit)
		if err != nil {
			return err
		}
		commit = manualArchive.Commit
		_, dirty, err = regression.ManualCommit(ctx, cfg.Source, "", false)
		if err != nil {
			return err
		}
	} else if manual {
		if regressionJTBin {
			release := os.Getenv("JTBIN")
			if release == "" {
				return fmt.Errorf("--jtbin requires JTBIN")
			}
			commit, err = regression.MiSTerReleaseBuildCommit(ctx, release, cores)
		} else {
			commit, dirty, err = regression.ManualCommit(ctx, cfg.Source, "", false)
		}
		if err != nil {
			return err
		}
	} else {
		if regressionPoll && (regressionRunID != "" || regressionManifest != "") {
			return fmt.Errorf("--poll requires automatic MiSTer build discovery")
		}
		build, discoverErr := regression.DiscoverBuild(ctx, cfg, dataRoot, regressionRunID)
		if errors.Is(discoverErr, regression.ErrNoEligibleBuild) && regressionPoll {
			fmt.Fprintln(command.OutOrStdout(), discoverErr)
			return nil
		}
		if discoverErr != nil {
			return discoverErr
		}
		commit = build.SHA
		manifest.Build = build
	}
	if !validMiSTerCommit(commit) {
		return fmt.Errorf("MiSTer source/build identity is not a full lowercase commit SHA")
	}
	for _, core := range cores {
		if err = regression.RequireSourceCommit(ctx, cfg.Source, commit, core); err != nil {
			return err
		}
	}
	record, err := regression.OpenCommitLog(dataRoot, commit, dirty)
	if err != nil {
		return err
	}
	defer func() {
		if closeErr := record.Close(); closeErr != nil && resultErr == nil {
			resultErr = closeErr
		}
	}()
	if err = record.Write("Starting qualified MiSTer regression in " + cfg.Source); err != nil {
		return err
	}
	work, err := miSTerWorkDirectory()
	if err != nil {
		return err
	}
	defer os.RemoveAll(work)
	sourceView, err := regression.OpenSourceCommitView(ctx, cfg.Source, commit)
	if err != nil {
		return err
	}
	defer func() {
		if closeErr := sourceView.Close(); closeErr != nil && resultErr == nil {
			resultErr = closeErr
		}
	}()
	cfg.SourceConfigRoot = sourceView.Root
	prepareCtx, cancel := miSTerTimeoutContext(ctx, cfg.TimeoutSeconds)
	defer cancel()
	switch {
	case archiveMode:
		manifest, err = regression.PrepareMiSTerManualArchive(prepareCtx, cfg, dataRoot, work, manualArchive, cores, sets)
	case manual:
		manifest, err = regression.PrepareMiSTerManualSelection(prepareCtx, cfg, work, cores, sets, regressionJTBin)
		if err == nil {
			manifest.Build = regression.BuildIdentity{Repository: "jotego/jtcores", Workflow: "manual", RunID: "manual-mister", Attempt: "1", SHA: commit, Event: "manual-mister", Conclusion: "manual"}
		}
	default:
		manifest, err = regression.PrepareMiSTerBuild(prepareCtx, cfg, dataRoot, work, manifest.Build)
	}
	if err != nil {
		return err
	}
	if manifest.Source != "" && filepath.Clean(manifest.Source) != filepath.Clean(cfg.Source) {
		return fmt.Errorf("prepared MiSTer inventory belongs to another working project")
	}
	if manifest.Build.SHA != "" && manifest.Build.SHA != commit {
		return fmt.Errorf("prepared MiSTer inventory source SHA differs from the selected log identity")
	}
	prepared, err := prepareMiSTerJobs(ctx, cfg, manifest, work, qualification)
	if err != nil {
		return err
	}
	boards, err := regression.BuildMiSTerPoolBoards(cfg, prepared, dataRoot)
	if err != nil {
		return err
	}
	scope, resume := regression.MiSTerAutomaticRunScopeID, false
	if manual {
		scope, resume, err = miSTerScopeID(regressionMisterRunScope)
		if err != nil {
			return err
		}
	} else if regressionMisterRunScope != "" {
		return fmt.Errorf("--mister-run-scope is only for manual MiSTer capture resumption")
	}
	archiveSHA256 := manualArchive.SHA256
	if archiveSHA256 == "" && len(manifest.Build.ArtifactSHA) == 64 {
		if _, decodeErr := hex.DecodeString(manifest.Build.ArtifactSHA); decodeErr == nil {
			archiveSHA256 = strings.ToLower(manifest.Build.ArtifactSHA)
		}
	}
	policy := regression.MiSTerRunPolicy{Manual: manual, Retry: resume, RunScopeID: scope, FullInventory: !manual, ArchiveSHA256: archiveSHA256}
	deps := regression.MiSTerCommitDeps{Qualification: qualification, Boards: boards,
		CoordinatorOptions: regression.CaptureCoordinatorOptions{CaptureTimeout: time.Duration(cfg.CaptureContract.CaptureTimeoutSeconds) * time.Second,
			CleanupTimeout: time.Duration(cfg.CaptureContract.CleanupTimeoutSeconds) * time.Second},
		PrivateWorkRoot: filepath.Join(dataRoot, "log", ".mister-private", regression.LogKey(commit, dirty))}
	_, err = regression.RunCommitMiSTer(ctx, record, prepared, cfg, deps, policy)
	if err != nil {
		_ = record.Entry("", -1, "error", err.Error())
		return err
	}
	lanes, err := regression.ReadMiSTerLaneStatus(dataRoot, qualification.Generation, qualification.QualificationID)
	if err != nil {
		return err
	}
	for _, lane := range lanes {
		if lane.Commit == commit && lane.Lane.RunScopeID == scope {
			fmt.Fprintf(command.OutOrStdout(), "MiSTer lane %s: %s (%d selected games)\n", lane.Key, lane.Lane.Status, len(lane.Lane.Selected))
			return nil
		}
	}
	return fmt.Errorf("MiSTer coordinator returned without a persisted selected lane")
}

func makeMiSTerRunScope() (string, error) {
	var token [16]byte
	if _, err := rand.Read(token[:]); err != nil {
		return "", err
	}
	return "manual-" + hex.EncodeToString(token[:]), nil
}

func miSTerResultRoot(cfg regression.Config, dataRoot string) (regression.Config, error) {
	if cfg.Root == "" {
		cfg.Root = dataRoot
	}
	configured, err := filepath.Abs(cfg.Root)
	if err != nil {
		return cfg, err
	}
	expected, err := filepath.Abs(dataRoot)
	if err != nil {
		return cfg, err
	}
	if configured != expected {
		return cfg, fmt.Errorf("result root must be JOTEGO/regression (%s)", expected)
	}
	cfg.Root = expected
	return cfg, nil
}

func miSTerScopeID(explicit string) (string, bool, error) {
	if explicit != "" {
		if strings.TrimSpace(explicit) != explicit || len(explicit) > 256 || strings.ContainsAny(explicit, "\x00\r\n") {
			return "", false, fmt.Errorf("MiSTer run scope is invalid")
		}
		return explicit, true, nil
	}
	scope, err := makeMiSTerRunScope()
	return scope, false, err
}

func validMiSTerCommit(value string) bool {
	if len(value) != 40 || strings.ToLower(value) != value {
		return false
	}
	_, err := hex.DecodeString(value)
	return err == nil
}

func miSTerRequireCoreSet(cores, sets []string) error {
	if len(sets) > 0 && len(cores) == 0 {
		return fmt.Errorf("--setname requires --core for MiSTer")
	}
	return nil
}

func miSTerWorkDirectory() (string, error) {
	return os.MkdirTemp("/tmp", "jtutil-mister-run-")
}

func miSTerTimeoutContext(parent context.Context, seconds int) (context.Context, context.CancelFunc) {
	if seconds < 1 {
		seconds = 900
	}
	return context.WithTimeout(parent, time.Duration(seconds)*time.Second)
}

func prepareMiSTerJobs(ctx context.Context, cfg regression.Config, manifest regression.Manifest, work string, qualification regression.CaptureQualification) ([]regression.MiSTerPreparedGame, error) {
	var prepared []regression.MiSTerPreparedGame
	seen := map[string]bool{}
	for _, core := range manifest.Cores {
		for _, spec := range core.Games {
			if seen[core.Core+"/"+spec.Setname] {
				return nil, fmt.Errorf("duplicate MiSTer inventory game %s/%s", core.Core, spec.Setname)
			}
			seen[core.Core+"/"+spec.Setname] = true
			stage := filepath.Join(work, "sessions", core.Core, spec.Setname)
			if err := os.MkdirAll(stage, 0700); err != nil {
				return nil, err
			}
			session, packedCAB, capturePlan, err := regression.PrepareMiSTerSession(ctx, core.Core, spec, regression.MiSTerSessionBuildOptions{
				SourceRoot: cfg.Source, ConfigSourceRoot: cfg.SourceConfigRoot, CabPacker: cfg.CabPacker, Generation: qualification.Generation,
				Convention: qualification.Convention, MainSHA256: cfg.CaptureContract.MainSHA256,
				MaxHoldMS: cfg.CaptureContract.MaxHoldMS, StagingDir: stage,
			})
			if err != nil {
				return nil, fmt.Errorf("prepare MiSTer session %s/%s: %w", core.Core, spec.Setname, err)
			}
			sessionID, nonce, err := randomMiSTerAttempt()
			if err != nil {
				return nil, err
			}
			job := regression.PoolJob{Session: session, SessionID: sessionID, Nonce: nonce}
			prepared = append(prepared, regression.MiSTerPreparedGame{Job: job, Spec: spec, PackedCAB: packedCAB, CapturePlan: capturePlan})
		}
	}
	if len(prepared) == 0 {
		return nil, fmt.Errorf("MiSTer inventory contains no games")
	}
	return prepared, nil
}

func randomMiSTerAttempt() (string, string, error) {
	var id, nonce [24]byte
	if _, err := rand.Read(id[:]); err != nil {
		return "", "", err
	}
	if _, err := rand.Read(nonce[:]); err != nil {
		return "", "", err
	}
	return "mister-" + hex.EncodeToString(id[:12]), hex.EncodeToString(nonce[:]), nil
}

func runMiSTerManagement(command *cobra.Command, cfg regression.Config, dataRoot string) error {
	qualification, err := regression.ReadMiSTerQualification(cfg)
	if err != nil {
		return err
	}
	switch {
	case regressionAccept != "":
		core, set, parseErr := parseMiSTerGameSelector(regressionAccept)
		if parseErr != nil {
			return parseErr
		}
		if err = regression.AcceptMiSTerResult(dataRoot, core, set, qualification.Generation, qualification.QualificationID); err == nil {
			fmt.Fprintf(command.OutOrStdout(), "Accepted qualified MiSTer candidate %s/%s as ref\n", core, set)
		}
		return err
	case regressionReject != "":
		core, set, parseErr := parseMiSTerGameSelector(regressionReject)
		if parseErr != nil {
			return parseErr
		}
		if err = regression.RejectMiSTerResult(dataRoot, core, set, regressionReason); err == nil {
			fmt.Fprintf(command.OutOrStdout(), "Rejected MiSTer candidate %s/%s\n", core, set)
		}
		return err
	case regressionStatus:
		lanes, laneErr := regression.ReadMiSTerLaneStatus(dataRoot, qualification.Generation, qualification.QualificationID)
		if laneErr != nil {
			return laneErr
		}
		if len(lanes) == 0 {
			fmt.Fprintln(command.OutOrStdout(), "No qualified MiSTer capture lanes")
			return nil
		}
		for _, item := range lanes {
			counts := map[regression.Outcome]int{}
			for _, game := range item.Lane.Games {
				counts[game.Result]++
			}
			fmt.Fprintf(command.OutOrStdout(), "%s %s %s scope=%s selected=%d finalized=%d pass=%d new=%d fail=%d status=%s\n",
				item.Commit[:min(12, len(item.Commit))], item.Lane.CaptureGeneration, item.Lane.QualificationID,
				item.Lane.RunScopeID, len(item.Lane.Selected), len(item.Lane.Games), counts[regression.Pass], counts[regression.New], counts[regression.Fail], item.Lane.Status)
		}
		return nil
	default:
		return fmt.Errorf("MiSTer management supports --accept, --reject and --status")
	}
}

func parseMiSTerGameSelector(value string) (string, string, error) {
	parts := strings.Split(value, "/")
	if len(parts) != 2 || !safe_regression_component(parts[0]) || !safe_regression_component(parts[1]) || parts[0] == "log" {
		return "", "", fmt.Errorf("MiSTer game selector must be exactly core/setname")
	}
	return parts[0], parts[1], nil
}
